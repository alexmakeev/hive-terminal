use std::collections::HashMap;
use std::sync::Arc;

use russh::client::{self, Config, Msg};
use russh::keys::key::PublicKey;
use russh::Channel;
use sqlx::PgPool;
use tokio::sync::{broadcast, Mutex, RwLock};
use tracing::{debug, error, info};
use uuid::Uuid;

use crate::db::{Connection as DbConnection, ScrollbackChunk, Session as DbSession};
use crate::{HiveError, Result};

struct SessionHandler {
    host: String,
    output_tx: broadcast::Sender<Vec<u8>>,
}

#[async_trait::async_trait]
impl client::Handler for SessionHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        server_public_key: &PublicKey,
    ) -> std::result::Result<bool, Self::Error> {
        info!(
            "Accepting server key for {}: {:?}",
            self.host,
            server_public_key.fingerprint()
        );
        Ok(true)
    }

    async fn data(
        &mut self,
        _channel: russh::ChannelId,
        data: &[u8],
        _session: &mut client::Session,
    ) -> std::result::Result<(), Self::Error> {
        debug!("Received {} bytes from SSH", data.len());
        let _ = self.output_tx.send(data.to_vec());
        Ok(())
    }

    async fn extended_data(
        &mut self,
        _channel: russh::ChannelId,
        _ext: u32,
        data: &[u8],
        _session: &mut client::Session,
    ) -> std::result::Result<(), Self::Error> {
        debug!("Received {} bytes of stderr from SSH", data.len());
        let _ = self.output_tx.send(data.to_vec());
        Ok(())
    }
}

pub struct ActiveSession {
    pub session_id: Uuid,
    pub connection_id: Uuid,
    pub user_id: Uuid,
    channel: Channel<Msg>,
    output_tx: broadcast::Sender<Vec<u8>>,
}

impl ActiveSession {
    pub async fn send(&self, data: &[u8]) -> Result<()> {
        self.channel
            .data(data)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to send data: {}", e)))?;
        Ok(())
    }

    pub async fn resize(&self, cols: u32, rows: u32) -> Result<()> {
        self.channel
            .window_change(cols, rows, 0, 0)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to resize: {}", e)))?;
        Ok(())
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Vec<u8>> {
        self.output_tx.subscribe()
    }
}

pub struct SessionManager {
    pool: PgPool,
    sessions: RwLock<HashMap<Uuid, Arc<Mutex<ActiveSession>>>>,
}

impl SessionManager {
    pub fn new(pool: PgPool) -> Self {
        Self {
            pool,
            sessions: RwLock::new(HashMap::new()),
        }
    }

    pub async fn create_session(
        &self,
        user_id: Uuid,
        connection_id: Uuid,
        cols: u32,
        rows: u32,
        password: &str,
    ) -> Result<(Uuid, broadcast::Receiver<Vec<u8>>)> {
        // Get connection details
        let connection = DbConnection::find_by_id(&self.pool, connection_id)
            .await?
            .ok_or_else(|| HiveError::Session("Connection not found".into()))?;

        if connection.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to use this connection".into()));
        }

        // Create database session record
        let db_session = DbSession::create(&self.pool, user_id, connection_id).await?;

        info!(
            "Creating SSH session {} for connection {} ({}:{})",
            db_session.id, connection.name, connection.host, connection.port
        );

        // Create broadcast channel for output
        let (output_tx, output_rx) = broadcast::channel(1024);

        let config = Config {
            inactivity_timeout: Some(std::time::Duration::from_secs(3600)),
            keepalive_interval: Some(std::time::Duration::from_secs(30)),
            keepalive_max: 3,
            ..Default::default()
        };
        let config = Arc::new(config);

        let handler = SessionHandler {
            host: connection.host.clone(),
            output_tx: output_tx.clone(),
        };

        let addr = format!("{}:{}", connection.host, connection.port);

        let mut handle = client::connect(config, &addr, handler)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to connect: {}", e)))?;

        let authenticated = handle
            .authenticate_password(&connection.username, password)
            .await
            .map_err(|e| HiveError::Ssh(format!("Authentication failed: {}", e)))?;

        if !authenticated {
            return Err(HiveError::Auth("SSH authentication failed".into()));
        }

        let channel = handle
            .channel_open_session()
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to open channel: {}", e)))?;

        channel
            .request_pty(false, "xterm-256color", cols, rows, 0, 0, &[])
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to request PTY: {}", e)))?;

        channel
            .request_shell(false)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to request shell: {}", e)))?;

        info!("SSH session {} established", db_session.id);

        // Spawn background task to save scrollback
        let scrollback_pool = self.pool.clone();
        let scrollback_session_id = db_session.id;
        let mut scrollback_rx = output_tx.subscribe();
        tokio::spawn(async move {
            loop {
                match scrollback_rx.recv().await {
                    Ok(data) => {
                        if let Err(e) =
                            ScrollbackChunk::append(&scrollback_pool, scrollback_session_id, &data)
                                .await
                        {
                            error!("Failed to save scrollback: {}", e);
                        }
                    }
                    Err(broadcast::error::RecvError::Closed) => {
                        debug!("Scrollback channel closed for session {}", scrollback_session_id);
                        break;
                    }
                    Err(broadcast::error::RecvError::Lagged(n)) => {
                        debug!("Scrollback lagged {} messages", n);
                    }
                }
            }
        });

