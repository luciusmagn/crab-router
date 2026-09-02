#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let page-fill = rgb("#f8f5ee")
#let time-fill = rgb("#dce8f2")
#let sigop-fill = rgb("#dcebdc")
#let merkle-fill = rgb("#eee7c8")
#let coinbase-fill = rgb("#f1ddd7")
#let neutral-fill = rgb("#e7e0ed")
#let line-color = rgb("#89939a")

#let flow-box(body, fill: time-fill) = block(
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

#let flow-down = align(center)[
  #text(size: 1.2em, weight: "bold")[#sym.arrow.b]
]

#let compact(body) = text(size: 0.82em)[#body]

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [BIP-54: Consensus Cleanup],
  config-info(
    title: [Consensus Cleanup],
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
    = BIP-54: Consensus Cleanup
    #text(size: 0.62em)[Random bullshit go]
  ]
]

== Agenda

- Content and history #pause
- Timewarp #pause
- Legacy sigops #pause
- Merkle trees #pause
- Coinbase uniqueness #pause
- Mining impact

= Context

== Four main changes

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr, 1fr),
    column-gutter: 10pt,
    align: top,
    flow-box([*Timewarp* \
      #text(size: 0.65em)[difficulty can be forced down]], fill: time-fill),
    flow-box([*Legacy sigops* \
      #text(size: 0.65em)[pathological validation cost]], fill: sigop-fill),
    flow-box([*64-byte txs* \
      #text(size: 0.65em)[Merkle leaf/node ambiguity]], fill: merkle-fill),
    flow-box([*Duplicate txids* \
      #text(size: 0.65em)[future BIP30 problem]], fill: coinbase-fill),
  )

  #v(0.95em)
  A lot of unrelated stuff in one bip whew  
]

== History and status

#text(size: 0.8em)[
  1. *2019* - Matt Corallo proposes the Great Consensus Cleanup #pause
  2. *2023-24* - Antoine Poinsot reworks the proposal #pause
  3. *26 March 2025* - consolidated draft published #pause
  4. *11 April 2025* - assigned BIP 54 #pause
  5. *February 2026* - Bitcoin Inquisition activates it on signet #pause
  6. *22 May 2026* - version 1.0.0, status Complete #pause
  7. *Today* - Bitcoin Core PR open for regtest; mainnet activation unselected
]

= Difficulty adjustment

== Retarget gap

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 8pt,
    align: center + horizon,
    flow-box([*Previous period* \
      #text(size: 0.65em)[last block: `N - 1`]], fill: neutral-fill),
    flow-arrow,
    flow-box([*Unmeasured gap* \
      #text(size: 0.65em)[between `N - 1` and `N`]], fill: coinbase-fill),
    flow-arrow,
    flow-box([*New period* \
      #text(size: 0.65em)[first block: `N`]], fill: time-fill),
  )

  #v(0.8em)
  #compact[
    Difficulty retargets every 2016 blocks from the period's first and last timestamps. \
    The boundary interval drops out of the calculation.
  ]
]

== Timewarp

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 8pt,
    align: center + horizon,
    flow-box([*Backdate first block*], fill: time-fill),
    flow-arrow,
    flow-box([*Inflate measured duration*], fill: neutral-fill),
    flow-arrow,
    flow-box([*Lower difficulty*], fill: coinbase-fill),
  )

  #v(0.85em)
  #compact[
    A majority-hashrate attacker repeats this at each retarget. \
    Difficulty reaches the minimum in roughly 38 days; blocks then accelerate without bound.
  ]
]

== Timestamp constraints

#align(center + horizon)[
  #block(width: 88%)[
    #flow-box([
      *First block of period* \
      $T_N >= T_(N - 1) - 7200$
    ], fill: time-fill)

    #v(0.6em)

    #flow-box([
      *Last block of period* \
      $T_N >= T_(N - 2015)$
    ], fill: time-fill)
  ]

  #v(0.7em)
  #text(size: 0.76em)[The first rule caps the timewarp at two hours. The second prevents a negative period (Murch-Zawy).]
]

= Validation time

== Legacy sigops

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([*Prepare UTXOs*], fill: neutral-fill),
    flow-arrow,
    flow-box([*Mine pathological transactions*], fill: sigop-fill),
    flow-arrow,
    flow-box([*Competitors validate slowly*], fill: coinbase-fill),
  )

  #v(0.8em)
  #compact[
    A sigop is a `CHECKSIG` or `CHECKMULTISIG` operation in Bitcoin Script. \
    Legacy Script can concentrate expensive checks inside a few transactions.
  ]
]

== Validation cost

#compact[
  - About 10 minutes on a Core i5-12500H in a 2026 test #pause
  - About 29 minutes in a comparable test on an older Xeon #pause
  - The attacker prepares suitable UTXOs in earlier blocks #pause
  - A miner starts the next block while competitors validate the slow block #pause
  - Under some conditions, the head start can cover the preparation cost
]

== 2500 per transaction

