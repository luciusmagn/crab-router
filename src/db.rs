use anyhow::Result;
use chrono::{DateTime, Utc};
use rusqlite::{Connection, OptionalExtension, params};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NodeType {
    Unknown,
    Knots,
    Core,
    LibreRelay,
    Other,
}

impl NodeType {
    pub fn from_user_agent(agent: &str) -> Self {
        let lower = agent.to_lowercase();
        if lower.contains("knots") {
            NodeType::Knots
        } else if lower.contains("libre") {
            NodeType::LibreRelay
        } else if lower.contains("satoshi") || lower.contains("core") {
            NodeType::Core
        } else {
            NodeType::Other
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            NodeType::Unknown => "unknown",
            NodeType::Knots => "knots",
            NodeType::Core => "core",
            NodeType::LibreRelay => "libre",
            NodeType::Other => "other",
        }
    }
}

#[derive(Debug, Clone)]
pub struct NodeInfo {
    pub addr: SocketAddr,
    pub node_type: NodeType,
    pub user_agent: Option<String>,
    pub version: Option<i32>,
    pub services: Option<u64>,
    pub last_seen: DateTime<Utc>,
    pub last_connected: Option<DateTime<Utc>>,
    pub connection_failures: u32,
    pub is_reachable: bool,
}

pub struct AddressDb {
    conn: Mutex<Connection>,
}

impl AddressDb {
    pub fn new(path: Option<PathBuf>) -> Result<Self> {
        let path = path.unwrap_or_else(|| {
            dirs::data_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("crab-router")
                .join("peers.db")
        });

        std::fs::create_dir_all(path.parent().unwrap())?;

        let conn = Connection::open(&path)?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS nodes (
                addr TEXT PRIMARY KEY,
                node_type TEXT NOT NULL,
                user_agent TEXT,
                version INTEGER,
                services INTEGER,
                last_seen TEXT NOT NULL,
                last_connected TEXT,
                connection_failures INTEGER NOT NULL DEFAULT 0,
                is_reachable INTEGER NOT NULL DEFAULT 1
            )",
            [],
        )?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_node_type ON nodes(node_type)",
            [],
        )?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_reachable ON nodes(is_reachable)",
            [],
        )?;

        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn insert_or_update(&self, info: &NodeInfo) -> Result<bool> {
        let conn = self.conn.lock().unwrap();
        let addr = info.addr.to_string();
        let exists = conn
            .query_row(
                "SELECT 1 FROM nodes WHERE addr = ?1",
                params![addr],
                |row| row.get::<_, i64>(0),
            )
            .optional()?
            .is_some();
        conn.execute(
            "INSERT INTO nodes (addr, node_type, user_agent, version, services, last_seen, last_connected, connection_failures, is_reachable)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
             ON CONFLICT(addr) DO UPDATE SET
                node_type = excluded.node_type,
                user_agent = excluded.user_agent,
                version = excluded.version,
                services = excluded.services,
                last_seen = excluded.last_seen,
                last_connected = excluded.last_connected,
                connection_failures = excluded.connection_failures,
                is_reachable = excluded.is_reachable",
            params![
                info.addr.to_string(),
                info.node_type.as_str(),
                info.user_agent,
                info.version,
                info.services.map(|s| s as i64),
                info.last_seen.to_rfc3339(),
                info.last_connected.map(|t| t.to_rfc3339()),
                info.connection_failures,
                info.is_reachable as i32,
            ],
        )?;
        Ok(!exists)
    }

    pub fn get_by_type(&self, node_type: NodeType, limit: usize) -> Result<Vec<SocketAddr>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT addr FROM nodes WHERE node_type = ?1 AND is_reachable = 1 ORDER BY last_seen DESC LIMIT ?2"
        )?;

        let addrs: Vec<SocketAddr> = stmt
            .query_map(params![node_type.as_str(), limit as i64], |row| {
                let addr_str: String = row.get(0)?;
                Ok(addr_str.parse::<SocketAddr>().unwrap())
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(addrs)
    }

    pub fn get_random(&self, limit: usize) -> Result<Vec<SocketAddr>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare("SELECT addr FROM nodes WHERE is_reachable = 1 ORDER BY RANDOM() LIMIT ?1")?;

        let addrs: Vec<SocketAddr> = stmt
            .query_map(params![limit as i64], |row| {
                let addr_str: String = row.get(0)?;
                Ok(addr_str.parse::<SocketAddr>().unwrap())
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(addrs)
    }

    pub fn get_knots_excluding(&self, limit: usize) -> Result<Vec<SocketAddr>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT addr
             FROM nodes
             WHERE node_type != 'knots' AND is_reachable = 1
             ORDER BY
                 CASE node_type
                     WHEN 'libre' THEN 0
                     WHEN 'core' THEN 1
                     WHEN 'other' THEN 2
                     WHEN 'unknown' THEN 3
                     ELSE 4
                 END,
                 last_seen DESC
             LIMIT ?1",
        )?;

        let addrs: Vec<SocketAddr> = stmt
            .query_map(params![limit as i64], |row| {
                let addr_str: String = row.get(0)?;
                Ok(addr_str.parse::<SocketAddr>().unwrap())
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(addrs)
    }

    pub fn mark_failed(&self, addr: SocketAddr) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE nodes SET connection_failures = connection_failures + 1,
             is_reachable = CASE WHEN connection_failures + 1 >= 5 THEN 0 ELSE is_reachable END
             WHERE addr = ?1",
            params![addr.to_string()],
        )?;
        Ok(())
    }

    pub fn mark_connected(&self, addr: SocketAddr) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE nodes SET last_connected = ?1, connection_failures = 0, is_reachable = 1 WHERE addr = ?2",
            params![Utc::now().to_rfc3339(), addr.to_string()],
        )?;
        Ok(())
    }

    pub fn count_by_type(&self) -> Result<Vec<(NodeType, i64)>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT node_type, COUNT(*) FROM nodes WHERE is_reachable = 1 GROUP BY node_type",
        )?;

        let counts: Vec<(NodeType, i64)> = stmt
            .query_map([], |row| {
                let type_str: String = row.get(0)?;
                let count: i64 = row.get(1)?;
                let node_type = match type_str.as_str() {
                    "knots" => NodeType::Knots,
                    "core" => NodeType::Core,
                    "libre" => NodeType::LibreRelay,
                    "other" => NodeType::Other,
                    _ => NodeType::Unknown,
                };
                Ok((node_type, count))
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(counts)
    }

    pub fn prune_old(&self, before: DateTime<Utc>) -> Result<usize> {
        let conn = self.conn.lock().unwrap();
        let count = conn.execute(
            "DELETE FROM nodes WHERE last_seen < ?1 AND is_reachable = 0",
            params![before.to_rfc3339()],
        )?;
        Ok(count)
    }
}
