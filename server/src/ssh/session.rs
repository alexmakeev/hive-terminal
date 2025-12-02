use std::sync::Arc;

use russh::client::{self, Config, Msg};
use russh::keys::key::PublicKey;
use russh::Channel;
use tracing::{debug, info};

use crate::{HiveError, Result};

pub struct SshSession {
    channel: Channel<Msg>,
}

struct SessionHandler {
    host: String,
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
}

impl SshSession {
    pub async fn connect(
        host: &str,
        port: u16,
        username: &str,
        password: &str,
        cols: u32,
        rows: u32,
    ) -> Result<Self> {
        let config = Config {
            inactivity_timeout: Some(std::time::Duration::from_secs(3600)),
            keepalive_interval: Some(std::time::Duration::from_secs(30)),
            keepalive_max: 3,
            ..Default::default()
        };

        let config = Arc::new(config);

        let handler = SessionHandler {
            host: host.to_string(),
        };

        let addr = format!("{}:{}", host, port);
        debug!("Connecting to SSH server at {}", addr);

        let mut handle = client::connect(config, &addr, handler)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to connect to {}: {}", addr, e)))?;

        info!("Connected to SSH server at {}", addr);

        // Authenticate
        let authenticated = handle
            .authenticate_password(username, password)
            .await
            .map_err(|e| HiveError::Ssh(format!("Authentication failed: {}", e)))?;

        if !authenticated {
            return Err(HiveError::Auth("SSH authentication failed".into()));
        }

        info!("Authenticated as {}", username);

        // Open session channel
        let channel = handle
            .channel_open_session()
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to open channel: {}", e)))?;

        debug!("Opened SSH channel {}", channel.id());

        // Request PTY
        channel
            .request_pty(
                false, // don't want reply
                "xterm-256color",
                cols,
                rows,
                0,
                0,
                &[],
            )
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to request PTY: {}", e)))?;

        debug!("Requested PTY {}x{}", cols, rows);

        // Request shell
        channel
            .request_shell(false)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to request shell: {}", e)))?;

        info!("Shell started on channel {}", channel.id());

        Ok(Self { channel })
    }

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

    pub async fn close(self) -> Result<()> {
        self.channel
            .close()
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to close channel: {}", e)))?;
        Ok(())
    }

    pub fn into_channel(self) -> Channel<Msg> {
        self.channel
    }
}
