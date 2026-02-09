use crate::db::AddressDb;
use crate::metrics::Metrics;
use crate::p2p::PeerHandle;
use crate::p2p::message::{AddressEntry, Message};
use rand::seq::SliceRandom;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tokio::time::interval;
use tracing::{debug, info};

// DNS seeds for mainnet
const DNS_SEEDS: [&str; 3] = [
    "seed.bitcoin.sipa.be",
    "dnsseed.bluematt.me",
    "seed.bitcoinstats.com",
];

pub struct DiscoveryService {
    db: Arc<AddressDb>,
    metrics: Arc<RwLock<Metrics>>,
    peers: Arc<RwLock<Vec<PeerHandle>>>,
}

impl DiscoveryService {
    pub fn new(
        db: Arc<AddressDb>,
        metrics: Arc<RwLock<Metrics>>,
        peers: Arc<RwLock<Vec<PeerHandle>>>,
    ) -> Self {
        Self { db, metrics, peers }
    }

    pub async fn run(&self, interval_secs: u64) {
        let mut ticker = interval(Duration::from_secs(interval_secs));

        // Initial seed from DNS
        self.seed_from_dns().await;

        loop {
            ticker.tick().await;
            self.run_discovery_cycle().await;
        }
    }

    async fn seed_from_dns(&self) {
        info!("Seeding addresses from DNS seeds...");
        let mut total_new = 0u64;

        for seed in &DNS_SEEDS {
            match tokio::net::lookup_host(format!("{}:8333", seed)).await {
                Ok(addrs) => {
                    let resolved: Vec<SocketAddr> = addrs.collect();
                    let new_nodes = self.store_socket_addrs(resolved.clone(), None).await;
                    total_new += new_nodes;
                    info!(
                        "Found {} addresses from {} ({} new)",
                        resolved.len(),
                        seed,
                        new_nodes
                    );
                }
                Err(e) => {
                    debug!("Failed to resolve {}: {}", seed, e);
                }
            }
        }

        if total_new > 0 {
            let metrics = self.metrics.write().await;
            metrics.nodes_discovered.inc_by(total_new);
        }
    }

    async fn run_discovery_cycle(&self) {
        debug!("Running discovery cycle");

        {
            let metrics = self.metrics.write().await;
            metrics.discovery_runs.inc();
        }

        // Request addresses from random peers
        let handles: Vec<PeerHandle> = {
            let peers = self.peers.read().await;
            let mut peers = peers.clone();
            peers.shuffle(&mut rand::thread_rng());
            peers.into_iter().take(10).collect()
        };

        for peer in handles {
            let _ = peer.send(Message::GetAddr);
        }

        // Prune old unreachable nodes
        let cutoff = chrono::Utc::now() - chrono::Duration::days(7);
        match self.db.prune_old(cutoff) {
            Ok(pruned) => {
                if pruned > 0 {
                    info!("Pruned {} old unreachable nodes", pruned);
                    let metrics = self.metrics.write().await;
                    metrics.nodes_pruned.inc_by(pruned as u64);
                }
            }
            Err(e) => {
                debug!("Failed to prune old nodes: {}", e);
            }
        }
    }

    pub async fn handle_new_addresses(&self, addrs: Vec<AddressEntry>) {
        let mut new_count = 0u64;

        for entry in addrs {
            // Skip non-public addresses
            if !is_public_addr(entry.addr) {
                continue;
            }

            // Try to add to database
            let info = crate::db::NodeInfo {
                addr: entry.addr,
                node_type: crate::db::NodeType::Unknown,
                user_agent: None,
                version: None,
                services: Some(entry.services.to_u64()),
                last_seen: chrono::Utc::now(),
                last_connected: None,
                connection_failures: 0,
                is_reachable: true,
            };

            match self.db.insert_or_update(&info) {
                Ok(is_new) => {
                    if is_new {
                        new_count += 1;
                    }
                }
                Err(e) => {
                    debug!("Failed to store discovered address {}: {}", info.addr, e);
                }
            }
        }

        if new_count > 0 {
            let metrics = self.metrics.write().await;
            metrics.nodes_discovered.inc_by(new_count);
        }
    }

    async fn store_socket_addrs(&self, addrs: Vec<SocketAddr>, services: Option<u64>) -> u64 {
        let mut new_count = 0u64;

        for addr in addrs {
            if !is_public_addr(addr) {
                continue;
            }

            let info = crate::db::NodeInfo {
                addr,
                node_type: crate::db::NodeType::Unknown,
                user_agent: None,
                version: None,
                services,
                last_seen: chrono::Utc::now(),
                last_connected: None,
                connection_failures: 0,
                is_reachable: true,
            };

            match self.db.insert_or_update(&info) {
                Ok(is_new) => {
                    if is_new {
                        new_count += 1;
                    }
                }
                Err(e) => {
                    debug!("Failed to store DNS seed address {}: {}", info.addr, e);
                }
            }
        }

        new_count
    }
}

fn is_public_addr(addr: SocketAddr) -> bool {
    match addr.ip() {
        std::net::IpAddr::V4(ip) => {
            !ip.is_private()
                && !ip.is_loopback()
                && !ip.is_link_local()
                && !ip.is_multicast()
                && !ip.is_broadcast()
                && !ip.is_documentation()
        }
        std::net::IpAddr::V6(ip) => !ip.is_loopback() && !ip.is_multicast() && !ip.is_unspecified(),
    }
}
