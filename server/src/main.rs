use clap::Parser;
use tonic::transport::Server;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use std::sync::Arc;

use hive_server::api::{AuthService, ConnectionsService, SessionsService};
use hive_server::cli::{handle_key_command, handle_user_command, Cli, Commands};
use hive_server::db::{create_pool, run_migrations};
use hive_server::proto::auth_server::AuthServer;
use hive_server::proto::connections_server::ConnectionsServer;
use hive_server::proto::sessions_server::SessionsServer;
use hive_server::proto::terminal_server::TerminalServer;
use hive_server::terminal::{SessionManager, TerminalService};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "hive_server=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let cli = Cli::parse();

    let database_url = cli
        .database_url
        .clone()
        .or_else(|| std::env::var("DATABASE_URL").ok())
        .ok_or_else(|| anyhow::anyhow!("DATABASE_URL not set"))?;

    let pool = create_pool(&database_url).await?;

    match cli.command {
        Some(Commands::Migrate) => {
            info!("Running migrations...");
            run_migrations(&pool).await?;
            info!("Migrations completed");
        }
        Some(Commands::User { action }) => {
            handle_user_command(&pool, action).await?;
        }
        Some(Commands::Key { action }) => {
            handle_key_command(&pool, action).await?;
        }
        Some(Commands::Serve) | None => {
            // Run migrations before starting server
            run_migrations(&pool).await?;

            let addr = cli.listen.parse()?;
            info!("Starting Hive Server on {}", addr);

            let session_manager = Arc::new(SessionManager::new(pool.clone()));

            let auth_service = AuthService::new(pool.clone());
            let connections_service = ConnectionsService::new(pool.clone());
            let sessions_service = SessionsService::new(pool.clone(), session_manager.clone());
            let terminal_service = TerminalService::new(session_manager);

            Server::builder()
                .add_service(AuthServer::new(auth_service))
                .add_service(ConnectionsServer::new(connections_service))
                .add_service(SessionsServer::new(sessions_service))
                .add_service(TerminalServer::new(terminal_service))
                .serve(addr)
                .await?;
        }
    }

    Ok(())
}
