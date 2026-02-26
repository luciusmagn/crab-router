#import "@preview/touying:0.5.3": *
#import themes.simple: *

#show: simple-theme.with(
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

#set page(fill: rgb("#f8f5ee"))

#align(center + horizon)[
  #image("braiins-symbol-black-rgb.png", width: 28%)
]

#title-slide()[
  #align(center + horizon)[
    = Information Theory vs Filters
  ]
]

= Intro

== Lukáš Hozda

- Marketing at Braiins #pause
- Rust/Lisp programmer #pause
- Bitcoin, Emacs, HTMX, Linux enthusiast #pause
- Teaching Rust at MatFyz

==

#align(center)[
  #image("lukas-rust-book.png", height: 86%)
]

== Context

- There is an ongoing Core vs Knots debate #pause
- Filtering is one of the main (technical) fault lines #pause
  - Proponents of filtering want to filter arbitrary data embedding #pause
  - All non-monetary data on the blockchain == spam (?) and should be rejected #pause
- Focus today: mempool / relay-level filtering #pause
- `BIP-110` exists, but consensus-level filtering is out of scope today

== Ordinals

- Ordinals are a convention for tracking individual satoshis #pause
- More precisely, ordinal theory is one ruleset for saying "these sats are the same" across transactions #pause
- You could define a different tracking ruleset; the point is social coordination and shared interpretation #pause
- They assign each sat a stable identity/index within the total supply #pause
- That lets people say "this specific sat moved here" #pause
- By themselves, ordinals are about identification and tracking, not content

== Inscriptions

- Inscriptions are arbitrary data embedded in Bitcoin transactions (usually witness data) #pause
  - Witness data is discounted, so they can fit in more of it
- In the ordinals ecosystem, an inscription is associated with a specific sat #pause
- The payload can be images, text, HTML, or other bytes #pause
- This is the part that usually triggers filtering debates

== Difference

- `Ordinal` = which sat #pause
- `Inscription` = what data is attached/associated #pause
- You can discuss ordinals as tracking without discussing inscriptions #pause
- In practice, people usually discuss the combined ordinals+inscriptions ecosystem

== Criticism

- Most criticism targets inscriptions and transaction patterns, not the numbering convention itself #pause
- Block weight is bounded, so this is not "infinite blockchain bloat per block" #pause
  - The "unrestricted growth" is also often cited for OP_RETURN #pause
- One concern is competition for scarce blockspace (including witness-heavy payloads) #pause
- Another concern is UTXO set growth from certain usage patterns #pause
- These are different resource problems and should not be conflated

== UTXO Set

#align(center)[
  #image("utxo-set-chart.png", height: 80%)
]

== Chain Growth

- The more precise concern is sustained chain growth over time and who uses scarce blockspace #pause
- Historical storage, bandwidth, and validation costs still accumulate #pause
- UTXO set can shrink, the blockchain can't

==

#align(center)[
  #image("blockchain-size-growth.png", width: 95%)
]

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

== BTC wire protocol

- The protocol through which nodes talk is pretty simple
- We can make a relay just by being able to process a few message types

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

- Steganography = hiding a message inside another valid-looking carrier #pause
- The receiver needs an extraction rule, but outsiders may only see an ordinary object #pause
- The carrier still "works" for its normal purpose #pause
- Steganography is about covert encoding, not encryption

== Bitcoin

- Bitcoin transactions are structured, expressive, and highly constrained at the same time #pause
- Many different valid transactions can represent similar economic intent #pause
- This gives adversaries room to encode side-information while staying consensus-valid #pause
- Filters must infer intent from valid transactions

== General Examples

- Image pixels: least-significant bits can carry a hidden message with little visible change #pause
- Text: whitespace, capitalization, or punctuation patterns can encode bits #pause
- Network traffic: timing, padding, or packet ordering can carry side-information #pause
- The same message can often move between multiple carriers

