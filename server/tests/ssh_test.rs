use hive_server::ssh::SshSession;
use tokio::time::Duration;

// SSH test container settings from docker-compose.yml
const SSH_HOST: &str = "localhost";
const SSH_PORT: u16 = 2222;
const SSH_USER: &str = "testuser";
const SSH_PASS: &str = "testpass";

#[tokio::test]
async fn test_ssh_connection() {
    // Connect to SSH test container
    let session = SshSession::connect(
        SSH_HOST,
        SSH_PORT,
        SSH_USER,
        SSH_PASS,
        80,
        24,
    )
    .await;

    match session {
        Ok(session) => {
            // Connection successful
            println!("SSH connection successful!");

            // Close session
            session.close().await.expect("Failed to close session");
        }
        Err(e) => {
            // This is expected to fail if SSH container is not running
            println!("SSH connection failed (expected if container not running): {}", e);
        }
    }
}

#[tokio::test]
async fn test_ssh_send_command() {
    let session = match SshSession::connect(
        SSH_HOST,
        SSH_PORT,
        SSH_USER,
        SSH_PASS,
        80,
        24,
    )
    .await {
        Ok(s) => s,
        Err(e) => {
            println!("Skipping test - SSH container not available: {}", e);
            return;
        }
    };

    // Send a simple command
    session.send(b"echo hello\n").await.expect("Failed to send data");

    // Wait a bit for the command to execute
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Close session
    session.close().await.expect("Failed to close session");
}

#[tokio::test]
async fn test_ssh_resize() {
    let session = match SshSession::connect(
        SSH_HOST,
        SSH_PORT,
        SSH_USER,
        SSH_PASS,
        80,
        24,
    )
    .await {
        Ok(s) => s,
        Err(e) => {
            println!("Skipping test - SSH container not available: {}", e);
            return;
        }
    };

    // Resize terminal
    session.resize(120, 40).await.expect("Failed to resize");

    // Close session
    session.close().await.expect("Failed to close session");
}

#[tokio::test]
async fn test_ssh_auth_failure() {
    let result = SshSession::connect(
        SSH_HOST,
        SSH_PORT,
        SSH_USER,
        "wrongpassword",
        80,
        24,
    )
    .await;

    match result {
        Ok(_) => panic!("Expected authentication to fail"),
        Err(e) => {
            let error_msg = format!("{}", e);
            assert!(
                error_msg.contains("auth") || error_msg.contains("failed"),
                "Expected auth error, got: {}",
                error_msg
            );
        }
    }
}
