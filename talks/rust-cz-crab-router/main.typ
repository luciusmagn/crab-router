#import "@preview/touying:0.5.3": *
#import themes.metropolis: *

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => [Rust CZ Meetup · Information Theory vs Filters],
  config-info(
    title: [Information Theory vs Filters],
    subtitle: [Bitcoin mempool filtering, topology, steganography, and a Rust demo],
    author: [Lukáš Hozda],
    institution: [Braiins],
    date: [Rust Czech Republic Meetup],
  ),
)

#title-slide()

= Intro

== Lukáš Hozda

- Marketing at Braiins #pause
- Rust/Lisp programmer #pause
- Former embedded Rust developer #pause
- Teaching Rust at MatFyz

== Context

- Ongoing Core vs Knots debate #pause
- Filtering is one of the main fault lines #pause
- Focus today: mempool / relay-level filtering #pause
- `BIP-110` exists, but consensus-level filtering is out of scope today

== Ordinals

- Ordinals are a convention for tracking individual satoshis #pause
- They assign each sat a stable identity/index within the total supply #pause
- That lets people say "this specific sat moved here" #pause
- By themselves, ordinals are about identification and tracking, not content

== Inscriptions

- Inscriptions are arbitrary data embedded in Bitcoin transactions (usually witness data) #pause
- In the ordinals ecosystem, an inscription is associated with a specific sat #pause
- The payload can be images, text, HTML, or other bytes #pause
- This is the part that usually triggers filtering debates

== Difference

- `Ordinal` = which sat #pause
- `Inscription` = what data is attached/associated #pause
- You can discuss ordinals as tracking without discussing inscriptions #pause
- In practice, the current controversy is mostly about inscriptions

== Criticism

- Most criticism targets inscriptions and transaction patterns, not the numbering convention itself #pause
- One concern is chain data / blockspace usage (especially witness payloads) #pause
- Another concern is UTXO set growth from certain usage patterns #pause
- These are different resource problems and should not be conflated

= Network

== Mempool

- There is no single global mempool #pause
- Every node has its own local mempool #pause
- Local policy decides what is accepted and relayed #pause
- Miners build blocks from what they see and what pays

== Gossip

- Nodes talk to peers, not to a central coordinator #pause
- Transactions propagate hop by hop #pause
- Topology matters: peers, connectivity, implementation mix #pause
- Small relay minorities can still create viable paths

== Handshake

- `version`: announces protocol version, services, user agent, and chain height #pause
- `verack`: confirms the handshake #pause
- `ping`: keepalive / liveness check #pause
- `pong`: response to `ping`

== Relay

- `inv`: "I have object(s) with these hashes" (announcement only) #pause
- `getdata`: "send me the full object for these hashes" #pause
- `tx`: full transaction payload

== Discovery

- `getaddr`: "send me peer addresses" #pause
- `addr`: list of peer addresses

== Relay Flow

- Node A sends `inv` with tx hash(es) #pause
- Node B decides what it wants #pause
- Node B sends `getdata` for selected txs #pause
- Node A sends `tx` with full bytes #pause
- This reduces bandwidth compared to pushing full txs to everyone

== Filtering

- Mempool filtering is local policy, not consensus #pause
- It can block relay through that node #pause
- It cannot directly control the whole network topology #pause
- The real question is network-wide effectiveness

= Limits

== Topology

- Relay is path-based #pause
- Transactions need some permissive paths, not universal approval #pause
- More connectivity makes bypass easier #pause
- Strong suppression needs near-universal adoption

== Sub-1 sat/vB

- We already have a concrete precedent #pause
- Many nodes reject or deprioritize sub-1 sat/vB transactions #pause
- They still propagate and still get mined #pause
- Relay policy does not equal miner/pool inclusion policy #pause
- Partial filtering is not network-wide suppression

== Steganography

- Useful protocols have encoding capacity #pause
- Bitcoin transactions have a large valid design space #pause
- Data can be embedded in forms that look economically ordinary #pause
- Filters must infer intent from valid transactions

== Examples

- Explicit payload fields (for example `OP_RETURN`) #pause
- Witness data payloads (the inscriptions case) #pause
- Data encoded indirectly via transaction structure/pattern choices #pause
- The same information can be moved between multiple valid representations

== Asymmetry

- Filters remove known patterns #pause
- Encoders move to new patterns #pause
- Encoders have more degrees of freedom than filters #pause
- This is a structural limit

== Incentives

- "Spam" definitions do not remove the limits above #pause
- Filtering can push embedding into worse forms #pause
- `OP_RETURN` is prunable; fake UTXO growth is worse #pause
- Incentives and harm reduction matter more than prohibition

== Miners

- Miners (more precisely pools) run nodes too #pause
- Their incentive is fee revenue and reliable block production #pause
- They do not automatically share relay-policy filtering goals #pause
- Even strong relay filtering can fail if mining incentives remain permissive

= Rust

== Rust at Braiins

- Rust across embedded systems #pause
- Rust in infrastructure components #pause
- Rust in high-level, low-latency network services

== Async in Rust

- `async fn` lets us write non-blocking I/O code in direct style #pause
- Futures represent work that can make progress over time #pause
- `.await` yields control while waiting for I/O #pause
- This is a good fit when one process manages many peer connections

== Tokio

- Network software is mostly waiting: sockets, timeouts, backpressure #pause
- Async tasks make large peer sets practical #pause
- Rust gives memory safety under concurrency #pause
- Metrics/logging compose well in the same process

```rust
loop {
    tokio::select! {
        result = stream.read(&mut buf) => { /* parse */ }
        Some(msg) = outbound_rx.recv() => { /* send */ }
        _ = keepalive.tick() => { /* ping */ }
    }
}
```

== Demo Tool

- `crab-router` is a demo instrument supporting the argument #pause
- It connects to many mainnet peers and classifies implementations #pause
- It observes relay, discovery, and transaction flow metrics #pause
- The point is measurement and demonstration

= Demo

== Demo

- Live `crab-router` run on mainnet #pause
- Peer mix and transaction flow in Grafana #pause
- Discovery traffic (`addr` / `getaddr`) #pause
- Use observations to support the topology argument

= End

== Q&A
