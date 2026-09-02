#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let page-fill = rgb("#f8f5ee")
#let l1-fill = rgb("#dce8f2")
#let l2-fill = rgb("#dcebdc")
#let miner-fill = rgb("#eee7c8")
#let risk-fill = rgb("#f1ddd7")
#let fork-fill = rgb("#eadfd2")
#let bridge-fill = rgb("#e7e0ed")
#let line-color = rgb("#89939a")

#let flow-box(body, fill: l1-fill) = block(
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

#let flow-left = align(center + horizon)[
  #text(size: 1.35em, weight: "bold")[#sym.arrow.l]
]

#let flow-bidir = align(center + horizon)[
  #text(size: 1.15em, weight: "bold")[#sym.arrow.l #h(2pt) #sym.arrow.r]
]

#let flow-down = align(center)[
  #text(size: 1.2em, weight: "bold")[#sym.arrow.b]
]

#let compact(body) = text(size: 0.82em)[#body]

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [Drivechains / eCash],
  config-info(
    title: [Drivechains: BIP 300, BIP 301, and eCash],
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
    = Drivechains: BIP 300, BIP 301, and eCash
  ]
]

== Agenda

- The two-way peg problem #pause
- BIP 300 hashrate escrows #pause
- BIP 301 blind merged mining #pause
- Paul Sztorc's planned eCash fork, CUSF, and mining compatibility

= Drivechains

== The three bois

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 14pt,
    align: center + horizon,
    flow-box([
      *BIP 300* \
      #text(size: 0.72em)[Peg state, deposits, and miner-approved withdrawals]
    ], fill: bridge-fill),
    flow-box([
      *BIP 301* \
      #text(size: 0.72em)[A fee market for committing sidechain blocks]
    ], fill: miner-fill),
    flow-box([
      *eCash* \
      #text(size: 0.72em)[A separate L1 fork that plans to enable both]
    ], fill: fork-fill),
  )
]

#place(bottom + center, dy: -50pt)[
  #text(size: 0.76em)[So far, eCash has attracted far less controversy than BIP 110.]
]

== Proposal status

- *BIP 300*: Hashrate Escrows, assigned August 2017, Draft #pause
- *BIP 301*: Blind Merged Mining, assigned July 2019, Draft #pause
- Both are consensus soft-fork proposals #pause
- Neither is active on Bitcoin #pause
- Current implementations can enforce them outside Bitcoin Core through CUSF

== Terms

#compact[
  - *Sidechain*: a separate ledger with its own validation rules #pause
  - *Peg-in*: lock L1 coins and recognize an equivalent balance on the sidechain #pause
  - *Peg-out*: destroy or lock the sidechain balance and release coins on L1 #pause
  - *Treasury UTXO*: the single L1 output holding one sidechain's locked funds #pause
  - *CTIP*: the cached txid and output index of the current treasury UTXO #pause
    - Current Treasury Index Pointer #pause
  - *Withdrawal bundle*: one L1 transaction aggregating many sidechain peg-outs #pause
  - *Blind merged mining*: buying an L1 commitment to an L2 block without asking the L1 miner to validate that L2
]

== A two-way peg

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1.15fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    flow-box([
      *Bitcoin UTXOs* \
      #text(size: 0.7em)[user-controlled]
    ], fill: l1-fill),
    flow-arrow,
    flow-box([
      *BIP 300 treasury* \
      #text(size: 0.7em)[one UTXO per sidechain slot]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *Sidechain ledger* \
      #text(size: 0.7em)[independent rules and state]
    ], fill: l2-fill),
  )

  #v(0.8em)
  #text(size: 0.78em)[Deposits move value right. Approved withdrawal bundles move value left.]
]

== Withdrawal approval by block voting

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 18pt,
    align: top,
    flow-box([
      *Federated peg* \
      #text(size: 0.72em)[A known threshold of keys signs withdrawals]
    ], fill: l1-fill),
    flow-box([
      *Drivechain peg* \
      #text(size: 0.72em)[Future mainchain blocks accumulate approval for a withdrawal hash]
    ], fill: miner-fill),
  )

  #v(0.9em)
  BIP 300 replaces fixed-keyholder approval with approval accumulated across future mainchain block templates.
]

= BIP 300

== L1 state

- Up to 256 numbered sidechain slots #pause
- A sidechain list records each active slot and its current treasury outpoint #pause
- A withdrawal list records candidate bundle hashes, scores, and expiry #pause
- Bitcoin nodes enforcing BIP 300 track this state #pause
- They do not validate the sidechain's transactions or ledger

