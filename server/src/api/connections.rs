use sqlx::PgPool;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

use crate::db::Connection;
use crate::proto::connections_server::Connections;
use crate::proto::{
    Connection as ProtoConnection, ConnectionListResponse, CreateConnectionRequest,
    DeleteConnectionRequest, Empty, UpdateConnectionRequest,
};

pub struct ConnectionsService {
    pool: PgPool,
}

impl ConnectionsService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    fn extract_user_id(request: &Request<impl std::fmt::Debug>) -> Result<Uuid, Status> {
        request
            .metadata()
            .get("x-user-id")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| Uuid::parse_str(s).ok())
            .ok_or_else(|| Status::unauthenticated("Missing or invalid user ID"))
    }

    fn connection_to_proto(conn: Connection) -> ProtoConnection {
        ProtoConnection {
            id: conn.id.to_string(),
            name: conn.name,
            host: conn.host,
            port: conn.port,
            username: conn.username,
            ssh_key_id: conn.ssh_key_id.map(|id| id.to_string()).unwrap_or_default(),
            startup_command: conn.startup_command.unwrap_or_default(),
            created_at: conn.created_at.to_rfc3339(),
        }
    }
}

#[tonic::async_trait]
impl Connections for ConnectionsService {
    async fn list(&self, request: Request<Empty>) -> Result<Response<ConnectionListResponse>, Status> {
        let user_id = Self::extract_user_id(&request)?;

        let connections = Connection::list_for_user(&self.pool, user_id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?;

        let proto_connections: Vec<ProtoConnection> = connections
            .into_iter()
            .map(Self::connection_to_proto)
            .collect();

        info!("Listed {} connections for user {}", proto_connections.len(), user_id);

        Ok(Response::new(ConnectionListResponse {
            connections: proto_connections,
        }))
    }

    async fn create(
        &self,
        request: Request<CreateConnectionRequest>,
    ) -> Result<Response<ProtoConnection>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let req = request.into_inner();

        let ssh_key_id = if req.ssh_key_id.is_empty() {
            None
        } else {
            Some(
                Uuid::parse_str(&req.ssh_key_id)
                    .map_err(|_| Status::invalid_argument("Invalid SSH key ID"))?,
            )
        };

        let startup_command = if req.startup_command.is_empty() {
            None
        } else {
            Some(req.startup_command.as_str())
        };

        let connection = Connection::create(
            &self.pool,
            user_id,
            &req.name,
            &req.host,
            req.port,
            &req.username,
            ssh_key_id,
            startup_command,
        )
        .await
        .map_err(|e| Status::internal(format!("Failed to create connection: {}", e)))?;

        info!("Created connection {} for user {}", connection.id, user_id);

        Ok(Response::new(Self::connection_to_proto(connection)))
    }

    async fn update(
        &self,
        request: Request<UpdateConnectionRequest>,
    ) -> Result<Response<ProtoConnection>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let req = request.into_inner();

        let id = Uuid::parse_str(&req.id)
            .map_err(|_| Status::invalid_argument("Invalid connection ID"))?;

        // Verify ownership
        let existing = Connection::find_by_id(&self.pool, id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?
            .ok_or_else(|| Status::not_found("Connection not found"))?;

        if existing.user_id != user_id {
            return Err(Status::permission_denied("Not authorized to update this connection"));
        }

        let ssh_key_id = if req.ssh_key_id.is_empty() {
            None
        } else {
            Some(
                Uuid::parse_str(&req.ssh_key_id)
                    .map_err(|_| Status::invalid_argument("Invalid SSH key ID"))?,
            )
        };

        let startup_command = if req.startup_command.is_empty() {
            None
        } else {
            Some(req.startup_command.as_str())
        };

        let connection = Connection::update(
            &self.pool,
            id,
            &req.name,
            &req.host,
            req.port,
            &req.username,
            ssh_key_id,
            startup_command,
        )
        .await
        .map_err(|e| Status::internal(format!("Failed to update connection: {}", e)))?
        .ok_or_else(|| Status::not_found("Connection not found"))?;

        info!("Updated connection {} for user {}", id, user_id);

        Ok(Response::new(Self::connection_to_proto(connection)))
    }

    async fn delete(&self, request: Request<DeleteConnectionRequest>) -> Result<Response<Empty>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let req = request.into_inner();

        let id = Uuid::parse_str(&req.id)
            .map_err(|_| Status::invalid_argument("Invalid connection ID"))?;

        // Verify ownership
        let existing = Connection::find_by_id(&self.pool, id)
            .await
            .map_err(|e| Status::internal(format!("Database error: {}", e)))?
            .ok_or_else(|| Status::not_found("Connection not found"))?;

        if existing.user_id != user_id {
            return Err(Status::permission_denied("Not authorized to delete this connection"));
        }

        Connection::delete(&self.pool, id)
            .await
            .map_err(|e| Status::internal(format!("Failed to delete connection: {}", e)))?;

        info!("Deleted connection {} for user {}", id, user_id);

        Ok(Response::new(Empty {}))
    }
}
