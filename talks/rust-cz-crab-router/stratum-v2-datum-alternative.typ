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

- Stratum V1 jobs, shares, and template control #pause
- DATUM's gateway architecture #pause
- Stratum V2's three protocols #pause
- FPPS with miner-created templates #pause
- Technical and specification differences

= Stratum V1

== Terms

- *Block template*: candidate block contents before proof of work #pause
- *Mining job*: search space derived from a block template #pause
- *Network target*: proof-of-work threshold for a valid Bitcoin block #pause
- *Share target*: easier threshold used by a pool to measure work #pause
- *Share*: proof of work valid for the pool, usually not for the Bitcoin network #pause
- *Coinbase transaction*: first transaction; claims subsidy and fees and carries the extranonce

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

- The pool builds a block template and derives a mining job #pause
- `mining.notify` sends the previous block hash, coinbase parts, Merkle branches, version, `nBits`, and time #pause
- Extranonce parameters and the share target are supplied separately #pause
- The miner constructs the coinbase and Merkle root, then searches nonce, extranonce2, time, and allowed version bits #pause
- The pool validates submitted shares and accounts for the measured work

== Miner-controlled fields

- Extranonce2 changes the coinbase transaction #pause
- The new coinbase transaction changes the Merkle root #pause
- Nonce, time, and permitted version bits provide additional header search space #pause
- These fields produce many candidate headers from one pool job #pause
- They do not change the non-coinbase transaction set

== Pool controls the template

- ASICs do not maintain mempools #pause
- The pool's node and template builder select the transactions #pause
- A mining proxy can distribute a job, but cannot replace its transaction set #pause
- A miner can reject the job or change pools, but cannot modify the current template #pause
- Pool operators therefore select block contents for their connected hash rate

== V1 limitations

#text(size: 0.8em)[
  - *Pool-built templates*
    - transaction selection is concentrated at pools #pause
  - *JSON wire format*
    - more bytes and parsing than a binary protocol #pause
  - *Informal specification, dialects, and extensions*
    - compatibility depends on established implementation behavior #pause
  - *No native authentication or encryption* #pause
  - *No standard channel model for proxy aggregation* #pause
  - *Coinbase and Merkle processing below the pool*
    - additional bandwidth and firmware or proxy work
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
  DATUM and Stratum V2 can move template construction to the miner while retaining pool accounting.
]

== Miner-created templates

- The miner's Bitcoin node supplies the template #pause
- Its mempool and policy determine the transaction set #pause
- The pool supplies required coinbase outputs and validates shares #pause
- The miner's node can submit a solved block #pause
- FPPS additionally requires a credible transaction-fee value for each declared job

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

== DATUM custom-template flow

#text(size: 0.78em)[DATUM: Decentralized Alternative Templates for Universal Mining]

#v(0.45em)

1. The local Bitcoin node builds a block template #pause
2. The pool provides its payout requirements #pause
3. The Gateway combines both into a Stratum V1 mining job #pause
4. ASICs mine the job and return shares through the Gateway #pause
5. The pool accounts for the accepted shares #pause
6. The local Bitcoin node submits a solved block

== DATUM template policy

- The Gateway creates work only from the miner's local node #pause
- DATUM defines no pool-supplied template path #pause
- Local template construction is mandatory #pause
- Existing ASICs continue to use Stratum V1 #pause
- The node-facing interface remains `getblocktemplate` #pause
- The Gateway-to-pool protocol is DATUM-specific and described as evolving

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

The Mining Protocol can run alone. Job Declaration is optional, so SV2 does not by itself move template construction to miners.

== SV2 roles

- *Template Provider*: node-side source of block templates #pause
- *Job Declarator Client (JDC)*: miner-side coordinator for custom jobs #pause
- *Job Declarator Server (JDS)*: pool-side job validation and acceptance #pause
- *Mining proxy*: distributes jobs and aggregates downstream channels

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
      #text(size: 0.7em)[accepts custom work; accounts for shares and payouts]
    ], fill: pool-fill),
    [],
  )
]

== Stratum V2 custom-template flow

1. The miner's Bitcoin node builds a block template #pause
2. The pool provides its payout requirements #pause
3. The miner-side JDC combines both into a custom job #pause
4. The JDC declares the job to the pool-side JDS #pause
5. The pool validates and accepts the job #pause
6. Mining devices receive the job; shares go to the pool and a solved block is submitted locally

== Two Job Declaration modes

#text(size: 0.74em)[
  #table(
    columns: (auto, 1fr, 1fr),
    align: left,
    [*Property*], [*Full-template*], [*Coinbase-only*],
    [Transaction set], [Declared; missing transactions can be requested], [Not revealed to pool or JDS],
    [Fee and validity checks], [JDS can verify the proposed template], [Pool cannot independently verify the transaction set],
    [Privacy], [JDS learns the template], [Transaction set remains private],
    [Pool risk], [Validated job], [Requires a separate risk policy],
  )
]

