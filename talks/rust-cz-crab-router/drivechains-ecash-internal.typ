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
- Paul Sztorc's planned eCash fork

= Drivechains

== Three separate mechanisms

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

  #v(1em)
  They compose, but they solve different problems.
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

== Control moves to future blocks

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
  BIP 300 removes fixed keyholders. It gives withdrawal control to whoever builds enough future block templates.
]

= BIP 300

== L1 state

- Up to 256 numbered sidechain slots #pause
- A sidechain list records each active slot and its current treasury outpoint #pause
- A withdrawal list records candidate bundle hashes, scores, and expiry #pause
- Bitcoin nodes enforcing BIP 300 track this state #pause
- They do not validate the sidechain's transactions or ledger

== Six messages

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

== The delay is the defense

#compact[
  - A withdrawal hash must remain visible while its score grows
    - One block cannot instantly drain the treasury #pause
  - L1 does not verify sidechain state or a fraud proof
    - Enough approving templates can authorize an invalid withdrawal #pause
  - Miners may abstain, downvote, or censor the final M6
    - Peg-out liveness is not guaranteed #pause
  - Monitoring can expose a bad bundle
    - Detection does not cryptographically stop it
]

== Bridge, not block production

- BIP 300 defines sidechain slots and the two-way peg #pause
- It does not select or order sidechain blocks #pause
- It does not require one particular sidechain consensus #pause
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
  1. A sidechain node constructs a candidate block and its hash, `h*` #pause
  2. The bidder broadcasts an L1 transaction naming the slot, `h*`, and previous L1 block #pause
  3. Its transaction fee is the bid to the mainchain miner #pause
  4. The miner includes at most one matching BMM Accept per slot in the coinbase #pause
  5. Sidechain nodes validate the candidate and either connect it or reject it
]

== Blindness boundary

- Mainchain miner sees the sidechain slot, `h*`, and L1 fee #pause
- It need not run the sidechain node or inspect sidechain transactions #pause
- Sidechain nodes still apply every sidechain validation rule #pause
- An invalid winning candidate buys an empty round; it does not become valid state #pause
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
  BMM anchors the L2 block sequence. It does not validate or secure the peg-out bundle.
]

== Failure boundaries

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
      #text(size: 0.7em)[existing network continues]
    ], fill: l1-fill),
    flow-arrow,
    flow-box([
      *eCash / ECX* \
      #text(size: 0.7em)[new network and rules]
    ], fill: fork-fill),
  )
]

#v(0.65em)

- Advertised target: BTC block *~963,648* #pause
- Current estimate: *22 August 2026* #pause
- Planned SHA-256d chain; Bitcoin itself is unaffected #pause
- This is not Chaumian eCash, Cashu, or the existing XEC network

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
      Project-described 400 kB block cap]
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

== Difficulty reset

#text(size: 0.84em)[
  - The fork inherits Bitcoin's history, but not its hashrate
    - Keeping Bitcoin's difficulty would leave the new chain nearly stalled #pause
  - 963,648 is exactly $478 times 2,016$
    - The target is a Bitcoin difficulty-period boundary #pause
  - eCash plans one period at minimum difficulty
    - Early blocks can arrive quickly with little proof of work #pause
  - Normal retargeting resumes after 2,016 eCash blocks
    - Security and block cadence seek a new equilibrium
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

#text(size: 0.86em)[CUSF leaves the rules outside Bitcoin Core's source tree. They are still consensus rules for nodes that run the enforcer.]

== Advertised sidechains

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

#v(0.7em)

This is the project's current test and launch set; implementation maturity varies.

= Assessment

== Trust and scope

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 14pt,
    align: top,
    flow-box([
      *BIP 300* \
      #text(size: 0.68em)[Removes a fixed federation, but replaces it with delayed hashrate custody]
    ], fill: bridge-fill),
    flow-box([
      *BIP 301* \
      #text(size: 0.68em)[Lets miners sell L2 commitments without validating L2 state]
    ], fill: miner-fill),
    flow-box([
      *eCash* \
      #text(size: 0.68em)[Runs the experiment on a separate asset and security budget]
    ], fill: fork-fill),
  )
]

== Q&A
