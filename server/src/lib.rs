pub mod api;
pub mod cli;
pub mod db;
pub mod ssh;
pub mod terminal;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum HiveError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Migration error: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),

    #[error("Authentication error: {0}")]
    Auth(String),

    #[error("SSH error: {0}")]
    Ssh(String),

    #[error("Session error: {0}")]
    Session(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, HiveError>;

pub mod proto {
    tonic::include_proto!("hive");
}
