mod config;
mod db;
mod discovery;
mod manager;
mod metrics;
mod p2p;

use anyhow::Result;
use clap::Parser;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::INFO.into()),
        )
        .with_target(true)
        .with_thread_ids(false)
        .with_file(false)
        .with_line_number(false)
        .init();

    let config = config::Config::parse();

    info!("Starting Crab Router v1.0.0");
    info!("Target peers: {}", config.target_peers);
    info!("Metrics endpoint: http://{}/metrics", config.metrics_addr);

    // Initialize database
    let db = Arc::new(db::AddressDb::new(None)?);

    // Initialize metrics
    let metrics = Arc::new(RwLock::new(metrics::Metrics::new()));

    // Start metrics server
    let metrics_clone = metrics.clone();
    tokio::spawn(async move {
        metrics::serve_metrics(config.metrics_addr, metrics_clone).await;
    });

    // Address advertised in version handshake and used for inbound bind port.
    let our_addr: SocketAddr = format!("0.0.0.0:{}", config.listen_port).parse()?;

    // Start peer manager
    let mut manager = manager::PeerManager::new(
        db.clone(),
        metrics.clone(),
        config.target_peers,
        our_addr,
        config.user_agent.clone(),
        config.peer_timeout_secs,
    );

    let peers = manager.peers();

    if config.enable_discovery {
        // Start discovery service
        let discovery = Arc::new(discovery::DiscoveryService::new(
            db.clone(),
            metrics.clone(),
            peers.clone(),
        ));
        manager.set_discovery_service(discovery.clone());

        tokio::spawn(async move {
            discovery.run(config.discovery_interval_secs).await;
        });
    } else {
        info!("Discovery disabled by configuration");
    }

    // Run peer manager
    manager.run().await;

    Ok(())
}
