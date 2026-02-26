use crate::db::{AddressDb, NodeType};
use crate::discovery::DiscoveryService;
use crate::metrics::Metrics;
use crate::p2p::message::{AddressEntry, Inventory, Message};
use crate::p2p::{Peer, PeerEvent, PeerHandle};
use bitcoin::p2p::ServiceFlags;
use bitcoin::hashes::Hash;
use bitcoin::{Transaction, Txid, Wtxid};
use chrono::Utc;
use rand::seq::SliceRandom;
use std::collections::HashMap;
use std::collections::HashSet;
use std::collections::VecDeque;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::net::TcpListener;
use tokio::sync::RwLock;
use tokio::sync::mpsc;
use tokio::time::timeout;
use tracing::{info, warn};

const SEEN_TX_CACHE_LIMIT: usize = 100_000;
const RECENT_TX_CACHE_LIMIT: usize = 20_000;
const REQUESTED_TXID_TTL: Duration = Duration::from_secs(120);
const OUTBOUND_REFILL_INTERVAL: Duration = Duration::from_secs(3);
const MAX_CONNECT_ATTEMPTS_PER_TICK: usize = 192;
const GETADDR_RESPONSE_LIMIT: usize = 50;

#[derive(Default)]
struct RelayState {
    seen_txids: HashSet<[u8; 32]>,
    seen_order: VecDeque<[u8; 32]>,
    requested_txids: HashMap<[u8; 32], Instant>,
    tx_cache: HashMap<Txid, Transaction>,
    tx_by_wtxid: HashMap<Wtxid, Txid>,
    tx_cache_order: VecDeque<Txid>,
}

impl RelayState {
    fn mark_requested(&mut self, key: [u8; 32], now: Instant) -> bool {
        self.cleanup_requested(now);
        if self.seen_txids.contains(&key) || self.requested_txids.contains_key(&key) {
            return false;
        }
        self.requested_txids.insert(key, now);
        true
    }

    fn mark_seen(&mut self, key: [u8; 32]) -> bool {
        if self.seen_txids.contains(&key) {
            return false;
        }

        self.seen_txids.insert(key);
        self.seen_order.push_back(key);
        while self.seen_order.len() > SEEN_TX_CACHE_LIMIT {
            if let Some(oldest) = self.seen_order.pop_front() {
                self.seen_txids.remove(&oldest);
            }
        }
        true
    }

    fn complete_request(&mut self, key: [u8; 32]) {
        self.requested_txids.remove(&key);
    }

    fn insert_tx(&mut self, txid: Txid, tx: Transaction) {
        self.tx_by_wtxid.insert(tx.compute_wtxid(), txid);
        if !self.tx_cache.contains_key(&txid) {
            self.tx_cache_order.push_back(txid);
        }
        self.tx_cache.insert(txid, tx);

        while self.tx_cache_order.len() > RECENT_TX_CACHE_LIMIT {
            if let Some(oldest) = self.tx_cache_order.pop_front() {
                self.tx_by_wtxid
                    .retain(|_, mapped_txid| mapped_txid != &oldest);
                self.tx_cache.remove(&oldest);
            }
        }
    }

    fn get_tx(&self, txid: &Txid) -> Option<Transaction> {
        self.tx_cache.get(txid).cloned()
    }

    fn get_tx_by_wtxid(&self, wtxid: &Wtxid) -> Option<Transaction> {
        self.tx_by_wtxid
            .get(wtxid)
            .and_then(|txid| self.get_tx(txid))
    }

    fn cleanup_requested(&mut self, now: Instant) {
        self.requested_txids
            .retain(|_, requested_at| now.duration_since(*requested_at) < REQUESTED_TXID_TTL);
    }
}

