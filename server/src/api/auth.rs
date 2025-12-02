use sqlx::PgPool;
use tonic::{Request, Response, Status};
use tracing::info;

use crate::db::ApiKey;
use crate::proto::auth_server::Auth;
use crate::proto::{ApiKeyRequest, AuthResponse};

pub struct AuthService {
    pool: PgPool,
}

impl AuthService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[tonic::async_trait]
impl Auth for AuthService {
    async fn validate_api_key(
        &self,
        request: Request<ApiKeyRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let api_key = &request.get_ref().api_key;

        match ApiKey::validate(&self.pool, api_key).await {
            Ok(Some((_, user))) => {
                info!("API key validated for user: {}", user.username);
                Ok(Response::new(AuthResponse {
                    valid: true,
                    user_id: user.id.to_string(),
                    username: user.username,
                }))
            }
            Ok(None) => {
                info!("Invalid API key attempted");
                Ok(Response::new(AuthResponse {
                    valid: false,
                    user_id: String::new(),
                    username: String::new(),
                }))
            }
            Err(e) => {
                tracing::error!("Database error during API key validation: {}", e);
                Err(Status::internal("Internal error"))
            }
        }
    }
}