== Rust example

- I have a tiny Rust example that hides a message in image pixel bytes (LSB) #pause
- I show it on a BMP photo #pause
- The encoder writes one hidden bit into the lowest bit of each pixel byte #pause
- The decoder reads those low bits back in the agreed order

== Encoding

```rust
fn put_bit(byte: &mut u8, bit: u8) {
    *byte = (*byte & !1) | (bit & 1);
}

for (i, bit) in bits.enumerate() {
    put_bit(&mut pixels[i], bit);
}
```

== Decoding

```rust
let mut out = 0u8;
for (shift, b) in pixels[i..i + 8].iter().enumerate() {
    out |= (b & 1) << shift;
}
```

== Original BMP

#align(center)[
  #image("me-original.png", height: 80%)
]

== Encoded BMP

#align(center)[
  #image("me-encoded.png", height: 80%)
]

== BTC Examples

- Explicit payload fields (for example `OP_RETURN`) #pause
- Witness data payloads (the inscriptions case) #pause
- Data encoded indirectly via transaction structure/pattern choices #pause
- The same information can be moved between multiple valid representations

== Encodings

- `OP_RETURN` and visible witness payloads are easy to identify #pause
- Other encodings can be much less visible at policy level #pause
- Example: data hidden in synthetic / fake public-key-like material or script patterns #pause
- Filtering one encoding path can push usage into less transparent and more harmful ones

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

== Async Rust

- Since async was merged, Rust is very good at network programming with many peers #pause
- We can tackle many connections and events at once, with low overhead #pause
- Rust is also generally a good fit for sensitive applications (hence its adoption in e.g. BDK) #pause
  - Not relevant for this example, though #pause
- This makes Rust invaluable for both Braiins OS and Braiins Pool

== Tokio

- Network software is mostly waiting: sockets, timeouts, backpressure #pause
- Async tasks make large peer sets practical #pause
- Rust gives memory safety under concurrency #pause
- Metrics/logging compose well in the same process #pause
  - We can use Prometheus!

== Tokio
```rust
loop {
    tokio::select! {
        result = stream.read(&mut buf) => { /* parse */ }
        Some(msg) = outbound_rx.recv() => { /* send */ }
        _ = keepalive.tick() => { /* ping */ }
    }
}
```

== Rust pitch part 2: The electric boogaloo

- Hostile network input benefits from strong typing and explicit parsing #pause
- Enums + `match` make protocol state handling readable and auditable #pause
- Bounded channels make backpressure decisions explicit #pause
- You can push performance without giving up memory safety

== Patterns

- One task per peer is easy to reason about #pause
- `tokio::select!` maps naturally to socket/read/write/keepalive loops #pause
- `Arc<RwLock<...>>` is enough for shared relay state and metrics in a small tool #pause
- `tracing` + Prometheus + Axum make observability cheap

== Prometheus shill

- Rust has a solid Prometheus crate with the usual metric types (counter / gauge / histogram) #pause
- Instrumentation is straightforward to wire into normal application code paths #pause
- Exposing `/metrics` over Axum is simple and production-friendly #pause
- Grafana integration is immediate; we do not need custom telemetry plumbing

== Demo Tool

- `crab-router` is a demo instrument supporting the argument #pause
- It connects to many mainnet peers and classifies implementations #pause
- It observes relay, discovery, and transaction flow metrics #pause
- The point is measurement and demonstration

== Thesis

- In this topology, relay-level filtering is easy to route around #pause
- Even a filtering majority does not imply network-wide suppression #pause
- A permissive relay layer can explicitly bridge filtered regions and miners / pools #pause
- Pools do not automatically share content-filtering incentives if the transactions pay

= Demo

== Demo

- Live `crab-router` run on mainnet #pause
- Peer mix and transaction flow in Grafana #pause
- Discovery traffic (`addr` / `getaddr`) #pause

= End

== Q&A
