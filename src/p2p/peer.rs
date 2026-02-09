use super::message::{
    AddressEntry, MAGIC, Message, PeerVersion, build_version_message, parse_message,
    serialize_message,
};
use crate::db::{AddressDb, NodeInfo, NodeType};
use anyhow::Result;
use chrono::Utc;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio::time::{Duration, Instant as TokioInstant, interval_at};
use tracing::{debug, info, warn};

const MAX_MESSAGE_SIZE: usize = 4 * 1024 * 1024; // 4MB
const OUTBOUND_QUEUE_CAPACITY: usize = 2048;

#[derive(Debug)]
pub enum PeerEvent {
    Connected {
        addr: SocketAddr,
        version: PeerVersion,
    },
    Disconnected {
        addr: SocketAddr,
        reason: String,
    },
    Message {
        addr: SocketAddr,
        message: Message,
    },
    Addresses {
        addr: SocketAddr,
        addrs: Vec<AddressEntry>,
    },
}

#[derive(Debug, Clone)]
pub struct PeerHandle {
    addr: SocketAddr,
    sender: mpsc::Sender<Message>,
    node_type: NodeType,
    user_agent: String,
}

impl PeerHandle {
    pub fn send(&self, msg: Message) -> Result<()> {
        self.sender
            .try_send(msg)
            .map_err(|e| anyhow::anyhow!("message queue send failed: {}", e))?;
        Ok(())
    }

    pub fn addr(&self) -> SocketAddr {
        self.addr
    }

    pub fn node_type(&self) -> NodeType {
        self.node_type
    }

    pub fn user_agent(&self) -> &str {
        &self.user_agent
    }
}

pub struct Peer {
    addr: SocketAddr,
    stream: TcpStream,
    our_addr: SocketAddr,
    db: Arc<AddressDb>,
    event_tx: mpsc::UnboundedSender<PeerEvent>,
    to_peer_rx: mpsc::Receiver<Message>,
    to_peer_tx: mpsc::Sender<Message>,
    node_type: NodeType,
    version: Option<PeerVersion>,
    user_agent: String,
}

impl Peer {
    pub async fn connect(
        addr: SocketAddr,
        our_addr: SocketAddr,
        user_agent: String,
        db: Arc<AddressDb>,
        event_tx: mpsc::UnboundedSender<PeerEvent>,
        start_height: i32,
    ) -> Result<Self> {
        let stream = TcpStream::connect(addr).await?;
        let local_addr = stream.local_addr().unwrap_or(our_addr);
        info!("Connected to peer {}", addr);

        let (to_peer_tx, to_peer_rx) = mpsc::channel(OUTBOUND_QUEUE_CAPACITY);

        let mut peer = Self {
            addr,
            stream,
            our_addr: local_addr,
            db,
            event_tx,
            to_peer_rx,
            to_peer_tx,
            node_type: NodeType::Unknown,
            version: None,
            user_agent,
        };

        peer.handshake(start_height).await?;

        Ok(peer)
    }

    pub async fn accept(
        stream: TcpStream,
        our_addr: SocketAddr,
        user_agent: String,
        db: Arc<AddressDb>,
        event_tx: mpsc::UnboundedSender<PeerEvent>,
        start_height: i32,
    ) -> Result<Self> {
        let addr = stream.peer_addr()?;
        let local_addr = stream.local_addr().unwrap_or(our_addr);
        info!("Accepted connection from {}", addr);

        let (to_peer_tx, to_peer_rx) = mpsc::channel(OUTBOUND_QUEUE_CAPACITY);

        let mut peer = Self {
            addr,
            stream,
            our_addr: local_addr,
            db,
            event_tx,
            to_peer_rx,
            to_peer_tx,
            node_type: NodeType::Unknown,
            version: None,
            user_agent,
        };

        peer.handshake(start_height).await?;

        Ok(peer)
    }

    async fn handshake(&mut self, start_height: i32) -> Result<()> {
        // Send version
        let version =
            build_version_message(self.our_addr, self.addr, start_height, &self.user_agent);
        self.send_message(&Message::Version(version)).await?;

        // Wait for their version
        let their_version = loop {
            match self.recv_message().await? {
                Some(Message::Version(v)) => break v,
                Some(_) => continue, // Ignore other messages until version
                None => anyhow::bail!("Connection closed during handshake"),
            }
        };

        let peer_version = PeerVersion::from_version_message(&their_version);
        self.node_type = NodeType::from_user_agent(&peer_version.user_agent);
        self.version = Some(peer_version.clone());

        info!(
            "Peer {} is {:?} (agent: {}, version: {})",
            self.addr, self.node_type, peer_version.user_agent, peer_version.version
        );

        // Send verack
        self.send_message(&Message::Verack).await?;

        // Wait for their verack
        loop {
            match self.recv_message().await? {
                Some(Message::Verack) => break,
                Some(_) => continue,
                None => anyhow::bail!("Connection closed during handshake"),
            }
        }

        // Update database
        let user_agent = peer_version.user_agent.clone();
        let node_info = NodeInfo {
            addr: self.addr,
            node_type: self.node_type,
            user_agent: Some(user_agent),
            version: Some(peer_version.version as i32),
            services: Some(peer_version.services.to_u64()),
            last_seen: Utc::now(),
            last_connected: Some(Utc::now()),
            connection_failures: 0,
            is_reachable: true,
        };
        let _ = self.db.insert_or_update(&node_info)?;

        // Notify manager
        self.event_tx.send(PeerEvent::Connected {
            addr: self.addr,
            version: peer_version,
        })?;

        Ok(())
    }

