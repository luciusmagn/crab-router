#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let page-fill = rgb("#f8f5ee")
#let legacy-fill = rgb("#f1ddd7")
#let miner-fill = rgb("#dcebdc")
#let pool-fill = rgb("#dce8f2")
#let bridge-fill = rgb("#eee7c8")
#let line-color = rgb("#89939a")

#let flow-box(body, fill: pool-fill) = block(
  width: 100%,
  inset: 9pt,
  radius: 4pt,
  fill: fill,
  stroke: line-color,
)[
  #align(center)[#body]
]

#let flow-arrow = align(center + horizon)[
  #text(size: 1.35em, weight: "bold")[#sym.arrow.r]
]

#let flow-vertical = align(center)[
  #text(size: 1.1em, weight: "bold")[#sym.arrow.b #h(5pt) #sym.arrow.t]
]

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [Stratum V2 / DATUM],
  config-info(
    title: [Stratum V1, V2, and DATUM],
    author: [Lukáš Hozda],
    institution: [Braiins],
  ),
  config-page(
    fill: page-fill,
  ),
  config-colors(
    neutral-lightest: page-fill,
  ),
  config-common(
    show-strong-with-alert: false,
  ),
)

#title-slide()[
  #align(center + horizon)[
    = Stratum V1, V2, and DATUM
  ]
]

== Agenda

- Stratum V1 jobs and shares #pause
- Who controls a V1 block template #pause
- DATUM's gateway model #pause
- Stratum V2's three protocols #pause

= Stratum V1

== Terms

- *Block template*: candidate block contents before proof of work #pause
- *Mining job*: template-derived search space given to mining hardware #pause
- *Network target*: proof-of-work threshold for a valid Bitcoin block #pause
- *Share target*: easier threshold used to measure a miner's work #pause
- *Share*: valid proof of work for the pool, usually not a valid block #pause
- *Coinbase transaction*: first transaction; claims the subsidy and fees and carries the *extranonce*

== Stratum V1

#align(center + horizon)[
  #grid(
    columns: (1.2fr, auto, 1fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    flow-box([
      *Pool infrastructure* \
      #text(size: 0.72em)[Bitcoin node + template builder + Stratum server]
    ], fill: pool-fill),
    flow-arrow,
    flow-box([
      *Mining proxy* \
      #text(size: 0.72em)[optional]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *ASICs* \
      #text(size: 0.72em)[hashing]
    ], fill: legacy-fill),
  )

  #v(1.1em)
  jobs flow right, shares flow left
]

== V1 job flow

- Pool builds a block template and derives a mining job #pause
- `mining.notify` sends the previous block hash, coinbase parts, Merkle branches, version, target bits, and time #pause
- Miner varies the extranonce, nonce, time, and allowed version bits #pause
- Miner returns hashes that meet the pool's easier share target #pause
- Pool validates the shares and pays for the measured work

== Miner-controlled fields

- The extranonce changes the coinbase transaction #pause
- That changes the coinbase transaction ID and therefore the Merkle root #pause
- The nonce, time, and permitted version bits provide more header search space #pause
- These fields create many hashes from one pool-supplied job #pause
- None of them changes the non-coinbase transaction set

== Pool controls the template

- ASICs dont have mempools#pause
- The pool's node and template builder select the transactions #pause
- A miner can point hash rate elsewhere, but cannot edit the current job #pause
- A few pool operators therefore choose block contents for a large share of Bitcoin's hash rate

== V1 limitations

#text(size: 0.82em)[
  - Pool-built templates
    - Pool chooses transactions for all connected hash rate #pause
  - JSON wire format
    - More bytes and parsing than a binary protocol needs #pause
  - Informal dialects and extensions
    - Compatibility depends on implementation quirks #pause
  - No native authentication or encryption
    - Protection has to come from TLS, a VPN, or the network #pause
  - Coinbase and Merkle work on mining devices
    - More bandwidth and firmware complexity
]

= Template Control

== Split construction from accounting

#align(center + horizon)[
  #grid(
    columns: (1fr, 16pt, 1fr),
    column-gutter: 18pt,
    align: center + horizon,
    flow-box([
      *Template construction* \
      #text(size: 0.72em)[Transactions in the candidate block]
    ], fill: miner-fill),
    [],
    flow-box([
      *Pool accounting* \
      #text(size: 0.72em)[Accepted shares and miner payouts]
    ], fill: pool-fill),
  )

  #v(1em)
    Miner can built the template in both SV2 & DATUM (must in DATUM), pool tracks shares and pays miners

]

==

- Miner's BTC node supplies the template #pause
- Its mempool and policy determine the transaction set #pause
- Pool still accounts for shares and pays miners #pause
- Miner's node can publish a found block

= DATUM

== DATUM architecture

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1.25fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([
      *Local Bitcoin node* \
      #text(size: 0.7em)[mempool + `getblocktemplate`]
    ], fill: miner-fill),
    flow-arrow,
    flow-box([
      *DATUM Gateway* \
      #text(size: 0.7em)[constructs jobs and validates local shares]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *ASICs* \
      #text(size: 0.7em)[Stratum V1]
    ], fill: legacy-fill),
  )

  #v(0.25em)
  #flow-vertical
  #v(0.25em)
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    [],
    flow-box([
      *DATUM Prime / pool* \
      #text(size: 0.7em)[encrypted DATUM link; payout data and share accounting]
    ], fill: pool-fill),
    [],
  )
]