#text(size: 0.78em)[
  #table(
    columns: (1.25fr, 1fr),
    align: left,
    [*Opcode form*], [*BIP 54 sigops*],
    [`CHECKSIG` / `CHECKSIGVERIFY`], [1],
    [`OP_1`...`OP_16` then `CHECKMULTISIG`], [1...16],
    [Other `CHECKMULTISIG` forms], [20],
    [Transaction total], [0...2500 valid; >2500 invalid],
  )
]

#compact[
  Count each input's `scriptSig`, spent `scriptPubKey`, and P2SH `redeemScript`. \
  This BIP16-style count includes unreachable opcodes. \
  The limit cuts worst-case validation time by roughly 40 times.
]

= Merkle trees

== The 64-byte ambiguity

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 20pt,
    align: top,
    flow-box([
      *Transaction leaf* \
      #text(size: 0.68em)[`txid = SHA256d(serialized_tx)`]
    ], fill: merkle-fill),
    flow-box([
      *Inner node* \
      #text(size: 0.68em)[`SHA256d(left_hash || right_hash)`]
    ], fill: neutral-fill),
  )

  #v(0.9em)
  #compact[
    An inner-node preimage is 32 + 32 = 64 bytes. \
    A 64-byte witness-stripped transaction can occupy either interpretation.
  ]
]

== Merkle proof rule

#compact[
  - Ambiguous leaves can forge an apparent SPV inclusion with less work than a SHA256 collision #pause
  - BIP 54 makes transactions with exactly 64 witness-stripped bytes invalid #pause
  - Current Bitcoin Core policy already excludes them from relay and block templates #pause
  - The last one appeared on-chain in 2016 #pause
  - Present-day 64-byte transactions create anyone-can-spend or provably unspendable outputs
]

= Coinbase uniqueness

== BIP30 and BIP34

#compact[
  - Coinbase transactions create subsidy and fees and carry a txid #pause
  - *BIP30* protects unspent outputs from a duplicate txid #pause
  - Two historical blocks remain explicit exceptions #pause
  - *BIP34* encodes block height in the coinbase `scriptSig` #pause
  - Bitcoin Core uses BIP34 to skip most explicit BIP30 checks
]

== Future duplicate height

#compact[
  - Some pre-BIP34 coinbases begin with bytes that encode future heights #pause
  - The earliest duplicate candidate occurs at height *1,983,702* #pause
  - Explicit BIP30 validation would resume before that height #pause
  - BIP30 needs the UTXO set and complicates designs such as Utreexo #pause
  - A height-bound coinbase provides permanent uniqueness
]

== Height-bound coinbase

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 18pt,
    align: top,
    flow-box([
      *`nLockTime`* \
      $N - 1$
    ], fill: coinbase-fill),
    flow-box([
      *input `nSequence`* \
      must not equal `0xffffffff`
    ], fill: coinbase-fill),
  )

  #v(0.8em)
  #compact[
    `nSequence` activates the locktime. \
    `nLockTime = N - 1` becomes final at height `N`, binding the transaction to that block height.
  ]
]

= Operational impact

== Nodes and applications

#compact[
  - Upgraded nodes enforce all four rules after activation #pause
  - Standard wallet transactions fit the new limits #pause
  - Script tooling enforces the 2500 legacy-sigop ceiling #pause
  - Transaction builders pad a 64-byte stripped transaction #pause
  - SPV, bridge, and sidechain code gets unambiguous Merkle proofs #pause
  - Utreexo implementations can skip future BIP30 validation
]

== Mining pools

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([*Pool template* \
      #text(size: 0.65em)[BIP-54-compliant coinbase]], fill: coinbase-fill),
    flow-arrow,
    flow-box([*Stratum job* \
      #text(size: 0.65em)[distributes template data]], fill: neutral-fill),
    flow-arrow,
    flow-box([*ASIC* \
      #text(size: 0.65em)[searches SHA-256d headers]], fill: sigop-fill),
  )

  #v(0.7em)
  #text(size: 0.76em)[
    The pool sets `nLockTime = block height - 1` and `nSequence != 0xffffffff`. \
    It uses `curtime` or `mintime` from `getblocktemplate`. \
    Pools continue rolling extranonce in `scriptSig`.
  ]
]

== Deployment readiness

#compact[
  - Bitcoin Core 29.0+ templates use compatible timestamps #pause
  - Bitcoin Core 30.0+ policy enforces the 2500-sigop limit #pause
  - Bitcoin Core 0.16.1+ policy excludes 64-byte stripped transactions #pause
  - Pool software adds the coinbase locktime and sequence fields #pause
  - Mainnet activation mechanism and parameters remain unselected
]

== Takeaways

#compact[
  - BIP 54 packages four consensus fixes #pause
  - Boundary timestamps close timewarp #pause
  - Per-transaction sigops bound validation cost #pause
  - A 64-byte ban removes the Merkle ambiguity #pause
  - Coinbase locktime guarantees unique future txids #pause
  - Pools implement the only mining-specific change
]

== Q&A