pub struct PeerManager {
    db: Arc<AddressDb>,
    metrics: Arc<RwLock<Metrics>>,
    target_peers: usize,
    peers: Arc<RwLock<Vec<PeerHandle>>>,
    pending_outbound: Arc<RwLock<HashSet<SocketAddr>>>,
    relay_state: Arc<RwLock<RelayState>>,
    our_addr: SocketAddr,
    user_agent: String,
    peer_timeout: Duration,
    start_height: i32,
    discovery: Option<Arc<DiscoveryService>>,
}

impl PeerManager {
    pub fn new(
        db: Arc<AddressDb>,
        metrics: Arc<RwLock<Metrics>>,
        target_peers: usize,
        our_addr: SocketAddr,
        user_agent: String,
        peer_timeout_secs: u64,
    ) -> Self {
        Self {
            db,
            metrics,
            target_peers,
            peers: Arc::new(RwLock::new(Vec::new())),
            pending_outbound: Arc::new(RwLock::new(HashSet::new())),
            relay_state: Arc::new(RwLock::new(RelayState::default())),
            our_addr,
            user_agent,
            peer_timeout: Duration::from_secs(peer_timeout_secs),
            start_height: 0,
            discovery: None,
        }
    }

    pub fn peers(&self) -> Arc<RwLock<Vec<PeerHandle>>> {
        self.peers.clone()
    }

    pub fn set_discovery_service(&mut self, discovery: Arc<DiscoveryService>) {
        self.discovery = Some(discovery);
    }