== How DATUM works

#text(size: 0.78em)[DATUM: Decentralized Alternative Templates for Universal Mining]

#v(0.45em)

1. The local node builds a template and returns it through `getblocktemplate` #pause
2. The pool sends coinbase payout data and validity constraints #pause
3. The Gateway builds the coinbase, Merkle root, and V1 jobs #pause
4. ASICs hash those jobs and return shares to the Gateway #pause
5. The Gateway checks shares and forwards qualifying ones to the pool #pause
6. The miner's node publishes a solved block

== DATUM only mines local templates

- The Gateway creates work only from the miner's local node #pause
- DATUM defines no path for a pool-supplied template #pause
- The pool cannot replace the local template without a configuration change #pause
- This guarantees local control but limits DATUM to that use case

= Stratum V2

== Three protocols

#text(size: 0.8em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Protocol*], [*Responsibility*],
    [Mining Protocol], [Jobs, channels, targets, shares, and solutions],
    [Template Distribution Protocol], [Templates and transaction data from a full node],
    [Job Declaration Protocol], [Miner-created jobs proposed to a pool],
  )
]

#v(0.8em)

The Mining Protocol can run alone. Job Declaration is optional, so SV2 does not automatically decentralize template construction.

== SV2 roles

- *Template Provider*: node-side source of block templates #pause
- *Job Declarator Client (JDC)*: miner-side coordinator for custom jobs #pause
- *Job Declarator Server (JDS)*: pool-side approval and validation service #pause
- *Mining proxy*: distributes jobs and aggregates downstream connections

== Stratum V2 architecture

#align(center + horizon)[
  #grid(
    columns: (1fr, 28pt, 1.25fr, 28pt, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([
      *Template Provider* \
      #text(size: 0.7em)[Bitcoin node + Template Distribution]
    ], fill: miner-fill),
    flow-arrow,
    flow-box([
      *JDC / proxy* \
      #text(size: 0.7em)[declares custom jobs and distributes work]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *ASICs* \
      #text(size: 0.7em)[native V2 or V1 through translation]
    ], fill: legacy-fill),
  )

  #v(0.25em)
  #flow-vertical
  #v(0.25em)
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    [],
    flow-box([
      *JDS + pool* \
      #text(size: 0.7em)[approves custom work; accounts shares and payouts]
    ], fill: pool-fill),
    [],
  )
]

== How a custom SV2 job works

1. Template Provider pushes a template to the miner-side JDC #pause
2. JDC obtains a job token and required pool coinbase outputs #pause
3. JDC builds a custom job from the local template #pause
4. Full-template reveals the transaction set; coinbase-only keeps it private #pause
5. The pool accepts the custom job and agrees to pay its shares #pause
6. The JDC distributes work and forwards shares; the miner's node publishes a found block

== Two Job Declaration modes

#text(size: 0.76em)[
  #table(
    columns: (auto, 1fr, 1fr),
    align: left,
    [*Property*], [*Full-template*], [*Coinbase-only*],
    [Transaction set], [Declared by transaction IDs; missing data can be requested], [Not revealed to pool or JDS],
    [Fee and validity checks], [JDS can verify the proposed template], [Pool cannot independently verify the transaction set],
    [Privacy], [JDS learns the template], [Miner's mempool remains private],
    [Tradeoff], [More verification], [More withholding / invalid-template risk for pool],
  )
]

== SV2 transport and work distribution

- Binary framing with one precise specification #pause
- AEAD-encrypted remote connections with a Noise handshake #pause
- Multiple channels per connection and efficient proxy aggregation #pause
- Header-only jobs that keep coinbase and Merkle handling away from ASICs #pause
- Future jobs prepared before a new previous-block hash arrives #pause
- Native version rolling and specified protocol extensions

= Comparison

== SV2 and DATUM

#text(size: 0.67em)[
  #table(
    columns: (auto, 1fr, 1fr),
    align: left,
    [*Dimension*], [*Stratum V2*], [*DATUM*],
    [Scope], [General mining protocol suite], [Gateway for local templates and pool accounting],
    [ASIC-facing link], [Native V2, or translated V1], [V1 today],
    [Node-facing link], [Template Distribution Protocol], [`getblocktemplate` over RPC],
    [Template source], [Pool jobs or miner custom jobs], [Miner's local node only],
    [Template validation], [Full-template or coinbase-only mode], [Pool-coordinated today; intended to become mostly blind],
    [Specification], [Published modular protocol], [Open implementation; pool protocol described as evolving],
    [Remote security], [Specified Noise/AEAD transport], [Encrypted custom DATUM transport],
  )
]

== Stratum V2 pros

#text(size: 0.86em)[
  - Replaces V1 on the pool link and inside the farm #pause
  - Gives pools, firmware, proxies, and nodes one published standard #pause
  - Uses the same security, framing, and channel model across implementations #pause
  - Defines a mining-specific path for node-to-miner templates #pause
  - Supports verified full-template jobs and private coinbase-only jobs #pause
  - Allows pool jobs and V1 translation during migration
]

== DATUM's differences

- Existing V1 ASICs work unchanged behind one Gateway #pause
- Local template construction is mandatory by design #pause
- Its narrow design suits miners who only want local template control #pause
- There is no pool-supplied fallback path

== Q&A
