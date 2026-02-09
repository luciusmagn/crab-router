use crate::db::NodeType;
use axum::{Router, routing::get};
use prometheus::{
    Encoder, IntCounter, IntGauge, IntGaugeVec, TextEncoder, register_int_counter,
    register_int_gauge, register_int_gauge_vec,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::error;

#[derive(Clone)]
pub struct Metrics {
    pub connected_peers: IntGauge,
    pub total_connections: IntCounter,
    pub total_disconnections: IntCounter,
    pub transactions_relayed: IntCounter,
    pub transactions_received: IntCounter,
    pub transactions_received_from_knots: IntCounter,
    pub transactions_received_from_core: IntCounter,
    pub transactions_received_from_libre: IntCounter,
    pub transactions_received_from_other: IntCounter,
    pub transactions_received_from_unknown: IntCounter,
    pub unclassified_agent_peers: IntGaugeVec,
    pub inv_messages_received: IntCounter,
    pub addr_messages_received: IntCounter,
    pub knots_peers: IntGauge,
    pub core_peers: IntGauge,
    pub libre_peers: IntGauge,
    pub other_peers: IntGauge,
    pub discovery_runs: IntCounter,
    pub nodes_discovered: IntCounter,
    pub nodes_pruned: IntCounter,
}

impl Metrics {
    pub fn new() -> Self {
        Self {
            connected_peers: register_int_gauge!(
                "crab_router_connected_peers",
                "Number of currently connected peers"
            )
            .unwrap(),
            total_connections: register_int_counter!(
                "crab_router_total_connections",
                "Total number of peer connections made"
            )
            .unwrap(),
            total_disconnections: register_int_counter!(
                "crab_router_total_disconnections",
                "Total number of peer disconnections"
            )
            .unwrap(),
            transactions_relayed: register_int_counter!(
                "crab_router_transactions_relayed",
                "Total number of transactions relayed to peers"
            )
            .unwrap(),
            transactions_received: register_int_counter!(
                "crab_router_transactions_received",
                "Total number of transactions received from peers"
            )
            .unwrap(),
            transactions_received_from_knots: register_int_counter!(
                "crab_router_transactions_received_from_knots",
                "Total number of transactions received from Knots peers"
            )
            .unwrap(),
            transactions_received_from_core: register_int_counter!(
                "crab_router_transactions_received_from_core",
                "Total number of transactions received from Core peers"
            )
            .unwrap(),
            transactions_received_from_libre: register_int_counter!(
                "crab_router_transactions_received_from_libre",
                "Total number of transactions received from Libre Relay peers"
            )
            .unwrap(),
            transactions_received_from_other: register_int_counter!(
                "crab_router_transactions_received_from_other",
                "Total number of transactions received from other peers"
            )
            .unwrap(),
            transactions_received_from_unknown: register_int_counter!(
                "crab_router_transactions_received_from_unknown",
                "Total number of transactions received from unknown peers"
            )
            .unwrap(),
            unclassified_agent_peers: register_int_gauge_vec!(
                "crab_router_unclassified_agent_peers",
                "Number of currently connected peers by unclassified user agent",
                &["user_agent"]
            )
            .unwrap(),
            inv_messages_received: register_int_counter!(
                "crab_router_inv_messages_received",
                "Total number of inv messages received"
            )
            .unwrap(),
            addr_messages_received: register_int_counter!(
                "crab_router_addr_messages_received",
                "Total number of addr messages received"
            )
            .unwrap(),
            knots_peers: register_int_gauge!(
                "crab_router_knots_peers",
                "Number of Knots peers currently connected"
            )
            .unwrap(),
            core_peers: register_int_gauge!(
                "crab_router_core_peers",
                "Number of Core peers currently connected"
            )
            .unwrap(),
            libre_peers: register_int_gauge!(
                "crab_router_libre_peers",
                "Number of Libre Relay peers currently connected"
            )
            .unwrap(),
            other_peers: register_int_gauge!(
                "crab_router_other_peers",
                "Number of other peers currently connected"
            )
            .unwrap(),
            discovery_runs: register_int_counter!(
                "crab_router_discovery_runs",
                "Number of discovery cycles run"
            )
            .unwrap(),
            nodes_discovered: register_int_counter!(
                "crab_router_nodes_discovered",
                "Total number of new nodes discovered"
            )
            .unwrap(),
            nodes_pruned: register_int_counter!(
                "crab_router_nodes_pruned",
                "Total number of nodes pruned from database"
            )
            .unwrap(),
        }
    }

    pub fn update_peer_counts(&self, knots: i64, core: i64, libre: i64, other: i64) {
        self.knots_peers.set(knots);
        self.core_peers.set(core);
        self.libre_peers.set(libre);
        self.other_peers.set(other);
        self.connected_peers.set(knots + core + libre + other);
    }

    pub fn inc_transactions_received_from(&self, node_type: NodeType) {
        match node_type {
            NodeType::Knots => self.transactions_received_from_knots.inc(),
            NodeType::Core => self.transactions_received_from_core.inc(),
            NodeType::LibreRelay => self.transactions_received_from_libre.inc(),
            NodeType::Other => self.transactions_received_from_other.inc(),
            NodeType::Unknown => self.transactions_received_from_unknown.inc(),
        }
    }

    pub fn update_unclassified_agent_peers(&self, counts: &HashMap<String, i64>) {
        self.unclassified_agent_peers.reset();
        for (agent, count) in counts {
            self.unclassified_agent_peers
                .with_label_values(&[agent.as_str()])
                .set(*count);
        }
    }
}

pub async fn serve_metrics(addr: SocketAddr, _metrics: Arc<RwLock<Metrics>>) {
    let app = Router::new().route("/metrics", get(metrics_handler));

    match tokio::net::TcpListener::bind(addr).await {
        Ok(listener) => {
            if let Err(e) = axum::serve(listener, app).await {
                error!("Metrics server failed on {}: {}", addr, e);
            }
        }
        Err(e) => {
            error!("Failed to bind metrics server on {}: {}", addr, e);
        }
    }
}

async fn metrics_handler() -> String {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = Vec::new();
    if let Err(e) = encoder.encode(&metric_families, &mut buffer) {
        return format!("# metrics encoding error: {}", e);
    }
    String::from_utf8_lossy(&buffer).to_string()
}