    pub fn handle(&self) -> PeerHandle {
        PeerHandle {
            addr: self.addr,
            sender: self.to_peer_tx.clone(),
            node_type: self.node_type,
            user_agent: self
                .version
                .as_ref()
                .map(|v| v.user_agent.clone())
                .unwrap_or_default(),
        }
    }

    pub async fn run(mut self) {
        let mut buf = [0u8; 8192];
        let mut accumulated = Vec::new();
        let mut keepalive = interval_at(
            TokioInstant::now() + Duration::from_secs(30),
            Duration::from_secs(30),
        );

        loop {
            tokio::select! {
                // Read from socket
                result = self.stream.read(&mut buf) => {
                    match result {
                        Ok(0) => {
                            let _ = self.event_tx.send(PeerEvent::Disconnected {
                                addr: self.addr,
                                reason: "Connection closed by peer".to_string(),
                            });
                            break;
                        }
                        Ok(n) => {
                            accumulated.extend_from_slice(&buf[..n]);
                            self.process_buffer(&mut accumulated).await;
                        }
                        Err(e) => {
                            let _ = self.event_tx.send(PeerEvent::Disconnected {
                                addr: self.addr,
                                reason: format!("Read error: {}", e),
                            });
                            break;
                        }
                    }
                }

                // Send to peer
                Some(msg) = self.to_peer_rx.recv() => {
                    if let Err(e) = self.send_message(&msg).await {
                        warn!("Failed to send message to {}: {}", self.addr, e);
                        let _ = self.event_tx.send(PeerEvent::Disconnected {
                            addr: self.addr,
                            reason: format!("Send error: {}", e),
                        });
                        break;
                    }
                }

                _ = keepalive.tick() => {
                    if let Err(e) = self.send_message(&Message::Ping(rand::random())).await {
                        warn!("Failed to send ping to {}: {}", self.addr, e);
                        let _ = self.event_tx.send(PeerEvent::Disconnected {
                            addr: self.addr,
                            reason: format!("Ping error: {}", e),
                        });
                        break;
                    }
                }
            }
        }
    }

    async fn process_buffer(&mut self, buf: &mut Vec<u8>) {
        // Bitcoin P2P messages have a header of 24 bytes
        // 4 magic, 12 command, 4 length, 4 checksum
        loop {
            if buf.len() < 24 {
                return;
            }

            let payload_len = u32::from_le_bytes([buf[16], buf[17], buf[18], buf[19]]) as usize;

            if payload_len > MAX_MESSAGE_SIZE {
                warn!(
                    "Oversized message from {}: {} bytes",
                    self.addr, payload_len
                );
                buf.clear();
                return;
            }

            let total_len = 24 + payload_len;
            if buf.len() < total_len {
                return;
            }

            let message_data = buf[..total_len].to_vec();
            buf.drain(..total_len);

            match parse_message(&message_data) {
                Ok(msg) => {
                    debug!(
                        "Received {:?} from {}",
                        std::mem::discriminant(&msg),
                        self.addr
                    );
                    self.handle_message(msg).await;
                }
                Err(e) => {
                    debug!("Failed to parse message from {}: {}", self.addr, e);
                }
            }
        }
    }

    async fn handle_message(&mut self, msg: Message) {
        match msg {
            Message::Ping(nonce) => {
                let _ = self.send_message(&Message::Pong(nonce)).await;
            }
            Message::Addr(entries) => {
                let _ = self.event_tx.send(PeerEvent::Addresses {
                    addr: self.addr,
                    addrs: entries,
                });
            }
            message => {
                // Forward other messages to manager
                let _ = self.event_tx.send(PeerEvent::Message {
                    addr: self.addr,
                    message,
                });
            }
        }
    }

    async fn send_message(&mut self, msg: &Message) -> Result<()> {
        let data = serialize_message(msg, MAGIC)?;
        self.stream.write_all(&data).await?;
        self.stream.flush().await?;
        Ok(())
    }

    async fn recv_message(&mut self) -> Result<Option<Message>> {
        let mut header = [0u8; 24];
        self.stream.read_exact(&mut header).await?;

        let payload_len =
            u32::from_le_bytes([header[16], header[17], header[18], header[19]]) as usize;

        if payload_len > MAX_MESSAGE_SIZE {
            anyhow::bail!("Payload too large: {}", payload_len);
        }

        let mut payload = vec![0u8; payload_len];
        if payload_len > 0 {
            self.stream.read_exact(&mut payload).await?;
        }

        let mut full_message = Vec::with_capacity(24 + payload_len);
        full_message.extend_from_slice(&header);
        full_message.extend_from_slice(&payload);

        Ok(Some(parse_message(&full_message)?))
    }
}