        // Store active session
        let active_session = ActiveSession {
            session_id: db_session.id,
            connection_id,
            user_id,
            channel,
            output_tx,
        };

        let mut sessions = self.sessions.write().await;
        sessions.insert(db_session.id, Arc::new(Mutex::new(active_session)));

        Ok((db_session.id, output_rx))
    }

    pub async fn get_session(&self, session_id: Uuid) -> Option<Arc<Mutex<ActiveSession>>> {
        let sessions = self.sessions.read().await;
        sessions.get(&session_id).cloned()
    }

    pub async fn close_session(&self, session_id: Uuid) -> Result<()> {
        let mut sessions = self.sessions.write().await;

        if let Some(session) = sessions.remove(&session_id) {
            let session = session.lock().await;
            session.channel.close().await.ok();

            // Update database
            DbSession::close(&self.pool, session_id).await?;

            info!("Session {} closed", session_id);
        }

        Ok(())
    }

    pub async fn attach_to_session(
        &self,
        session_id: Uuid,
        user_id: Uuid,
    ) -> Result<broadcast::Receiver<Vec<u8>>> {
        // Verify ownership
        let db_session = DbSession::find_by_id(&self.pool, session_id)
            .await?
            .ok_or_else(|| HiveError::Session("Session not found".into()))?;

        if db_session.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to access this session".into()));
        }

        if db_session.status != "active" {
            return Err(HiveError::Session("Session is not active".into()));
        }

        let sessions = self.sessions.read().await;
        let session = sessions
            .get(&session_id)
            .ok_or_else(|| HiveError::Session("Session not active in memory".into()))?;

        let session = session.lock().await;
        Ok(session.subscribe())
    }

    /// Get full scrollback history for a session
    pub async fn get_scrollback(&self, session_id: Uuid, user_id: Uuid) -> Result<Vec<u8>> {
        // Verify ownership
        let db_session = DbSession::find_by_id(&self.pool, session_id)
            .await?
            .ok_or_else(|| HiveError::Session("Session not found".into()))?;

        if db_session.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to access this session".into()));
        }

        let scrollback = ScrollbackChunk::get_all(&self.pool, session_id).await?;
        Ok(scrollback)
    }

    /// Get scrollback from a specific offset (for resuming after disconnect)
    pub async fn get_scrollback_from_offset(
        &self,
        session_id: Uuid,
        user_id: Uuid,
        offset: usize,
    ) -> Result<Vec<u8>> {
        // Verify ownership
        let db_session = DbSession::find_by_id(&self.pool, session_id)
            .await?
            .ok_or_else(|| HiveError::Session("Session not found".into()))?;

        if db_session.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to access this session".into()));
        }

        let scrollback = ScrollbackChunk::get_from_offset(&self.pool, session_id, offset).await?;
        Ok(scrollback)
    }

    /// Get total scrollback size for a session
    pub async fn get_scrollback_size(&self, session_id: Uuid, user_id: Uuid) -> Result<usize> {
        // Verify ownership
        let db_session = DbSession::find_by_id(&self.pool, session_id)
            .await?
            .ok_or_else(|| HiveError::Session("Session not found".into()))?;

        if db_session.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to access this session".into()));
        }

        let size = ScrollbackChunk::total_size(&self.pool, session_id).await?;
        Ok(size)
    }

    /// Attach to session with recovery - returns scrollback data + live stream
    pub async fn attach_with_recovery(
        &self,
        session_id: Uuid,
        user_id: Uuid,
        last_seen_offset: Option<usize>,
    ) -> Result<(Vec<u8>, broadcast::Receiver<Vec<u8>>)> {
        // Verify ownership
        let db_session = DbSession::find_by_id(&self.pool, session_id)
            .await?
            .ok_or_else(|| HiveError::Session("Session not found".into()))?;

        if db_session.user_id != user_id {
            return Err(HiveError::Auth("Not authorized to access this session".into()));
        }

        if db_session.status != "active" {
            return Err(HiveError::Session("Session is not active".into()));
        }

        // Get scrollback data
        let scrollback = match last_seen_offset {
            Some(offset) => ScrollbackChunk::get_from_offset(&self.pool, session_id, offset).await?,
            None => ScrollbackChunk::get_all(&self.pool, session_id).await?,
        };

        // Subscribe to live stream
        let sessions = self.sessions.read().await;
        let session = sessions
            .get(&session_id)
            .ok_or_else(|| HiveError::Session("Session not active in memory".into()))?;

        let session = session.lock().await;
        let receiver = session.subscribe();

        Ok((scrollback, receiver))
    }
}