    pub async fn run(&self) {
        let (event_tx, mut event_rx) = mpsc::unbounded_channel();

        // Spawn inbound listener task
        let listen_db = self.db.clone();
        let listen_metrics = self.metrics.clone();
        let listen_peers = self.peers.clone();
        let listen_event_tx = event_tx.clone();
        let listen_our_addr = self.our_addr;
        let listen_timeout = self.peer_timeout;
        let listen_start_height = self.start_height;
        let listen_user_agent = self.user_agent.clone();

        tokio::spawn(async move {
            let bind_addr =
                SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), listen_our_addr.port());
            let listener = match TcpListener::bind(bind_addr).await {
                Ok(listener) => {
                    info!("Listening for inbound peers on {}", bind_addr);
                    listener
                }
                Err(e) => {
                    warn!("Failed to bind inbound listener on {}: {}", bind_addr, e);
                    return;
                }
            };

            loop {
                match listener.accept().await {
                    Ok((stream, _)) => {
                        let event_tx = listen_event_tx.clone();
                        let db = listen_db.clone();
                        let our_addr = listen_our_addr;
                        let metrics = listen_metrics.clone();
                        let peers = listen_peers.clone();
                        let timeout_duration = listen_timeout;
                        let start_height = listen_start_height;
                        let user_agent = listen_user_agent.clone();

                        tokio::spawn(async move {
                            match timeout(
                                timeout_duration,
                                Peer::accept(
                                    stream,
                                    our_addr,
                                    user_agent,
                                    db.clone(),
                                    event_tx,
                                    start_height,
                                ),
                            )
                            .await
                            {
                                Ok(Ok(peer)) => {
                                    let handle = peer.handle();
                                    let mut peers_lock = peers.write().await;
                                    if peers_lock
                                        .iter()
                                        .any(|existing| existing.addr() == handle.addr())
                                    {
                                        info!("Skipping duplicate inbound peer {}", handle.addr());
                                        return;
                                    }
                                    peers_lock.push(handle);
                                    drop(peers_lock);

                                    tokio::spawn(peer.run());

                                    let m = metrics.write().await;
                                    m.total_connections.inc();
                                }
                                Ok(Err(e)) => {
                                    warn!("Failed inbound peer handshake: {}", e);
                                }
                                Err(_) => {
                                    warn!("Inbound peer handshake timed out");
                                }
                            }
                        });
                    }
                    Err(e) => warn!("Inbound accept error: {}", e),
                }
            }
        });

        // Spawn outbound connection task
        let connect_db = self.db.clone();
        let connect_metrics = self.metrics.clone();
        let connect_peers = self.peers.clone();
        let connect_pending = self.pending_outbound.clone();
        let connect_our_addr = self.our_addr;
        let connect_timeout = self.peer_timeout;
        let connect_start_height = self.start_height;
        let connect_user_agent = self.user_agent.clone();
        let target = self.target_peers;

        tokio::spawn(async move {
            let mut interval = tokio::time::interval(OUTBOUND_REFILL_INTERVAL);

            loop {
                interval.tick().await;

                let current_count = {
                    let peers = connect_peers.read().await;
                    peers.len()
                };

                if current_count < target {
                    let to_connect = target - current_count;
                    // Mild over-dialing helps offset handshake failures and churn.
                    let desired_attempts = to_connect + (to_connect / 2);
                    let attempt_budget = desired_attempts.min(MAX_CONNECT_ATTEMPTS_PER_TICK);
                    let connected_addrs: HashSet<SocketAddr> = {
                        let peers = connect_peers.read().await;
                        peers.iter().map(PeerHandle::addr).collect()
                    };
                    let pending_addrs = { connect_pending.read().await.clone() };

                    let addrs = connect_db
                        .get_knots_excluding(attempt_budget * 4)
                        .unwrap_or_default();
                    let mut attempted = 0usize;

                    for addr in addrs {
                        if addr.ip().is_ipv6() {
                            continue;
                        }
                        if connected_addrs.contains(&addr) {
                            continue;
                        }
                        if pending_addrs.contains(&addr) {
                            continue;
                        }
                        if attempted >= attempt_budget {
                            break;
                        }
                        attempted += 1;

                        {
                            let mut pending = connect_pending.write().await;
                            pending.insert(addr);
                        }

                        let event_tx = event_tx.clone();
                        let db = connect_db.clone();
                        let our_addr = connect_our_addr;
                        let metrics = connect_metrics.clone();
                        let peers = connect_peers.clone();
                        let pending = connect_pending.clone();
                        let timeout_duration = connect_timeout;
                        let start_height = connect_start_height;
                        let user_agent = connect_user_agent.clone();

                        tokio::spawn(async move {
                            match timeout(
                                timeout_duration,
                                Peer::connect(
                                    addr,
                                    our_addr,
                                    user_agent,
                                    db.clone(),
                                    event_tx,
                                    start_height,
                                ),
                            )
                            .await
                            {
                                Ok(Ok(peer)) => {
                                    let handle = peer.handle();
                                    let mut peers_lock = peers.write().await;
                                    if peers_lock
                                        .iter()
                                        .any(|existing| existing.addr() == handle.addr())
                                    {
                                        info!("Skipping duplicate outbound peer {}", handle.addr());
                                    } else {
                                        peers_lock.push(handle);
                                        drop(peers_lock);

                                        tokio::spawn(peer.run());

                                        let m = metrics.write().await;
                                        m.total_connections.inc();
                                    }
                                }
                                Ok(Err(e)) => {
                                    warn!("Failed to connect to {}: {}", addr, e);
                                    let _ = db.mark_failed(addr);
                                }
                                Err(_) => {
                                    warn!("Connection to {} timed out", addr);
                                    let _ = db.mark_failed(addr);
                                }
                            }
                            let mut pending_lock = pending.write().await;
                            pending_lock.remove(&addr);
                        });
                    }
                }
            }
        });

        // Handle events
        while let Some(event) = event_rx.recv().await {
            match event {
                PeerEvent::Connected { addr, version } => {
                    info!("Peer {} connected (agent: {})", addr, version.user_agent);
                    self.update_peer_counts().await;
                }
                PeerEvent::Disconnected { addr, reason } => {
                    info!("Peer {} disconnected: {}", addr, reason);

                    {
                        let mut peers = self.peers.write().await;
                        peers.retain(|p| p.addr() != addr);
                    }

                    {
                        let metrics = self.metrics.write().await;
                        metrics.total_disconnections.inc();
                    }

                    let _ = self.db.mark_failed(addr);
                    self.update_peer_counts().await;
                }
                PeerEvent::Message { addr, message } => {
                    self.handle_message(addr, message).await;
                }
                PeerEvent::Addresses { addr, addrs } => {
                    info!("Received {} addresses from peer {}", addrs.len(), addr);
                    {
                        let metrics = self.metrics.write().await;
                        metrics.addr_messages_received.inc();
                    }

                    if let Some(discovery) = &self.discovery {
                        discovery.handle_new_addresses(addrs).await;
                    }
                }
            }
        }
    }

    async fn handle_message(&self, from_addr: SocketAddr, msg: Message) {
        match msg {
            Message::Inv(inv_list) => {
                {
                    let metrics = self.metrics.write().await;
                    metrics.inv_messages_received.inc_by(inv_list.len() as u64);
                }

                // Request tx data for unseen tx announcements.
                let mut getdata_items = Vec::new();
                {
                    let mut relay_state = self.relay_state.write().await;
                    let now = Instant::now();

                    for inv in inv_list {
                        let Some(key) = inventory_key(&inv) else {
                            continue;
                        };
                        if relay_state.mark_requested(key, now) {
                            getdata_items.push(inv);
                        }
                    }
                }

                if !getdata_items.is_empty() {
                    self.send_to_peer(from_addr, Message::GetData(getdata_items))
                        .await;
                }
            }
            Message::Tx(tx) => {
                let txid = tx.compute_txid();
                let txid_key = txid.to_byte_array();
                let wtxid_key = tx.compute_wtxid().to_byte_array();
                let source_node_type = self.peer_node_type(from_addr).await;
                let is_new = {
                    let mut relay_state = self.relay_state.write().await;
                    relay_state.complete_request(txid_key);
                    relay_state.complete_request(wtxid_key);
                    let is_new = relay_state.mark_seen(txid_key);
                    let _ = relay_state.mark_seen(wtxid_key);
                    if is_new {
                        relay_state.insert_tx(txid, tx.clone());
                    }
                    is_new
                };
                if !is_new {
                    return;
                }

                {
                    let metrics = self.metrics.write().await;
                    metrics.transactions_received.inc();
                    metrics.inc_transactions_received_from(source_node_type);
                }

                // Announce to non-Knots peers; they request via getdata.
                self.relay_inv(from_addr, vec![Inventory::Transaction(txid)])
                    .await;
            }
            Message::GetData(requests) => {
                let to_send = {
                    let relay_state = self.relay_state.read().await;
                    requests
                        .iter()
                        .filter_map(|inv| match inv {
                            Inventory::Transaction(txid) => relay_state.get_tx(txid),
                            Inventory::WitnessTransaction(txid) => relay_state.get_tx(txid),
                            Inventory::WTx(wtxid) => relay_state.get_tx_by_wtxid(wtxid),
                            _ => None,
                        })
                        .collect::<Vec<_>>()
                };

                let mut sent = 0u64;
                for tx in to_send {
                    if self.send_to_peer(from_addr, Message::Tx(tx)).await {
                        sent += 1;
                    }
                }

                if sent > 0 {
                    let metrics = self.metrics.write().await;
                    metrics.transactions_relayed.inc_by(sent);
                }
            }
            Message::GetAddr => {
                {
                    let metrics = self.metrics.write().await;
                    metrics.getaddr_messages_received.inc();
                }

                let response_addrs = {
                    let peers = self.peers.read().await;
                    let mut candidates: Vec<_> = peers
                        .iter()
                        .filter(|peer| peer.addr() != from_addr)
                        .map(PeerHandle::addr)
                        .collect();

                    let mut rng = rand::thread_rng();
                    candidates.shuffle(&mut rng);
                    candidates.truncate(GETADDR_RESPONSE_LIMIT);

                    let timestamp = Utc::now().timestamp().max(0) as u32;
                    candidates
                        .into_iter()
                        .map(|addr| AddressEntry {
                            services: ServiceFlags::NONE,
                            addr,
                            timestamp,
                        })
                        .collect::<Vec<_>>()
                };

                if !response_addrs.is_empty() {
                    let _ = self.send_to_peer(from_addr, Message::Addr(response_addrs)).await;
                }
            }
            _ => {}
        }
    }

    async fn relay_inv(&self, from_addr: SocketAddr, inv_list: Vec<Inventory>) {
        let msg = Message::Inv(inv_list);
        let peers = { self.peers.read().await.clone() };
        let mut stale = Vec::new();

        for peer in peers {
            // Don't relay back to sender
            if peer.addr() == from_addr {
                continue;
            }

            // Don't relay to Knots
            if peer.node_type() == NodeType::Knots {
                continue;
            }

            if !self.send_to_peer_handle(&peer, msg.clone()) {
                stale.push(peer.addr());
            }
        }

        if !stale.is_empty() {
            self.prune_stale_peers(stale).await;
        }
    }

    async fn send_to_peer(&self, addr: SocketAddr, msg: Message) -> bool {
        let peer = {
            let peers = self.peers.read().await;
            peers.iter().find(|p| p.addr() == addr).cloned()
        };

        if let Some(peer) = peer {
            let sent = self.send_to_peer_handle(&peer, msg);
            if !sent {
                self.prune_stale_peers(vec![addr]).await;
            }
            return sent;
        }
        false
    }

    async fn peer_node_type(&self, addr: SocketAddr) -> NodeType {
        let peers = self.peers.read().await;
        peers
            .iter()
            .find(|peer| peer.addr() == addr)
            .map(PeerHandle::node_type)
            .unwrap_or(NodeType::Unknown)
    }

    fn send_to_peer_handle(&self, peer: &PeerHandle, msg: Message) -> bool {
        if let Err(e) = peer.send(msg) {
            warn!("Failed to send message to {}: {}", peer.addr(), e);
            return false;
        }
        true
    }

    async fn prune_stale_peers(&self, stale: Vec<SocketAddr>) {
        if stale.is_empty() {
            return;
        }

        let stale_set: HashSet<SocketAddr> = stale.into_iter().collect();
        let removed_any = {
            let mut peers = self.peers.write().await;
            let before = peers.len();
            peers.retain(|peer| !stale_set.contains(&peer.addr()));
            peers.len() != before
        };

        if removed_any {
            self.update_peer_counts().await;
        }
    }

    async fn update_peer_counts(&self) {
        let peers = self.peers.read().await;

        let mut knots = 0i64;
        let mut core = 0i64;
        let mut libre = 0i64;
        let mut other = 0i64;
        let mut unclassified_agents: HashMap<String, i64> = HashMap::new();

        for peer in peers.iter() {
            match peer.node_type() {
                NodeType::Knots => knots += 1,
                NodeType::Core => core += 1,
                NodeType::LibreRelay => libre += 1,
                _ => {
                    other += 1;
                    let agent = match peer.user_agent().trim() {
                        "" => "<missing-user-agent>",
                        value => value,
                    };
                    *unclassified_agents.entry(agent.to_string()).or_insert(0) += 1;
                }
            }
        }

        let metrics = self.metrics.read().await;
        metrics.update_peer_counts(knots, core, libre, other);
        metrics.update_unclassified_agent_peers(&unclassified_agents);
    }
}

fn inventory_key(inv: &Inventory) -> Option<[u8; 32]> {
    match inv {
        Inventory::Transaction(txid) => Some(txid.to_byte_array()),
        Inventory::WTx(wtxid) => Some(wtxid.to_byte_array()),
        Inventory::WitnessTransaction(wtxid) => Some(wtxid.to_byte_array()),
        _ => None,
    }
}