== messages

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 14pt,
    align: center + horizon,
    flow-box([
      *Sidechain slots* \
      #text(size: 0.74em)[M1 proposes \
      M2 acknowledges]
    ], fill: l2-fill),
    flow-box([
      *Withdrawal approval* \
      #text(size: 0.74em)[M3 proposes a bundle \
      M4 changes its score]
    ], fill: miner-fill),
    flow-box([
      *Peg movement* \
      #text(size: 0.74em)[M5 deposits \
      M6 withdraws]
    ], fill: bridge-fill),
  )
]

== Treasury output

#align(center)[
  #block(width: 62%)[
    #flow-box([
      *Current treasury UTXO* \
      #text(size: 0.78em)[`OP_DRIVECHAIN <1-byte slot> OP_TRUE`]
    ], fill: bridge-fill)
  ]
]

#v(0.7em)

#text(size: 0.8em)[
  - `OP_NOP5` becomes `OP_DRIVECHAIN` only in this exact script form #pause
  - Legacy nodes see a no-op followed by true, so the spend is valid #pause
  - Enforcing nodes permit only M5 or an approved M6 #pause
  - Every spend recreates one treasury UTXO for the slot
]

== Deposit path

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1.15fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    flow-box([*User inputs*], fill: l1-fill),
    flow-arrow,
    flow-box([
      *M5 transaction* \
      #text(size: 0.7em)[spends the old treasury, if present]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *Larger treasury UTXO* \
      #text(size: 0.7em)[becomes the new CTIP]
    ], fill: l2-fill),
  )

  #v(0.85em)
  #text(size: 0.8em)[The sidechain observes the deposit and applies its own rules for crediting the recipient.]
]

== Withdrawal path

#text(size: 0.78em)[
  1. Sidechain users request peg-outs #pause
  2. Sidechain software aggregates up to 6,000 payments into one M6 transaction #pause
  3. M3 places the blinded M6 hash in the mainchain withdrawal list #pause
  4. Mainchain blocks change that candidate's score through M4 #pause
  5. A score of 13,150 makes the corresponding M6 eligible #pause
  6. M6 pays users and recreates the treasury UTXO with the remaining balance
]

== Vote arithmetic

#align(center)[
  #grid(
    columns: (1fr, 1fr, 1fr, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([*Selected* \
      #text(size: 0.75em)[+1]], fill: l2-fill),
    flow-box([*Competing* \
      #text(size: 0.75em)[-1]], fill: risk-fill),
    flow-box([*No M4* \
      #text(size: 0.75em)[0]], fill: l1-fill),
    flow-box([*Alarm* \
      #text(size: 0.75em)[-1 to all]], fill: fork-fill),
  )
]

#v(0.75em)

- Required score: *13,150* #pause
- Candidate lifetime: *26,300 blocks* #pause
- Fastest approval is about 91 days; the full window is about 183 days #pause
- Downvotes increase the number of positive blocks required

== Block templates cast the votes

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1.2fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    flow-box([
      *Hashers* \
      #text(size: 0.7em)[supply proof of work]
    ], fill: l2-fill),
    flow-arrow,
    flow-box([
      *Pool / template builder* \
      #text(size: 0.7em)[chooses BIP 300 messages and BMM Accepts]
    ], fill: miner-fill),
    flow-arrow,
    flow-box([
      *Mainchain block* \
      #text(size: 0.7em)[turns choices into votes]
    ], fill: l1-fill),
  )
]

#v(0.7em)

Under ordinary pooled mining, the pool votes. An ASIC owner's fraction of hashrate is not independently represented on-chain.

== Withdrawal approval properties

#compact[
  - A withdrawal hash remains in the candidate set while its score changes
    - A withdrawal cannot reach approval in one block #pause
  - L1 does not verify sidechain state or a fraud proof
    - Sufficient approving templates can make a sidechain-invalid withdrawal eligible #pause
  - Miners may abstain, downvote, or omit the final M6
    - A valid peg-out may remain pending #pause
  - Monitoring can identify a sidechain-invalid bundle
    - Identification does not change its score or block eligibility
]

== Bridge, not block production

- BIP 300 defines sidechain slots and the two-way peg #pause
- It does not select or order sidechain blocks #pause
- Doesn't require one particular sidechain consensus either #pause
- BIP 301 supplies the proposed block-production market

= BIP 301

== Classical and blind merged mining

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 18pt,
    align: top,
    flow-box([
      *Classical merged mining* \
      #text(size: 0.7em)[Miner runs the other chain's node, validates its block, and receives its native coin]
    ], fill: l1-fill),
    flow-box([
      *Blind merged mining* \
      #text(size: 0.7em)[Sidechain user builds the block and bids an L1 fee for the miner's commitment]
    ], fill: miner-fill),
  )
]

== BMM actors

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([
      *L2 bidder* \
      #text(size: 0.7em)[builds candidate `h*`]
    ], fill: l2-fill),
    flow-arrow,
    flow-box([
      *L1 mempool* \
      #text(size: 0.7em)[BMM Request + fee]
    ], fill: bridge-fill),
    flow-arrow,
    flow-box([
      *Miner / pool* \
      #text(size: 0.7em)[chooses one request per slot]
    ], fill: miner-fill),
  )

  #v(0.25em)
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center,
    [], [], [], [], flow-down,
  )
  #v(0.2em)

  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 12pt,
    align: center + horizon,
    flow-box([
      *Sidechain nodes* \
      #text(size: 0.7em)[validate the full candidate]
    ], fill: l2-fill),
    flow-left,
    flow-box([
      *L1 block* \
      #text(size: 0.7em)[BMM Accept commits `h*`]
    ], fill: l1-fill),
  )
]

