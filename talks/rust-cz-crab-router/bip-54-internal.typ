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
      Every 2016 blocks, difficulty gets recalculated from the timestamps of the first and last block in the period. \
      The gap between the last block of one period and the first block of the next isn't measured.
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
      A miner with most of the hashrate can do this at every retarget. \
      Difficulty bottoms out in about 38 days, and from there the attacker can mine as fast as it wants.
  ]
]

== Why it's bad

#compact[
  - Subsidy is paid per block, so faster blocks mean the remaining coins get mined way ahead of schedule #pause
  - Every node in the network has to download and validate the block storm #pause
  - And with almost no work behind the chain, rewriting history gets cheap too
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
  #text(size: 0.76em)[The first rule allows at most two hours of backdating per retarget, which is what caps timewarp. The second rule keeps the period from having a negative length (Murch-Zawy).]
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
      flow-box([*Mine a block full of slow transactions*], fill: sigop-fill),
    flow-arrow,
    flow-box([*Competitors validate slowly*], fill: coinbase-fill),
  )

  #v(0.8em)
  #compact[
    A sigop is a `CHECKSIG` or `CHECKMULTISIG` operation in Bitcoin Script. \
      Legacy Script lets a few transactions carry a huge number of these checks.
  ]
]

== Validation cost

#compact[
  - About 10 minutes on a Core i5-12500H in a 2026 test #pause
  - About 29 minutes in a comparable test on an older Xeon #pause
    - The attacker sets up the UTXOs it needs in earlier blocks #pause
    - While everyone else is still validating the slow block, the attacker starts mining the next one #pause
    - If the head start is worth more than the setup cost, the attack pays for itself
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
    Count sigops in each input's `scriptSig`, the output script it spends, and any P2SH `redeemScript`. \
    Like BIP 16, this counts even code that can never run. \
    The limit makes the worst-case block about 40 times faster to validate.
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
      An inner node is the hash of two 32-byte hashes: 64 bytes in, 32 out. \
      A transaction with its witness stripped can also be exactly 64 bytes, \
      so the same blob can be read as either one.
  ]
]

== Why it's bad

#compact[
  - Light wallets don't see whole blocks, they trust merkle proofs #pause
  - An attacker can craft a proof that shows a transaction in a block that never contained it #pause
  - Anyone who accepts proofs can be fooled: SPV wallets, exchanges, bridges #pause
  - And it costs far less work than a real SHA256 attack
]

== Merkle proof rule

#compact[
    - BIP 54 bans transactions that are exactly 64 bytes once the witness is stripped #pause
    - Bitcoin Core already refuses to relay them or put them in block templates #pause
    - The last one hit the chain in 2016 #pause
    - A 64-byte transaction these days is either anyone-can-spend or can't be spent at all
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
    - Some pre-BIP34 coinbases start with bytes that happen to encode a future block height #pause
    - The first possible duplicate lands at height *1,983,702* #pause
    - Full BIP30 checking has to come back before then #pause
    - BIP30 needs the whole UTXO set, which gets in the way of things like Utreexo #pause
    - Tying each coinbase to its own block height kills duplicates for good
]

== Why it's bad

#compact[
  - A txid is a transaction's identity: every outpoint and UTXO entry is keyed by it #pause
  - Two different transactions with the same txid can't be told apart by the chain #pause
  - A duplicate coinbase would fight over the same outpoints as the original #pause
  - Spending those outputs becomes ambiguous, and that kind of ambiguity is how chains split
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
      `nSequence` is what switches the locktime on. \
      With `nLockTime = N - 1`, the transaction only becomes valid at height `N`, \
      so the coinbase fits in exactly one block: its own.
  ]
]

= Operational impact

== Nodes and applications

#compact[
  - Upgraded nodes enforce all four rules after activation #pause
  - Standard wallet transactions fit the new limits #pause
  - Script tooling enforces the 2500 legacy-sigop ceiling #pause
    - Wallets and transaction builders should pad a transaction that would come out to exactly 64 bytes #pause
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
      Pool software sets `nLockTime` to one below the block height, with any `nSequence` other than `0xffffffff`. \
      Take the block timestamp from `curtime` or `mintime` in `getblocktemplate`. \
      Everything else, like rolling the extranonce, stays as it is.
  ]
]

== Deployment readiness

#compact[
  - Bitcoin Core 29.0+ templates use compatible timestamps #pause
  - Bitcoin Core 30.0+ policy enforces the 2500-sigop limit #pause
  - Bitcoin Core 0.16.1+ policy excludes 64-byte stripped transactions #pause
  - Pool software adds the coinbase locktime and sequence fields #pause
    - Nobody has picked how or when mainnet activation happens yet
]

== Takeaways

#compact[
    - Four fixes in one BIP #pause
    - The timestamp rules close the timewarp hole #pause
    - The sigop limit keeps the worst-case block cheap to validate #pause
    - Banning 64-byte transactions removes the Merkle ambiguity #pause
    - The coinbase locktime makes duplicate txids impossible #pause
    - Pools only need to change the coinbase
]

== Q&A
