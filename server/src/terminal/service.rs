use std::pin::Pin;
use std::sync::Arc;

use futures::Stream;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tokio_stream::StreamExt;
use tonic::{Request, Response, Status, Streaming};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use super::SessionManager;
use crate::proto::terminal_server::Terminal;
use crate::proto::{terminal_input, terminal_output, Error as ProtoError, TerminalInput, TerminalOutput};

pub struct TerminalService {
    session_manager: Arc<SessionManager>,
}

impl TerminalService {
    pub fn new(session_manager: Arc<SessionManager>) -> Self {
        Self { session_manager }
    }

    fn extract_user_id(request: &Request<Streaming<TerminalInput>>) -> Result<Uuid, Status> {
        request
            .metadata()
            .get("x-user-id")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| Uuid::parse_str(s).ok())
            .ok_or_else(|| Status::unauthenticated("Missing or invalid user ID"))
    }
}

#[tonic::async_trait]
impl Terminal for TerminalService {
    type AttachStream = Pin<Box<dyn Stream<Item = Result<TerminalOutput, Status>> + Send>>;

    async fn attach(
        &self,
        request: Request<Streaming<TerminalInput>>,
    ) -> Result<Response<Self::AttachStream>, Status> {
        let user_id = Self::extract_user_id(&request)?;
        let mut input_stream = request.into_inner();

        // Wait for the first message to get the session_id
        let first_msg = input_stream
            .next()
            .await
            .ok_or_else(|| Status::invalid_argument("No initial message received"))?
            .map_err(|e| Status::internal(format!("Stream error: {}", e)))?;

        let session_id = Uuid::parse_str(&first_msg.session_id)
            .map_err(|_| Status::invalid_argument("Invalid session ID"))?;

        info!("User {} attaching to session {}", user_id, session_id);

        // Get the session and subscribe to output
        let session = self
            .session_manager
            .get_session(session_id)
            .await
            .ok_or_else(|| Status::not_found("Session not found"))?;

        let output_rx = {
            let session = session.lock().await;
            if session.user_id != user_id {
                return Err(Status::permission_denied("Not authorized to access this session"));
            }
            session.subscribe()
        };

        // Create gRPC output stream
        let (output_tx, output_rx_grpc) = mpsc::channel::<Result<TerminalOutput, Status>>(1024);

        // Task to forward SSH output to gRPC stream
        let output_tx_clone = output_tx.clone();
        let mut output_rx = output_rx;
        tokio::spawn(async move {
            loop {
                match output_rx.recv().await {
                    Ok(data) => {
                        if let Err(e) = output_tx_clone
                            .send(Ok(TerminalOutput {
                                payload: Some(terminal_output::Payload::Data(data)),
                            }))
                            .await
                        {
                            debug!("Output channel closed: {}", e);
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                        info!("SSH output channel closed");
                        break;
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(n)) => {
                        warn!("Lagged behind {} messages", n);
                    }
                }
            }
        });

        // Task to handle input from gRPC stream
        let session_for_input = session.clone();
        let output_tx_for_input = output_tx.clone();
        tokio::spawn(async move {
            while let Some(result) = input_stream.next().await {
                match result {
                    Ok(input) => {
                        let session = session_for_input.lock().await;

                        match input.payload {
                            Some(terminal_input::Payload::Data(data)) => {
                                debug!("Received {} bytes of input", data.len());
                                if let Err(e) = session.send(&data).await {
                                    error!("Failed to send input: {}", e);
                                    let _ = output_tx_for_input
                                        .send(Ok(TerminalOutput {
                                            payload: Some(terminal_output::Payload::Error(ProtoError {
                                                code: "SSH_ERROR".to_string(),
                                                message: format!("Failed to send input: {}", e),
                                            })),
                                        }))
                                        .await;
                                    break;
                                }
                            }
                            Some(terminal_input::Payload::Resize(resize)) => {
                                debug!("Resizing to {}x{}", resize.cols, resize.rows);
                                if let Err(e) = session.resize(resize.cols, resize.rows).await {
                                    warn!("Failed to resize: {}", e);
                                }
                            }
                            Some(terminal_input::Payload::File(file)) => {
                                info!("File upload: {} ({} bytes)", file.filename, file.data.len());
                                // TODO: Handle file upload - save to temp dir and send path
                            }
                            None => {}
                        }
                    }
                    Err(e) => {
                        error!("Input stream error: {}", e);
                        break;
                    }
                }
            }

            info!("Input stream ended for session {}", session_id);
        });

        let output_stream = ReceiverStream::new(output_rx_grpc);
        Ok(Response::new(Box::pin(output_stream)))
    }
}