== One BMM round

#text(size: 0.8em)[
    1. A sidechain node constructs a candidate block and its hash, `h*` (hash of proposed sidechain block) #pause
    2. The bidder broadcasts an L1 transaction naming the slot, `h*`, and previous L1 block #pause
    3. Its transaction fee is the bid to the mainchain miner #pause
    4. The miner includes at most one matching BMM Accept per slot in the coinbase #pause
    5. Sidechain nodes validate the candidate and either connect it or reject it
]

== Blindness boundary

- Mainchain miner sees the sidechain slot, `h*`, and L1 fee #pause
- No need to the sidechain node or inspect sidechain transactions #pause
- Sidechain nodes still apply every sidechain validation rule #pause
- If the winning candidate is invalid, no sidechain block is added for that round #pause
- The miner still receives the L1 fee

== BIP 300 and 301 together

#align(center + horizon)[
  #grid(
    columns: (1fr, 18pt, 1fr),
    column-gutter: 16pt,
    align: center + horizon,
    flow-box([
      *BIP 301* \
      #text(size: 0.72em)[Which candidate becomes the next sidechain block?]
    ], fill: miner-fill),
    [],
    flow-box([
      *BIP 300* \
      #text(size: 0.72em)[When may the mainchain treasury release funds?]
    ], fill: bridge-fill),
  )

  #v(1em)
  blind mining commits the L2 block sequence, BIP 300 controls eligibility of the L1 withdrawal tx
]

== Outcomes in selected cases

#compact[
  - A template builder ignores BMM requests
    - That sidechain receives no anchored block for the round #pause
  - An invalid candidate wins the bid
    - Sidechain nodes reject it; the bidder loses the L1 fee #pause
  - The mainchain reorganizes
    - Sidechain commitments reorganize with it #pause
  - An invalid withdrawal accumulates enough score
    - BIP 300 permits the treasury spend; BIP 301 does not prevent it
]

= eCash

== A planned Bitcoin fork

#align(center)[
  #grid(
    columns: (1.2fr, auto, 1fr),
    rows: (auto, auto),
    column-gutter: 12pt,
    row-gutter: 10pt,
    align: center + horizon,
    grid.cell(rowspan: 2)[
      #flow-box([
        *Bitcoin history* \
        #text(size: 0.7em)[shared up to the fork snapshot]
      ], fill: l1-fill)
    ],
    flow-arrow,
    flow-box([
      *BTC* \
      #text(size: 0.7em)[network and rules continue]
    ], fill: l1-fill),
    flow-arrow,
    flow-box([
      *eCash / ECX* \
      #text(size: 0.7em)[new network and rules]
    ], fill: fork-fill),
  )
]

#v(0.65em)

- Planned target: BTC block *~963,648* #pause
- Current estimate: *22 August 2026* #pause
- Planned SHA-256d chain; it does not change BTC consensus rules or the BTC ledger

== Core Untouched Soft Fork

