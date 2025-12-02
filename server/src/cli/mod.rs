use clap::{Parser, Subcommand};
use sqlx::PgPool;
use tracing::info;

use crate::db::{ApiKey, User};
use crate::Result;

#[derive(Parser)]
#[command(name = "hive-server")]
#[command(about = "Hive Terminal Server")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,

    /// Database URL
    #[arg(long, env = "DATABASE_URL")]
    pub database_url: Option<String>,

    /// gRPC listen address
    #[arg(long, default_value = "[::1]:50051")]
    pub listen: String,
}

#[derive(Subcommand)]
pub enum Commands {
    /// User management
    User {
        #[command(subcommand)]
        action: UserCommands,
    },
    /// API key management
    Key {
        #[command(subcommand)]
        action: KeyCommands,
    },
    /// Run migrations
    Migrate,
    /// Start the server
    Serve,
}

#[derive(Subcommand)]
pub enum UserCommands {
    /// Create a new user
    Create {
        /// Username
        username: String,
    },
    /// List all users
    List,
}

#[derive(Subcommand)]
pub enum KeyCommands {
    /// Create a new API key for a user
    Create {
        /// Username
        #[arg(long)]
        user: String,
        /// Key name/description
        #[arg(long)]
        name: String,
    },
    /// List API keys for a user
    List {
        /// Username
        #[arg(long)]
        user: String,
    },
    /// Revoke an API key
    Revoke {
        /// API key to revoke
        key: String,
    },
}

pub async fn handle_user_command(pool: &PgPool, action: UserCommands) -> Result<()> {
    match action {
        UserCommands::Create { username } => {
            let user = User::create(pool, &username).await?;
            info!("Created user: {} (id: {})", user.username, user.id);
            println!("Created user: {} (id: {})", user.username, user.id);
        }
        UserCommands::List => {
            let users = User::list(pool).await?;
            if users.is_empty() {
                println!("No users found");
            } else {
                println!("{:<36} {:<20} {}", "ID", "Username", "Created");
                println!("{}", "-".repeat(70));
                for user in users {
                    println!(
                        "{:<36} {:<20} {}",
                        user.id,
                        user.username,
                        user.created_at.format("%Y-%m-%d %H:%M:%S")
                    );
                }
            }
        }
    }
    Ok(())
}

pub async fn handle_key_command(pool: &PgPool, action: KeyCommands) -> Result<()> {
    match action {
        KeyCommands::Create { user, name } => {
            let user_record = User::find_by_username(pool, &user)
                .await?
                .ok_or_else(|| crate::HiveError::Auth(format!("User not found: {}", user)))?;

            let key = ApiKey::generate_key();
            let api_key = ApiKey::create(pool, user_record.id, &name, &key).await?;

            info!(
                "Created API key for user {}: {} (id: {})",
                user, name, api_key.id
            );
            println!("\nAPI Key created successfully!");
            println!("Key: {}", key);
            println!("\nSave this key - it cannot be retrieved later.");
        }
        KeyCommands::List { user } => {
            let user_record = User::find_by_username(pool, &user)
                .await?
                .ok_or_else(|| crate::HiveError::Auth(format!("User not found: {}", user)))?;

            let keys = ApiKey::list_for_user(pool, user_record.id).await?;

            if keys.is_empty() {
                println!("No API keys found for user {}", user);
            } else {
                println!("API keys for user {}:", user);
                println!("{:<36} {:<20} {:<20} {}", "ID", "Name", "Created", "Last Used");
                println!("{}", "-".repeat(90));
                for key in keys {
                    let last_used = key
                        .last_used_at
                        .map(|t| t.format("%Y-%m-%d %H:%M:%S").to_string())
                        .unwrap_or_else(|| "Never".to_string());
                    println!(
                        "{:<36} {:<20} {:<20} {}",
                        key.id,
                        key.name,
                        key.created_at.format("%Y-%m-%d %H:%M:%S"),
                        last_used
                    );
                }
            }
        }
        KeyCommands::Revoke { key } => {
            let revoked = ApiKey::revoke(pool, &key).await?;
            if revoked {
                info!("Revoked API key");
                println!("API key revoked successfully");
            } else {
                println!("API key not found");
            }
        }
    }
    Ok(())
}
