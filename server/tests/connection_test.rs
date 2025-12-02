use hive_server::db::{create_pool, run_migrations, Connection, Session, User};
use sqlx::PgPool;

async fn setup_test_db() -> PgPool {
    let database_url =
        std::env::var("DATABASE_URL").expect("DATABASE_URL must be set for tests");
    let pool = create_pool(&database_url).await.expect("Failed to create pool");
    run_migrations(&pool).await.expect("Failed to run migrations");
    pool
}

async fn cleanup_test_user(pool: &PgPool, username: &str) {
    sqlx::query("DELETE FROM users WHERE username = $1")
        .bind(username)
        .execute(pool)
        .await
        .ok();
}

#[tokio::test]
async fn test_connection_crud() {
    let pool = setup_test_db().await;
    let test_username = "test_user_conn_crud";

    // Cleanup
    cleanup_test_user(&pool, test_username).await;

    // Create user
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create user");

    // Create connection
    let conn = Connection::create(
        &pool,
        user.id,
        "Test Server",
        "localhost",
        2222,
        "testuser",
        None,
        Some("ls -la"),
    )
    .await
    .expect("Failed to create connection");

    assert_eq!(conn.name, "Test Server");
    assert_eq!(conn.host, "localhost");
    assert_eq!(conn.port, 2222);
    assert_eq!(conn.username, "testuser");
    assert_eq!(conn.startup_command.as_deref(), Some("ls -la"));

    // Find by ID
    let found = Connection::find_by_id(&pool, conn.id)
        .await
        .expect("Failed to find connection")
        .expect("Connection should exist");

    assert_eq!(found.name, "Test Server");

    // List for user
    let connections = Connection::list_for_user(&pool, user.id)
        .await
        .expect("Failed to list connections");

    assert_eq!(connections.len(), 1);
    assert_eq!(connections[0].id, conn.id);

    // Update
    let updated = Connection::update(
        &pool,
        conn.id,
        "Updated Server",
        "192.168.1.1",
        22,
        "admin",
        None,
        None,
    )
    .await
    .expect("Failed to update connection")
    .expect("Connection should exist");

    assert_eq!(updated.name, "Updated Server");
    assert_eq!(updated.host, "192.168.1.1");
    assert_eq!(updated.port, 22);
    assert_eq!(updated.username, "admin");
    assert!(updated.startup_command.is_none());

    // Delete
    let deleted = Connection::delete(&pool, conn.id)
        .await
        .expect("Failed to delete connection");

    assert!(deleted);

    // Verify deleted
    let not_found = Connection::find_by_id(&pool, conn.id)
        .await
        .expect("Failed to query");

    assert!(not_found.is_none());

    // Cleanup
    cleanup_test_user(&pool, test_username).await;
}

#[tokio::test]
async fn test_session_crud() {
    let pool = setup_test_db().await;
    let test_username = "test_user_session_crud";

    // Cleanup
    cleanup_test_user(&pool, test_username).await;

    // Create user and connection
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create user");

    let conn = Connection::create(
        &pool,
        user.id,
        "Test Server",
        "localhost",
        2222,
        "testuser",
        None,
        None,
    )
    .await
    .expect("Failed to create connection");

    // Create session
    let session = Session::create(&pool, user.id, conn.id)
        .await
        .expect("Failed to create session");

    assert_eq!(session.user_id, user.id);
    assert_eq!(session.connection_id, conn.id);
    assert_eq!(session.status, "active");

    // Find by ID
    let found = Session::find_by_id(&pool, session.id)
        .await
        .expect("Failed to find session")
        .expect("Session should exist");

    assert_eq!(found.status, "active");

    // List for user
    let sessions = Session::list_for_user(&pool, user.id)
        .await
        .expect("Failed to list sessions");

    assert_eq!(sessions.len(), 1);

    // List active for user
    let active_sessions = Session::list_active_for_user(&pool, user.id)
        .await
        .expect("Failed to list active sessions");

    assert_eq!(active_sessions.len(), 1);

    // Update activity
    let updated = Session::update_activity(&pool, session.id)
        .await
        .expect("Failed to update activity");

    assert!(updated);

    // Close session
    let closed = Session::close(&pool, session.id)
        .await
        .expect("Failed to close session");

    assert!(closed);

    // Verify closed
    let closed_session = Session::find_by_id(&pool, session.id)
        .await
        .expect("Failed to find session")
        .expect("Session should exist");

    assert_eq!(closed_session.status, "closed");

    // Active sessions should be empty
    let active_sessions = Session::list_active_for_user(&pool, user.id)
        .await
        .expect("Failed to list active sessions");

    assert_eq!(active_sessions.len(), 0);

    // Cleanup
    cleanup_test_user(&pool, test_username).await;
}

#[tokio::test]
async fn test_multiple_connections() {
    let pool = setup_test_db().await;
    let test_username = "test_user_multi_conn";

    // Cleanup
    cleanup_test_user(&pool, test_username).await;

    // Create user
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create user");

    // Create multiple connections
    for i in 1..=3 {
        Connection::create(
            &pool,
            user.id,
            &format!("Server {}", i),
            &format!("server{}.example.com", i),
            22,
            "user",
            None,
            None,
        )
        .await
        .expect("Failed to create connection");
    }

    // List connections
    let connections = Connection::list_for_user(&pool, user.id)
        .await
        .expect("Failed to list connections");

    assert_eq!(connections.len(), 3);

    // Cleanup
    cleanup_test_user(&pool, test_username).await;
}
