use sqlx::PgPool;
use tokio::time::Duration;
use uuid::Uuid;

use hive_server::db::{create_pool, run_migrations, Connection, ScrollbackChunk, Session, User};
use hive_server::terminal::SessionManager;

async fn setup_db() -> PgPool {
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = create_pool(&database_url).await.unwrap();
    run_migrations(&pool).await.unwrap();
    pool
}

async fn create_test_user(pool: &PgPool) -> User {
    let username = format!("termtest_{}", Uuid::new_v4().to_string().split('-').next().unwrap());
    User::create(pool, &username).await.unwrap()
}

async fn create_test_connection(pool: &PgPool, user_id: Uuid) -> Connection {
    let name = format!("termconn_{}", Uuid::new_v4().to_string().split('-').next().unwrap());
    Connection::create(
        pool,
        user_id,
        &name,
        "localhost",
        2222,
        "testuser",
        None,
        None,
    )
    .await
    .unwrap()
}

#[tokio::test]
async fn test_session_manager_create_session() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    // Create a session
    let result = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await;

    assert!(result.is_ok(), "Failed to create session: {:?}", result);
    let (session_id, mut output_rx) = result.unwrap();

    // Verify session exists in manager
    let session = manager.get_session(session_id).await;
    assert!(session.is_some());

    // Session should be in database
    let db_session = Session::find_by_id(&pool, session_id).await.unwrap();
    assert!(db_session.is_some());
    let db_session = db_session.unwrap();
    assert_eq!(db_session.user_id, user.id);
    assert_eq!(db_session.connection_id, connection.id);
    assert_eq!(db_session.status, "active");

    // Should receive some initial output from SSH (shell prompt, MOTD, etc.)
    let receive_result = tokio::time::timeout(Duration::from_secs(5), output_rx.recv()).await;
    assert!(receive_result.is_ok(), "Timeout waiting for initial output");

    // Close session
    manager.close_session(session_id).await.unwrap();

    // Verify session is removed from manager
    let session = manager.get_session(session_id).await;
    assert!(session.is_none());

    // Verify session is closed in database
    let db_session = Session::find_by_id(&pool, session_id).await.unwrap();
    assert!(db_session.is_some());
    assert_eq!(db_session.unwrap().status, "closed");
}

#[tokio::test]
async fn test_session_manager_send_command() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, mut output_rx) = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // Wait for shell to be ready
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Clear any initial output
    while output_rx.try_recv().is_ok() {}

    // Get session and send command
    let session = manager.get_session(session_id).await.unwrap();
    {
        let session = session.lock().await;
        session.send(b"echo TESTMARKER123\n").await.unwrap();
    }

    // Wait for output
    let mut received_marker = false;
    let start = std::time::Instant::now();
    while start.elapsed() < Duration::from_secs(5) {
        match tokio::time::timeout(Duration::from_millis(100), output_rx.recv()).await {
            Ok(Ok(data)) => {
                let output = String::from_utf8_lossy(&data);
                if output.contains("TESTMARKER123") {
                    received_marker = true;
                    break;
                }
            }
            Ok(Err(_)) => break,
            Err(_) => continue,
        }
    }

    assert!(received_marker, "Did not receive expected output marker");

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_session_manager_multi_client_attach() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, mut output_rx1) = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // Wait for shell to be ready
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Attach second client
    let mut output_rx2 = manager.attach_to_session(session_id, user.id).await.unwrap();

    // Clear any pending output
    while output_rx1.try_recv().is_ok() {}
    while output_rx2.try_recv().is_ok() {}

    // Send command
    let session = manager.get_session(session_id).await.unwrap();
    {
        let session = session.lock().await;
        session.send(b"echo MULTICLIENT_TEST\n").await.unwrap();
    }

    // Both clients should receive the output
    let mut rx1_received = false;
    let mut rx2_received = false;

    let start = std::time::Instant::now();
    while start.elapsed() < Duration::from_secs(5) && (!rx1_received || !rx2_received) {
        tokio::select! {
            result = output_rx1.recv() => {
                if let Ok(data) = result {
                    if String::from_utf8_lossy(&data).contains("MULTICLIENT_TEST") {
                        rx1_received = true;
                    }
                }
            }
            result = output_rx2.recv() => {
                if let Ok(data) = result {
                    if String::from_utf8_lossy(&data).contains("MULTICLIENT_TEST") {
                        rx2_received = true;
                    }
                }
            }
            _ = tokio::time::sleep(Duration::from_millis(100)) => {}
        }
    }

    assert!(rx1_received, "First client did not receive output");
    assert!(rx2_received, "Second client did not receive output");

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_session_manager_resize() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, _output_rx) = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // Get session and resize
    let session = manager.get_session(session_id).await.unwrap();
    {
        let session = session.lock().await;
        let result = session.resize(120, 40).await;
        assert!(result.is_ok(), "Failed to resize: {:?}", result);
    }

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_session_manager_auth_check() {
    let pool = setup_db().await;
    let user1 = create_test_user(&pool).await;
    let user2 = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user1.id).await;

    let manager = SessionManager::new(pool.clone());

    // User1 creates session
    let (session_id, _output_rx) = manager
        .create_session(user1.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // User2 should not be able to attach
    let result = manager.attach_to_session(session_id, user2.id).await;
    assert!(result.is_err(), "User2 should not be able to attach to User1's session");

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_session_manager_invalid_password() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    // Try to create session with wrong password
    let result = manager
        .create_session(user.id, connection.id, 80, 24, "wrongpassword")
        .await;

    assert!(result.is_err(), "Should fail with wrong password");
}

