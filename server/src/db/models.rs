use chrono::{DateTime, Utc};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::Result;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Connection {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub host: String,
    pub port: i32,
    pub username: String,
    pub ssh_key_id: Option<Uuid>,
    pub startup_command: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Session {
    pub id: Uuid,
    pub user_id: Uuid,
    pub connection_id: Uuid,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ApiKey {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub key_hash: String,
    pub last_used_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

impl User {
    pub async fn create(pool: &PgPool, username: &str) -> Result<Self> {
        let id = Uuid::new_v4();
        let user = sqlx::query_as::<_, User>(
            r#"
            INSERT INTO users (id, username)
            VALUES ($1, $2)
            RETURNING id, username, created_at
            "#,
        )
        .bind(id)
        .bind(username)
        .fetch_one(pool)
        .await?;

        Ok(user)
    }

    pub async fn find_by_username(pool: &PgPool, username: &str) -> Result<Option<Self>> {
        let user = sqlx::query_as::<_, User>(
            r#"SELECT id, username, created_at FROM users WHERE username = $1"#,
        )
        .bind(username)
        .fetch_optional(pool)
        .await?;

        Ok(user)
    }

    pub async fn find_by_id(pool: &PgPool, id: Uuid) -> Result<Option<Self>> {
        let user =
            sqlx::query_as::<_, User>(r#"SELECT id, username, created_at FROM users WHERE id = $1"#)
                .bind(id)
                .fetch_optional(pool)
                .await?;

        Ok(user)
    }

    pub async fn list(pool: &PgPool) -> Result<Vec<Self>> {
        let users = sqlx::query_as::<_, User>(
            r#"SELECT id, username, created_at FROM users ORDER BY created_at"#,
        )
        .fetch_all(pool)
        .await?;

        Ok(users)
    }
}

impl ApiKey {
    pub fn generate_key() -> String {
        let random_bytes: [u8; 32] = rand::random();
        format!("hive_{}", hex::encode(random_bytes))
    }

    pub fn hash_key(key: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(key.as_bytes());
        hex::encode(hasher.finalize())
    }

    pub async fn create(pool: &PgPool, user_id: Uuid, name: &str, key: &str) -> Result<Self> {
        let id = Uuid::new_v4();
        let key_hash = Self::hash_key(key);

        let api_key = sqlx::query_as::<_, ApiKey>(
            r#"
            INSERT INTO api_keys (id, user_id, name, key_hash)
            VALUES ($1, $2, $3, $4)
            RETURNING id, user_id, name, key_hash, last_used_at, created_at
            "#,
        )
        .bind(id)
        .bind(user_id)
        .bind(name)
        .bind(key_hash)
        .fetch_one(pool)
        .await?;

        Ok(api_key)
    }

    pub async fn validate(pool: &PgPool, key: &str) -> Result<Option<(Self, User)>> {
        let key_hash = Self::hash_key(key);

        // First find the API key
        let api_key = sqlx::query_as::<_, ApiKey>(
            r#"
            SELECT id, user_id, name, key_hash, last_used_at, created_at
            FROM api_keys
            WHERE key_hash = $1
            "#,
        )
        .bind(&key_hash)
        .fetch_optional(pool)
        .await?;

        match api_key {
            Some(api_key) => {
                // Then fetch the associated user
                let user = User::find_by_id(pool, api_key.user_id)
                    .await?
                    .ok_or_else(|| crate::HiveError::Auth("User not found for API key".into()))?;

                // Update last_used_at
                sqlx::query("UPDATE api_keys SET last_used_at = NOW() WHERE id = $1")
                    .bind(api_key.id)
                    .execute(pool)
                    .await?;

                Ok(Some((api_key, user)))
            }
            None => Ok(None),
        }
    }

    pub async fn list_for_user(pool: &PgPool, user_id: Uuid) -> Result<Vec<Self>> {
        let keys = sqlx::query_as::<_, ApiKey>(
            r#"
            SELECT id, user_id, name, key_hash, last_used_at, created_at
            FROM api_keys
            WHERE user_id = $1
            ORDER BY created_at
            "#,
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;

        Ok(keys)
    }

    pub async fn revoke(pool: &PgPool, key: &str) -> Result<bool> {
        let key_hash = Self::hash_key(key);

        let result = sqlx::query("DELETE FROM api_keys WHERE key_hash = $1")
            .bind(&key_hash)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn revoke_by_id(pool: &PgPool, id: Uuid) -> Result<bool> {
        let result = sqlx::query("DELETE FROM api_keys WHERE id = $1")
            .bind(id)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }
}

impl Connection {
    pub async fn create(
        pool: &PgPool,
        user_id: Uuid,
        name: &str,
        host: &str,
        port: i32,
        username: &str,
        ssh_key_id: Option<Uuid>,
        startup_command: Option<&str>,
    ) -> Result<Self> {
        let id = Uuid::new_v4();
        let conn = sqlx::query_as::<_, Connection>(
            r#"
            INSERT INTO connections (id, user_id, name, host, port, username, ssh_key_id, startup_command)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id, user_id, name, host, port, username, ssh_key_id, startup_command, created_at
            "#,
        )
        .bind(id)
        .bind(user_id)
        .bind(name)
        .bind(host)
        .bind(port)
        .bind(username)
        .bind(ssh_key_id)
        .bind(startup_command)
        .fetch_one(pool)
        .await?;

        Ok(conn)
    }

    pub async fn find_by_id(pool: &PgPool, id: Uuid) -> Result<Option<Self>> {
        let conn = sqlx::query_as::<_, Connection>(
            r#"
            SELECT id, user_id, name, host, port, username, ssh_key_id, startup_command, created_at
            FROM connections WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(pool)
        .await?;

        Ok(conn)
    }

    pub async fn list_for_user(pool: &PgPool, user_id: Uuid) -> Result<Vec<Self>> {
        let conns = sqlx::query_as::<_, Connection>(
            r#"
            SELECT id, user_id, name, host, port, username, ssh_key_id, startup_command, created_at
            FROM connections WHERE user_id = $1
            ORDER BY created_at
            "#,
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;

        Ok(conns)
    }

    pub async fn update(
        pool: &PgPool,
        id: Uuid,
        name: &str,
        host: &str,
        port: i32,
        username: &str,
        ssh_key_id: Option<Uuid>,
        startup_command: Option<&str>,
    ) -> Result<Option<Self>> {
        let conn = sqlx::query_as::<_, Connection>(
            r#"
            UPDATE connections
            SET name = $2, host = $3, port = $4, username = $5, ssh_key_id = $6, startup_command = $7
            WHERE id = $1
            RETURNING id, user_id, name, host, port, username, ssh_key_id, startup_command, created_at
            "#,
        )
        .bind(id)
        .bind(name)
        .bind(host)
        .bind(port)
        .bind(username)
        .bind(ssh_key_id)
        .bind(startup_command)
        .fetch_optional(pool)
        .await?;

        Ok(conn)
    }

    pub async fn delete(pool: &PgPool, id: Uuid) -> Result<bool> {
        let result = sqlx::query("DELETE FROM connections WHERE id = $1")
            .bind(id)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }
}

impl Session {
    pub async fn create(pool: &PgPool, user_id: Uuid, connection_id: Uuid) -> Result<Self> {
        let id = Uuid::new_v4();
        let session = sqlx::query_as::<_, Session>(
            r#"
            INSERT INTO sessions (id, user_id, connection_id, status)
            VALUES ($1, $2, $3, 'active')
            RETURNING id, user_id, connection_id, status, created_at, last_activity
            "#,
        )
        .bind(id)
        .bind(user_id)
        .bind(connection_id)
        .fetch_one(pool)
        .await?;

        Ok(session)
    }

    pub async fn find_by_id(pool: &PgPool, id: Uuid) -> Result<Option<Self>> {
        let session = sqlx::query_as::<_, Session>(
            r#"
            SELECT id, user_id, connection_id, status, created_at, last_activity
            FROM sessions WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(pool)
        .await?;

        Ok(session)
    }

    pub async fn list_for_user(pool: &PgPool, user_id: Uuid) -> Result<Vec<Self>> {
        let sessions = sqlx::query_as::<_, Session>(
            r#"
            SELECT id, user_id, connection_id, status, created_at, last_activity
            FROM sessions WHERE user_id = $1
            ORDER BY last_activity DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;

        Ok(sessions)
    }

    pub async fn list_active_for_user(pool: &PgPool, user_id: Uuid) -> Result<Vec<Self>> {
        let sessions = sqlx::query_as::<_, Session>(
            r#"
            SELECT id, user_id, connection_id, status, created_at, last_activity
            FROM sessions WHERE user_id = $1 AND status = 'active'
            ORDER BY last_activity DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;

        Ok(sessions)
    }

    pub async fn update_status(pool: &PgPool, id: Uuid, status: &str) -> Result<bool> {
        let result = sqlx::query("UPDATE sessions SET status = $2 WHERE id = $1")
            .bind(id)
            .bind(status)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn update_activity(pool: &PgPool, id: Uuid) -> Result<bool> {
        let result = sqlx::query("UPDATE sessions SET last_activity = NOW() WHERE id = $1")
            .bind(id)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn close(pool: &PgPool, id: Uuid) -> Result<bool> {
        Self::update_status(pool, id, "closed").await
    }
}

const SCROLLBACK_CHUNK_SIZE: usize = 65536; // 64KB chunks

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ScrollbackChunk {
    pub id: i64,
    pub session_id: Uuid,
    pub chunk_index: i32,
    pub data: Vec<u8>,
    pub created_at: DateTime<Utc>,
}

impl ScrollbackChunk {
    pub async fn append(pool: &PgPool, session_id: Uuid, data: &[u8]) -> Result<()> {
        // Get current max chunk index
        let current_max: Option<i32> = sqlx::query_scalar(
            "SELECT MAX(chunk_index) FROM scrollback_chunks WHERE session_id = $1",
        )
        .bind(session_id)
        .fetch_one(pool)
        .await?;

        let mut chunk_index = current_max.unwrap_or(-1);
        let mut remaining = data;

        // Get last chunk to see if we can append to it
        if chunk_index >= 0 {
            let last_chunk: Option<ScrollbackChunk> = sqlx::query_as(
                r#"
                SELECT id, session_id, chunk_index, data, created_at
                FROM scrollback_chunks
                WHERE session_id = $1 AND chunk_index = $2
                "#,
            )
            .bind(session_id)
            .bind(chunk_index)
            .fetch_optional(pool)
            .await?;

            if let Some(last) = last_chunk {
                let space_left = SCROLLBACK_CHUNK_SIZE - last.data.len();
                if space_left > 0 {
                    // Append to existing chunk
                    let to_append = std::cmp::min(space_left, remaining.len());
                    let mut new_data = last.data;
                    new_data.extend_from_slice(&remaining[..to_append]);

                    sqlx::query(
                        "UPDATE scrollback_chunks SET data = $1 WHERE session_id = $2 AND chunk_index = $3",
                    )
                    .bind(&new_data)
                    .bind(session_id)
                    .bind(chunk_index)
                    .execute(pool)
                    .await?;

                    remaining = &remaining[to_append..];
                }
            }
        }

        // Create new chunks for remaining data
        while !remaining.is_empty() {
            chunk_index += 1;
            let chunk_size = std::cmp::min(SCROLLBACK_CHUNK_SIZE, remaining.len());
            let chunk_data = &remaining[..chunk_size];

            sqlx::query(
                r#"
                INSERT INTO scrollback_chunks (session_id, chunk_index, data)
                VALUES ($1, $2, $3)
                "#,
            )
            .bind(session_id)
            .bind(chunk_index)
            .bind(chunk_data)
            .execute(pool)
            .await?;

            remaining = &remaining[chunk_size..];
        }

        Ok(())
    }

    pub async fn get_all(pool: &PgPool, session_id: Uuid) -> Result<Vec<u8>> {
        let chunks: Vec<ScrollbackChunk> = sqlx::query_as(
            r#"
            SELECT id, session_id, chunk_index, data, created_at
            FROM scrollback_chunks
            WHERE session_id = $1
            ORDER BY chunk_index
            "#,
        )
        .bind(session_id)
        .fetch_all(pool)
        .await?;

        let mut result = Vec::new();
        for chunk in chunks {
            result.extend_from_slice(&chunk.data);
        }

        Ok(result)
    }

    pub async fn get_from_offset(pool: &PgPool, session_id: Uuid, offset: usize) -> Result<Vec<u8>> {
        let chunks: Vec<ScrollbackChunk> = sqlx::query_as(
            r#"
            SELECT id, session_id, chunk_index, data, created_at
            FROM scrollback_chunks
            WHERE session_id = $1
            ORDER BY chunk_index
            "#,
        )
        .bind(session_id)
        .fetch_all(pool)
        .await?;

        let mut result = Vec::new();
        let mut current_offset = 0;

        for chunk in chunks {
            let chunk_len = chunk.data.len();
            if current_offset + chunk_len <= offset {
                current_offset += chunk_len;
                continue;
            }

            let start_in_chunk = if current_offset < offset {
                offset - current_offset
            } else {
                0
            };

            result.extend_from_slice(&chunk.data[start_in_chunk..]);
            current_offset += chunk_len;
        }

        Ok(result)
    }

    pub async fn total_size(pool: &PgPool, session_id: Uuid) -> Result<usize> {
        let size: Option<i64> = sqlx::query_scalar(
            "SELECT COALESCE(SUM(LENGTH(data)), 0)::BIGINT FROM scrollback_chunks WHERE session_id = $1",
        )
        .bind(session_id)
        .fetch_one(pool)
        .await?;

        Ok(size.unwrap_or(0) as usize)
    }

    pub async fn delete_for_session(pool: &PgPool, session_id: Uuid) -> Result<bool> {
        let result = sqlx::query("DELETE FROM scrollback_chunks WHERE session_id = $1")
            .bind(session_id)
            .execute(pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }
}
