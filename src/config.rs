use clap::Parser;
use std::net::SocketAddr;

#[derive(Parser, Clone, Debug)]
#[command(name = "crab-router")]
#[command(about = "Aggressive Bitcoin P2P relay node for topology exploration")]
pub struct Config {
    #[arg(long, default_value = "0.0.0.0:15444")]
    pub metrics_addr: SocketAddr,

    #[arg(long, default_value = "1000")]
    pub target_peers: usize,

    #[arg(long, default_value = "8333")]
    pub listen_port: u16,

    #[arg(long, default_value_t = true, action = clap::ArgAction::Set)]
    pub enable_discovery: bool,

    #[arg(long, default_value = "300")]
    pub discovery_interval_secs: u64,

    #[arg(long, default_value = "60")]
    pub peer_timeout_secs: u64,

    #[arg(long, default_value = "/Crab Router:1.0.0/")]
    pub user_agent: String,
}