#[tokio::test]
async fn test_session_manager_connection_not_owned() {
    let pool = setup_db().await;
    let user1 = create_test_user(&pool).await;
    let user2 = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user1.id).await;

    let manager = SessionManager::new(pool.clone());

    // User2 tries to create session with User1's connection
    let result = manager
        .create_session(user2.id, connection.id, 80, 24, "testpass")
        .await;

    assert!(result.is_err(), "User2 should not be able to use User1's connection");
}

// ============ Phase 4: Scrollback and Recovery Tests ============

#[tokio::test]
async fn test_scrollback_storage() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, mut output_rx) = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // Wait for shell to be ready and collect some output
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Clear any initial output (but it should be stored in scrollback)
    while output_rx.try_recv().is_ok() {}

    // Send a command to generate more output
    let session = manager.get_session(session_id).await.unwrap();
    {
        let session = session.lock().await;
        session.send(b"echo SCROLLBACK_TEST_MARKER\n").await.unwrap();
    }

    // Wait for command to execute and be stored
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Get scrollback - should contain our marker
    let scrollback = manager.get_scrollback(session_id, user.id).await.unwrap();
    let scrollback_str = String::from_utf8_lossy(&scrollback);

    assert!(
        scrollback_str.contains("SCROLLBACK_TEST_MARKER"),
        "Scrollback should contain our marker. Got: {:?}",
        scrollback_str
    );

    // Verify size is reported correctly
    let size = manager.get_scrollback_size(session_id, user.id).await.unwrap();
    assert_eq!(size, scrollback.len(), "Scrollback size mismatch");

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_scrollback_chunks_model() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    // Create a session in database first
    let session = Session::create(&pool, user.id, connection.id).await.unwrap();

    // Test appending data
    let data1 = b"Hello, World!\n";
    ScrollbackChunk::append(&pool, session.id, data1).await.unwrap();

    let data2 = b"This is more data.\n";
    ScrollbackChunk::append(&pool, session.id, data2).await.unwrap();

    // Get all data
    let all_data = ScrollbackChunk::get_all(&pool, session.id).await.unwrap();
    let expected = [data1.as_slice(), data2.as_slice()].concat();
    assert_eq!(all_data, expected);

    // Test get from offset
    let from_offset = ScrollbackChunk::get_from_offset(&pool, session.id, data1.len()).await.unwrap();
    assert_eq!(from_offset, data2);

    // Test total size
    let size = ScrollbackChunk::total_size(&pool, session.id).await.unwrap();
    assert_eq!(size, data1.len() + data2.len());

    // Clean up
    ScrollbackChunk::delete_for_session(&pool, session.id).await.unwrap();
    Session::close(&pool, session.id).await.unwrap();
}

#[tokio::test]
async fn test_scrollback_large_data() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    // Create a session
    let session = Session::create(&pool, user.id, connection.id).await.unwrap();

    // Generate data larger than one chunk (> 64KB)
    let large_data: Vec<u8> = (0..100000).map(|i| (i % 256) as u8).collect();

    ScrollbackChunk::append(&pool, session.id, &large_data).await.unwrap();

    // Retrieve and verify
    let retrieved = ScrollbackChunk::get_all(&pool, session.id).await.unwrap();
    assert_eq!(retrieved, large_data);

    // Test offset retrieval
    let offset = 50000;
    let from_offset = ScrollbackChunk::get_from_offset(&pool, session.id, offset).await.unwrap();
    assert_eq!(from_offset, &large_data[offset..]);

    // Clean up
    ScrollbackChunk::delete_for_session(&pool, session.id).await.unwrap();
    Session::close(&pool, session.id).await.unwrap();
}

#[tokio::test]
async fn test_session_recovery() {
    let pool = setup_db().await;
    let user = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, mut output_rx1) = manager
        .create_session(user.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // Wait for shell to be ready
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Collect initial output and remember the offset
    let mut total_received = 0;
    while let Ok(data) = output_rx1.try_recv() {
        total_received += data.len();
    }

    // Send a command
    let session = manager.get_session(session_id).await.unwrap();
    {
        let session = session.lock().await;
        session.send(b"echo RECOVERY_MARKER\n").await.unwrap();
    }

    // Wait for command to execute
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Simulate client disconnect - drop receiver
    drop(output_rx1);

    // Now "reconnect" with recovery
    let (scrollback, _output_rx2) = manager
        .attach_with_recovery(session_id, user.id, Some(total_received))
        .await
        .unwrap();

    // The scrollback should contain the marker that we missed
    let scrollback_str = String::from_utf8_lossy(&scrollback);
    assert!(
        scrollback_str.contains("RECOVERY_MARKER"),
        "Recovery scrollback should contain the marker we missed"
    );

    manager.close_session(session_id).await.unwrap();
}

#[tokio::test]
async fn test_scrollback_auth_check() {
    let pool = setup_db().await;
    let user1 = create_test_user(&pool).await;
    let user2 = create_test_user(&pool).await;
    let connection = create_test_connection(&pool, user1.id).await;

    let manager = SessionManager::new(pool.clone());

    let (session_id, _output_rx) = manager
        .create_session(user1.id, connection.id, 80, 24, "testpass")
        .await
        .unwrap();

    // User2 should not be able to access User1's scrollback
    let result = manager.get_scrollback(session_id, user2.id).await;
    assert!(result.is_err(), "User2 should not access User1's scrollback");

    let result = manager.get_scrollback_size(session_id, user2.id).await;
    assert!(result.is_err(), "User2 should not access User1's scrollback size");

    let result = manager.attach_with_recovery(session_id, user2.id, None).await;
    assert!(result.is_err(), "User2 should not attach with recovery to User1's session");

    manager.close_session(session_id).await.unwrap();
}