#compact[
  - CUSF keeps the added validation rules in a separate program
    - The Core-compatible node retains its existing validation code #pause
  - The enforcer reads blocks through RPC and ZMQ
    - If a block violates the added rules, it calls `invalidateblock` #pause
  - A miner using CUSF builds templates that satisfy the same added rules
    - Otherwise its own enforcer rejects the resulting block #pause
  - Nodes without the enforcer continue applying their existing rules
    - CUSF is still a soft fork: enforcing nodes accept a subset of base-valid blocks
]

== CUSF stack

#align(center)[
  #grid(
    columns: (1.05fr, auto, 1.15fr, auto, 1.1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([
      #text(size: 0.9em, weight: "bold")[BIP 300/301 enforcer] \
      #text(size: 0.62em)[checks added rules; calls `invalidateblock`]
    ], fill: bridge-fill),
    flow-bidir,
    flow-box([
      #text(size: 0.9em, weight: "bold")[Core-compatible node] \
      #text(size: 0.62em)[base validation; RPC and ZMQ interface]
    ], fill: l1-fill),
    flow-arrow,
    flow-box([
      #text(size: 0.9em, weight: "bold")[Compliant template builder] \
      #text(size: 0.62em)[avoids mining blocks its enforcer rejects]
    ], fill: miner-fill),
  )
]

#v(0.7em)

#text(size: 0.86em)[CUSF leaves the added rules outside the node's source tree. Operators running the enforcer treat those rules as consensus.]

== Fork rules

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 18pt,
    align: top,
    flow-box([
      *Fork bootstrap* \
      #text(size: 0.7em)[One-time minimum difficulty \
      New network magic, seeds, and name \
      Optional transaction replay-control byte]
    ], fill: fork-fill),
    flow-box([
      *CUSF-enforced rules* \
      #text(size: 0.7em)[BIP 300 and BIP 301 \
      Planned 400 kB block cap]
    ], fill: bridge-fill),
  )

  #v(0.8em)
  The project intends to keep the remaining L1 code close to upstream Bitcoin Core.
]

== Ledger distribution

- Ordinary pre-fork BTC UTXOs are mirrored as ECX at 1:1 #pause
- The corresponding private keys control the coins on both chains #pause
- Spending ECX does not spend BTC, once replay protection is used #pause
- The Satoshi Half-Airdrop reallocates about 550,000 ECX associated with "Patoshi" outputs #pause
- That reallocation changes only the new chain's ledger

== Braiins Hashpower and ECX

#compact[
  - Similar to BCash
  - Existing BTC delivery does not change
    - eCash is a separate chain with separate pool jobs and payouts #pause
  - Hashpower can route bought SHA-256 hashrate to a custom destination pool
    - The pool must speak Stratum V1, report `extranonce2_size >= 7`, and accept `mining.authorize` #pause
  - The ECX pool builds the templates
    - It chooses BIP 300 votes and BMM Accepts; Hashpower routes the proof of work #pause
  - Hashpower does not need to interpret BIP 300 or BIP 301
    - Under the published interface, it can mine ECX through a compatible ECX pool
]

== Fork-day

#compact[
  - ECX starts its first 2,016 blocks at minimum network difficulty (maybe)
    - The destination pool and mining firmware must accept jobs at that target #pause
  - SoloFork tested a Braiins OS miner against its L2L signet endpoint
    - It reported a BOSminer assertion when share difficulty exceeded network difficulty #pause
    - https://solofork.com/blog/bosminer-low-diff-panic
]

== Public pool activity

#compact[
  - Major pool accounts
    - No eCash-specific announcement found from AntPool, F2Pool, ViaBTC, Foundry, Braiins, SpiderPool, or Luxor as of 3 August 2026 #pause
  - SoloFork
    - Independent CKpool-based ECX solo pool
    - Uses an L2L signet endpoint for Stratum integration testing
    - Plans to switch its public endpoint to ECX mainnet at launch
    - A found block pays the miner directly, minus a 2% operator output #pause
  - LayerTwo Labs also publishes SimplePool
    - It is Stratum V1 pool software, not really a public commitment from a pool
]

== Planned sidechains

#text(size: 0.78em)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 24pt,
    [
      - *Thunder*: high-throughput payments
      - *zSide*: Zcash-style privacy
      - *BitNames*: identity and DNS
      - *BitAssets*: issued assets
    ],
    [
      - *Truthcoin*: prediction markets
      - *CoinShift*: decentralized exchange
      - *Photon*: post-quantum signatures
    ],
  )
]

== Q&A
