use bitcoin::consensus::{Decodable, Encodable};
use bitcoin::p2p::address::{AddrV2, AddrV2Message};
use bitcoin::p2p::message::RawNetworkMessage;
pub use bitcoin::p2p::message_blockdata::Inventory;
use bitcoin::p2p::message_network::VersionMessage;
use bitcoin::p2p::{Magic, ServiceFlags};
use std::net::{IpAddr, SocketAddr};

pub const MAGIC: Magic = Magic::BITCOIN;
// Explicitly advertise a modern protocol version so peers send newer capability
// messages (e.g., feefilter, wtxidrelay, sendaddrv2/addrv2) during handshake.
pub const ADVERTISED_PROTOCOL_VERSION: u32 = 70016;

#[derive(Debug, Clone)]
pub struct PeerVersion {
    pub version: u32,
    pub services: ServiceFlags,
    pub timestamp: i64,
    pub user_agent: String,
    pub start_height: i32,
    pub relay: bool,
}

impl PeerVersion {
    pub fn from_version_message(msg: &VersionMessage) -> Self {
        Self {
            version: msg.version,
            services: msg.services,
            timestamp: msg.timestamp,
            user_agent: msg.user_agent.clone(),
            start_height: msg.start_height,
            relay: msg.relay,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Message {
    Version(VersionMessage),
    Verack,
    SendAddrV2,
    WtxidRelay,
    Ping(u64),
    Pong(u64),
    FeeFilter(i64),
    Inv(Vec<Inventory>),
    GetData(Vec<Inventory>),
    Tx(bitcoin::Transaction),
    GetAddr,
    Addr(Vec<AddressEntry>),
    AddrV2(Vec<AddressEntry>),
    Unknown { command: String },
}

#[derive(Debug, Clone)]
pub struct AddressEntry {
    pub services: ServiceFlags,
    pub addr: SocketAddr,
    pub timestamp: u32,
}

pub fn build_version_message(
    our_addr: SocketAddr,
    their_addr: SocketAddr,
    start_height: i32,
    user_agent: &str,
) -> VersionMessage {
    VersionMessage {
        version: ADVERTISED_PROTOCOL_VERSION,
        services: ServiceFlags::NETWORK_LIMITED,
        timestamp: chrono::Utc::now().timestamp(),
        receiver: bitcoin::p2p::address::Address::new(&their_addr, ServiceFlags::NONE),
        sender: bitcoin::p2p::address::Address::new(&our_addr, ServiceFlags::NETWORK_LIMITED),
        nonce: rand::random(),
        user_agent: user_agent.into(),
        start_height,
        relay: true,
    }
}

pub fn parse_message(data: &[u8]) -> anyhow::Result<Message> {
    use std::io::Cursor;

    if data.len() < 24 {
        anyhow::bail!("message too short");
    }

    let mut cursor = Cursor::new(data);
    let raw_msg: RawNetworkMessage = Decodable::consensus_decode(&mut cursor)?;
    if raw_msg.magic() != &MAGIC {
        anyhow::bail!("unexpected network magic: {:?}", raw_msg.magic());
    }

    let msg = match raw_msg.payload() {
        bitcoin::p2p::message::NetworkMessage::Version(v) => Message::Version(v.clone()),
        bitcoin::p2p::message::NetworkMessage::Verack => Message::Verack,
        bitcoin::p2p::message::NetworkMessage::SendAddrV2 => Message::SendAddrV2,
        bitcoin::p2p::message::NetworkMessage::WtxidRelay => Message::WtxidRelay,
        bitcoin::p2p::message::NetworkMessage::Ping(nonce) => Message::Ping(*nonce),
        bitcoin::p2p::message::NetworkMessage::Pong(nonce) => Message::Pong(*nonce),
        bitcoin::p2p::message::NetworkMessage::FeeFilter(feerate) => Message::FeeFilter(*feerate),
        bitcoin::p2p::message::NetworkMessage::Inv(inv) => Message::Inv(inv.clone()),
        bitcoin::p2p::message::NetworkMessage::GetData(data) => Message::GetData(data.clone()),
        bitcoin::p2p::message::NetworkMessage::Tx(tx) => Message::Tx(tx.clone()),
        bitcoin::p2p::message::NetworkMessage::GetAddr => Message::GetAddr,
        bitcoin::p2p::message::NetworkMessage::Addr(addrs) => {
            let entries = addrs
                .iter()
                .filter_map(|a| {
                    a.1.socket_addr().ok().map(|addr| AddressEntry {
                        services: a.1.services,
                        addr,
                        timestamp: a.0,
                    })
                })
                .collect();
            Message::Addr(entries)
        }
        bitcoin::p2p::message::NetworkMessage::AddrV2(addrs) => {
            let entries = addrs
                .iter()
                .filter_map(|a| {
                    a.socket_addr().ok().map(|addr| AddressEntry {
                        services: a.services,
                        addr,
                        timestamp: a.time,
                    })
                })
                .collect();
            Message::AddrV2(entries)
        }
        other => Message::Unknown {
            command: format!("{:?}", other),
        },
    };

    Ok(msg)
}

pub fn serialize_message(msg: &Message, magic: Magic) -> anyhow::Result<Vec<u8>> {
    let network_msg = match msg {
        Message::Version(v) => bitcoin::p2p::message::NetworkMessage::Version(v.clone()),
        Message::Verack => bitcoin::p2p::message::NetworkMessage::Verack,
        Message::SendAddrV2 => bitcoin::p2p::message::NetworkMessage::SendAddrV2,
        Message::WtxidRelay => bitcoin::p2p::message::NetworkMessage::WtxidRelay,
        Message::Ping(nonce) => bitcoin::p2p::message::NetworkMessage::Ping(*nonce),
        Message::Pong(nonce) => bitcoin::p2p::message::NetworkMessage::Pong(*nonce),
        Message::FeeFilter(feerate) => bitcoin::p2p::message::NetworkMessage::FeeFilter(*feerate),
        Message::Inv(inv) => bitcoin::p2p::message::NetworkMessage::Inv(inv.clone()),
        Message::GetData(data) => bitcoin::p2p::message::NetworkMessage::GetData(data.clone()),
        Message::Tx(tx) => bitcoin::p2p::message::NetworkMessage::Tx(tx.clone()),
        Message::GetAddr => bitcoin::p2p::message::NetworkMessage::GetAddr,
        Message::Addr(addrs) => {
            let addresses: Vec<(u32, bitcoin::p2p::address::Address)> = addrs
                .iter()
                .map(|a| {
                    (
                        a.timestamp,
                        bitcoin::p2p::address::Address::new(&a.addr, a.services),
                    )
                })
                .collect();
            bitcoin::p2p::message::NetworkMessage::Addr(addresses)
        }
        Message::AddrV2(addrs) => {
            let addresses: Vec<AddrV2Message> = addrs
                .iter()
                .map(|a| {
                    let addr = match a.addr.ip() {
                        IpAddr::V4(ip) => AddrV2::Ipv4(ip),
                        IpAddr::V6(ip) => AddrV2::Ipv6(ip),
                    };
                    AddrV2Message {
                        time: a.timestamp,
                        services: a.services,
                        addr,
                        port: a.addr.port(),
                    }
                })
                .collect();
            bitcoin::p2p::message::NetworkMessage::AddrV2(addresses)
        }
        Message::Unknown { command } => {
            anyhow::bail!("cannot serialize unknown command: {}", command)
        }
    };

    let raw = RawNetworkMessage::new(magic, network_msg);
    let mut bytes = Vec::new();
    raw.consensus_encode(&mut bytes)?;
    Ok(bytes)
}
