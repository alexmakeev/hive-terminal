use std::sync::Arc;

use russh::client::{self, Config, Handle, Msg};
use russh::keys::key::PublicKey;
use russh::{Channel, Disconnect};
use tracing::{debug, info};

use crate::{HiveError, Result};

pub struct SshClient {
    handle: Handle<ClientHandler>,
}

struct ClientHandler {
    host: String,
}

#[async_trait::async_trait]
impl client::Handler for ClientHandler {
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

impl SshClient {
    pub async fn connect(host: &str, port: u16) -> Result<Self> {
        let config = Config {
            inactivity_timeout: Some(std::time::Duration::from_secs(3600)),
            keepalive_interval: Some(std::time::Duration::from_secs(30)),
            keepalive_max: 3,
            ..Default::default()
        };

        let config = Arc::new(config);
        let handler = ClientHandler {
            host: host.to_string(),
        };

        let addr = format!("{}:{}", host, port);
        debug!("Connecting to SSH server at {}", addr);

        let handle = client::connect(config, &addr, handler)
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to connect to {}: {}", addr, e)))?;

        info!("Connected to SSH server at {}", addr);

        Ok(Self { handle })
    }

    pub async fn authenticate_password(&mut self, username: &str, password: &str) -> Result<bool> {
        debug!("Authenticating user {} with password", username);

        let authenticated = self
            .handle
            .authenticate_password(username, password)
            .await
            .map_err(|e| HiveError::Ssh(format!("Authentication failed: {}", e)))?;

        if authenticated {
            info!("User {} authenticated successfully", username);
        } else {
            info!("User {} authentication failed", username);
        }

        Ok(authenticated)
    }

    pub async fn open_session(&mut self) -> Result<Channel<Msg>> {
        let channel = self
            .handle
            .channel_open_session()
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to open channel: {}", e)))?;

        debug!("Opened SSH channel {}", channel.id());

        Ok(channel)
    }

    pub async fn disconnect(&mut self) -> Result<()> {
        debug!("Disconnecting SSH client");

        self.handle
            .disconnect(Disconnect::ByApplication, "Session ended", "en")
            .await
            .map_err(|e| HiveError::Ssh(format!("Failed to disconnect: {}", e)))?;

        Ok(())
    }
}
