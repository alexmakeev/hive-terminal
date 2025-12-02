use hive_server::db::{create_pool, run_migrations, ApiKey, User};
use hive_server::proto::auth_client::AuthClient;
use hive_server::proto::auth_server::AuthServer;
use hive_server::proto::ApiKeyRequest;
use hive_server::api::AuthService;
use sqlx::PgPool;
use std::net::SocketAddr;
use tonic::transport::Server;

async fn setup_test_db() -> PgPool {
    let database_url =
        std::env::var("DATABASE_URL").expect("DATABASE_URL must be set for tests");
    let pool = create_pool(&database_url).await.expect("Failed to create pool");
    run_migrations(&pool).await.expect("Failed to run migrations");
    pool
}

async fn cleanup_test_data(pool: &PgPool, username: &str) {
    // Clean up test user if exists
    sqlx::query("DELETE FROM users WHERE username = $1")
        .bind(username)
        .execute(pool)
        .await
        .ok();
}

#[tokio::test]
async fn test_api_key_validation() {
    let pool = setup_test_db().await;
    let test_username = "test_user_auth";

    // Cleanup any previous test data
    cleanup_test_data(&pool, test_username).await;

    // Create test user
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create test user");

    // Create API key
    let raw_key = ApiKey::generate_key();
    let _api_key = ApiKey::create(&pool, user.id, "test-key", &raw_key)
        .await
        .expect("Failed to create API key");

    // Start gRPC server in background
    let addr: SocketAddr = "[::1]:50052".parse().unwrap();
    let auth_service = AuthService::new(pool.clone());

    let server_handle = tokio::spawn(async move {
        Server::builder()
            .add_service(AuthServer::new(auth_service))
            .serve(addr)
            .await
            .unwrap();
    });

    // Wait for server to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    // Connect client
    let mut client = AuthClient::connect("http://[::1]:50052")
        .await
        .expect("Failed to connect to gRPC server");

    // Test valid key
    let response = client
        .validate_api_key(ApiKeyRequest {
            api_key: raw_key.clone(),
        })
        .await
        .expect("Failed to validate API key")
        .into_inner();

    assert!(response.valid, "Valid API key should return valid=true");
    assert_eq!(response.username, test_username);
    assert_eq!(response.user_id, user.id.to_string());

    // Test invalid key
    let response = client
        .validate_api_key(ApiKeyRequest {
            api_key: "invalid_key".to_string(),
        })
        .await
        .expect("Failed to validate API key")
        .into_inner();

    assert!(!response.valid, "Invalid API key should return valid=false");
    assert!(response.username.is_empty());

    // Cleanup
    cleanup_test_data(&pool, test_username).await;

    // Stop server
    server_handle.abort();
}

#[tokio::test]
async fn test_api_key_generation_and_hashing() {
    // Test that generated keys are unique
    let key1 = ApiKey::generate_key();
    let key2 = ApiKey::generate_key();
    assert_ne!(key1, key2);
    assert!(key1.starts_with("hive_"));
    assert!(key2.starts_with("hive_"));

    // Test that hashing is deterministic
    let hash1 = ApiKey::hash_key(&key1);
    let hash2 = ApiKey::hash_key(&key1);
    assert_eq!(hash1, hash2);

    // Test that different keys produce different hashes
    let hash3 = ApiKey::hash_key(&key2);
    assert_ne!(hash1, hash3);
}

#[tokio::test]
async fn test_user_crud() {
    let pool = setup_test_db().await;
    let test_username = "test_user_crud";

    // Cleanup
    cleanup_test_data(&pool, test_username).await;

    // Create user
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create user");

    assert_eq!(user.username, test_username);

    // Find by username
    let found = User::find_by_username(&pool, test_username)
        .await
        .expect("Failed to find user")
        .expect("User should exist");

    assert_eq!(found.id, user.id);

    // Find by ID
    let found_by_id = User::find_by_id(&pool, user.id)
        .await
        .expect("Failed to find user")
        .expect("User should exist");

    assert_eq!(found_by_id.username, test_username);

    // List users
    let users = User::list(&pool).await.expect("Failed to list users");
    assert!(users.iter().any(|u| u.id == user.id));

    // Cleanup
    cleanup_test_data(&pool, test_username).await;
}

#[tokio::test]
async fn test_api_key_revocation() {
    let pool = setup_test_db().await;
    let test_username = "test_user_revoke";

    // Cleanup
    cleanup_test_data(&pool, test_username).await;

    // Create user and key
    let user = User::create(&pool, test_username)
        .await
        .expect("Failed to create user");

    let raw_key = ApiKey::generate_key();
    ApiKey::create(&pool, user.id, "revoke-test", &raw_key)
        .await
        .expect("Failed to create API key");

    // Verify key works
    let result = ApiKey::validate(&pool, &raw_key)
        .await
        .expect("Validation failed");
    assert!(result.is_some());

    // Revoke key
    let revoked = ApiKey::revoke(&pool, &raw_key)
        .await
        .expect("Revocation failed");
    assert!(revoked);

    // Verify key no longer works
    let result = ApiKey::validate(&pool, &raw_key)
        .await
        .expect("Validation failed");
    assert!(result.is_none());

    // Cleanup
    cleanup_test_data(&pool, test_username).await;
}