== SV2 transport and work distribution

- Binary framing with a published specification #pause
- Noise handshake and AEAD transport #pause
- Multiple channels per connection and proxy aggregation #pause
- Header-only jobs that keep coinbase and Merkle processing away from ASICs #pause
- Future jobs prepared before a new previous-block hash arrives #pause
- Native version rolling and specified protocol extensions

= FPPS

== FPPS requirement

FPPS pays the expected subsidy and transaction fees for each accepted share.

#v(0.3em)

#align(center)[
  $P_"share" = D_"eff" / D_"net" (R_"base" + F)$
]

#v(0.3em)

#text(size: 0.86em)[
  - $P_"share"$: gross payout for one accepted share #pause
  - $D_"eff"$: difficulty credited to the share #pause
  - $D_"net"$: Bitcoin network difficulty #pause
  - $R_"base"$: block subsidy #pause
  - $F$: transaction fees assigned to the job
]

#text(size: 0.86em)[The pool pays before a block is found. It must verify or limit $F$.]

== FPPS with full-template declaration

1. The miner selects the transactions #pause
2. The JDC declares the transaction set and coinbase data #pause
3. The JDS obtains missing transactions and validates the template #pause
4. The pool computes $F_"verified"$ #pause
5. The accepted job and its shares use the verified fee value

#v(0.5em)

#align(center)[
  $P_"share" = D_"eff" / D_"net" (R_"base" + F_"verified")$
]

#v(0.4em)

No fee cap or additional incentive mechanism is required.

== FPPS with coinbase-only declaration

The pool cannot verify the transaction set before a block is found.

#v(0.35em)

#align(center)[
  $F_"cap" = min(F_"declared", gamma F_"avg")$
]
#align(center)[
  $P_"share" = D_"eff" / D_"net" (R_"base" + F_"cap")$
]
#align(center)[
  $B_"surplus" = lambda dot max(0, F_"real" - F_"cap")$
]

#v(0.2em)

#text(size: 0.76em)[
  - $gamma$ (“gamma”) multiplies the recent average fee, for example 1.4 #pause
  - The fee cap bounds exposure; it does not verify the fee claim #pause
  - $lambda$ is the fraction of verified surplus paid, from 0 to 1 #pause
  - $max(0, x)$ returns zero when $x$ is negative
]

== Claim that FPPS is impossible with SV2

- The claim is false as a general statement #pause
- Full-template Job Declaration lets the miner select transactions and the pool verify their fees #pause
- Coinbase-only declaration requires a separate risk policy #pause
- SV2 does not define FPPS policy; it supplies the data required to implement it

#v(0.5em)

#text(size: 0.68em)[Based on Pavlenex, _FPPS with JD Modes (Stratum V2 Compatible)_.]

= Comparison

== SV2 and DATUM

#text(size: 0.62em)[
  #table(
    columns: (auto, 1fr, 1fr),
    align: left,
    [*Dimension*], [*Stratum V2*], [*DATUM*],
    [Scope], [Mining protocol suite], [Gateway for local templates and pool accounting],
    [ASIC-facing link], [Native V2 or translated V1], [V1],
    [Node-facing link], [Template Distribution Protocol], [`getblocktemplate` RPC],
    [Template source], [Pool jobs or miner-created jobs], [Miner's local node only],
    [Template validation], [Full-template or coinbase-only declaration], [Pool-specific behavior],
    [FPPS path], [Verified full-template accounting], [No interoperable protocol flow specified],
    [Specification], [Published modular protocol standard], [Open implementation; pool protocol described as evolving],
    [Remote security], [Specified Noise/AEAD transport], [Encrypted DATUM transport],
  )
]

== Why Stratum V2 is preferable

#text(size: 0.82em)[
  - Replaces V1 on the pool link and can replace it inside the farm #pause
  - Defines interfaces for nodes, pools, proxies, and mining devices #pause
  - Provides a published protocol standard independent of one implementation #pause
  - Supports pool-created and miner-created jobs #pause
  - Supports verifiable FPPS through full-template Job Declaration #pause
  - Standardizes framing, transport security, channels, and extensions #pause
  - Allows V1 translation during migration
]

== DATUM trade-offs

- Existing V1 ASICs work unchanged behind one Gateway #pause
- Local template construction is mandatory #pause
- V1 and `getblocktemplate` remain part of the architecture #pause
- The pool protocol is specific to DATUM and still evolving #pause
- FPPS validation is not defined as an interoperable protocol flow #pause
- An open implementation is not equivalent to an open protocol standard

== Q&A
