use std::sync::Arc;

use sqlx::PgPool;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

use crate::db::{Connection, Session};
use crate::proto::sessions_server::Sessions;
use crate::proto::{
    CloseSessionRequest, CreateSessionRequest, Empty, Session as ProtoSession,
    SessionListResponse,
};
use crate::terminal::SessionManager;

pub struct SessionsService {
    pool: PgPool,
    session_manager: Arc<SessionManager>,
}

impl SessionsService {
    pub fn new(pool: PgPool, session_manager: Arc<SessionManager>) -> Self {
        Self { pool, session_manager }
    }

    fn extract_user_id(request: &Request<impl std::fmt::Debug>) -> Result<Uuid, Status> {
        request
            .metadata()
            .get("x-user-id")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| Uuid::parse_str(s).ok())
            .ok_or_else(|| Status::unauthenticated("Missing or invalid user ID"))
    }

    async fn session_to_proto(&self, session: Session) -> Result<ProtoSession, Status> {
        let connection = Connection::find_by_id(&self.pool, session.connection_id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?;

        let connection_name = connection.map(|c| c.name).unwrap_or_default();

        Ok(ProtoSession {
            id: session.id.to_string(),
            connection_id: session.connection_id.to_string(),
            connection_name,
            status: session.status,
            created_at: session.created_at.to_rfc3339(),
            last_activity: session.last_activity.to_rfc3339(),
        })
    }
}

#[tonic::async_trait]
impl Sessions for SessionsService {
    async fn list(&self, request: Request<Empty>) -> Result<Response<SessionListResponse>, Status> {
        let user_id = Self::extract_user_id(&request)?;

        let sessions = Session::list_for_user(&self.pool, user_id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?;

        let mut proto_sessions = Vec::with_capacity(sessions.len());
        for session in sessions {
            proto_sessions.push(self.session_to_proto(session).await?);
        }

        info!("Listed {} sessions for user {}", proto_sessions.len(), user_id);

        Ok(Response::new(SessionListResponse {
            sessions: proto_sessions,
        }))
    }

    async fn create(
        &self,
        request: Request<CreateSessionRequest>,
    ) -> Result<Response<ProtoSession>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let req = request.into_inner();

        let connection_id = Uuid::parse_str(&req.connection_id)
            .map_err(|_| Status::invalid_argument("Invalid connection ID"))?;

        // Verify connection exists and belongs to user
        let connection = Connection::find_by_id(&self.pool, connection_id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?
            .ok_or_else(|| Status::not_found("Connection not found"))?;

        if connection.user_id != user_id {
            return Err(Status::permission_denied("Not authorized to use this connection"));
        }

        // Create SSH session via SessionManager (establishes connection)
        let (session_id, _output_rx) = self.session_manager
            .create_session(user_id, connection_id, 80, 24, &req.password)
            .await
            .map_err(|e| Status::internal(format!("Failed to create session: {}", e)))?;

        // Get session from DB for response
        let session = Session::find_by_id(&self.pool, session_id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?
            .ok_or_else(|| Status::internal("Session not found after creation"))?;

        info!(
            "Created session {} for connection {} (user {})",
            session.id, connection_id, user_id
        );

        Ok(Response::new(ProtoSession {
            id: session.id.to_string(),
            connection_id: session.connection_id.to_string(),
            connection_name: connection.name,
            status: session.status,
            created_at: session.created_at.to_rfc3339(),
            last_activity: session.last_activity.to_rfc3339(),
        }))
    }

    async fn close(&self, request: Request<CloseSessionRequest>) -> Result<Response<Empty>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let req = request.into_inner();

        let id = Uuid::parse_str(&req.id)
            .map_err(|_| Status::invalid_argument("Invalid session ID"))?;

        // Verify ownership
        let session = Session::find_by_id(&self.pool, id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?
            .ok_or_else(|| Status::not_found("Session not found"))?;

        if session.user_id != user_id {
            return Err(Status::permission_denied("Not authorized to close this session"));
        }

        Session::close(&self.pool, id)
            .await
            .map_err(|e| Status::internal(format!("Failed to close session: {}", e)))?;

        info!("Closed session {} for user {}", id, user_id);

        Ok(Response::new(Empty {}))
    }
}
