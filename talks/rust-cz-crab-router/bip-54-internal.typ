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
  footer: self => [Consensus Cleanup / BIP 54],
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
    = Consensus Cleanup
    #text(size: 0.62em)[BIP 54]
  ]
]

== Agenda

- Scope, history, and current status #pause
- Difficulty adjustment timestamps #pause
- Worst-case block validation #pause
- Merkle tree ambiguity #pause
- Duplicate coinbase transactions #pause
- Impact on nodes, applications, and mining pools

= Context

== Four old edge cases

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
  BIP 54 bundles four consensus fixes; it adds no new spending functionality.
]

== Why bundle them?

#compact[
  - Each issue is independent #pause
  - Every consensus deployment has a large fixed coordination and review cost #pause
  - Bundling amortizes that cost across several mature fixes #pause
  - The trade-off is atomic deployment
    - disagreement over one rule can delay all four #pause
  - The common theme is bounding or removing behavior nobody intends to use
]

== It is a soft fork

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 16pt,
    align: center + horizon,
    flow-box([*Existing rules* \
      #text(size: 0.68em)[larger valid-block set]], fill: neutral-fill),
    flow-arrow,
    flow-box([*BIP 54 rules* \
      #text(size: 0.68em)[four additional validity checks]], fill: sigop-fill),
  )

  #v(0.9em)
  Old nodes accept BIP-54-compliant blocks; upgraded nodes reject four additional cases.
]

== History

#text(size: 0.82em)[
  1. *2019* - Matt Corallo proposes the Great Consensus Cleanup #pause
  2. *2023-24* - Antoine Poinsot revisits the attacks and mitigations #pause
  3. *26 March 2025* - consolidated BIP draft published #pause
  4. *11 April 2025* - assigned BIP 54 #pause
  5. *February 2026* - activated for testing by Bitcoin Inquisition on signet #pause
  6. *22 May 2026* - specification reaches version 1.0.0 and Complete status
]

== Status today

#compact[
  - Authors: Antoine Poinsot and Matt Corallo #pause
  - BIP status: *Complete* #pause
  - Complete means the specification is finished
    - it does not mean deployed or active #pause
  - Active on Bitcoin Inquisition's signet deployment #pause
  - Bitcoin Core implementation PR is open and enables the rules only on regtest #pause
  - No mainnet activation mechanism, parameters, or date have been selected
]

= Difficulty adjustment

== Retarget periods

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 15pt,
    align: center + horizon,
    flow-box([*2016 blocks* \
      #text(size: 0.68em)[timestamps estimate elapsed time]], fill: time-fill),
    flow-arrow,
    flow-box([*New target* \
      #text(size: 0.68em)[difficulty adjusted toward two weeks]], fill: neutral-fill),
  )

  #v(0.85em)
  #text(size: 0.82em)[The calculation uses the first and last timestamps inside the period.]
]

== The boundary is omitted

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
  #text(size: 0.8em)[The first timestamp of a new period can move backward relative to the previous block.]
]

== Timewarp

#compact[
  - A majority-hashrate attacker manipulates timestamps across period boundaries #pause
  - The new period begins with a timestamp earlier than the previous period ended #pause
  - Its measured duration is therefore longer than its real duration #pause
  - The next retarget lowers difficulty too far #pause
  - Repeating this can drive difficulty to the minimum in roughly 38 days #pause
  - Consequence: arbitrarily fast blocks, accelerated subsidy issuance, and broken timelock assumptions
]

== Boundary rules

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
]

== Two fixes in one

#compact[
  - The first-period rule limits the backward jump to two hours #pause
  - That closes the repeatable timewarp mechanism #pause
  - The last-period rule prevents a negative measured period #pause
  - The latter addresses the related Murch-Zawy edge case #pause
  - Only the first and last blocks of each 2016-block period receive new constraints #pause
  - The two-hour grace period tolerates imperfect mining timestamp software
]

= Validation time

== Sigops

#compact[
  - A sigop is an occurrence of a signature-checking opcode in Bitcoin Script #pause
  - `CHECKSIG` usually represents one signature check #pause
  - `CHECKMULTISIG` can represent several #pause
  - Bitcoin already limits sigops at the block level #pause
  - Legacy Script permits pathological transactions that concentrate expensive work #pause
  - Their validation cost is far outside ordinary wallet behavior
]

== Slow blocks

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
  #text(size: 0.8em)[A miner can begin hashing the next block while competitors are still validating the previous one.]
]

== Measured worst case

#compact[
  - Demonstrated constructions take minutes to validate on modern hardware #pause
  - A 2026 measurement was about 10 minutes on a Core i5-12500H #pause
  - A comparable demonstration took about 29 minutes on an older Xeon #pause
  - The absolute worst case matters for denial of service #pause
  - The cost ratio also matters
    - a miner may profit from imposing more validation work than it spent preparing #pause
  - This creates a mining centralization incentive
]

== Per-transaction limit

#compact[
  - Every non-coinbase transaction may contain at most *2500 legacy sigops* #pause
  - Count across each input's:
    - `scriptSig`
    - spent output's `scriptPubKey`
    - P2SH `redeemScript` #pause
  - Count opcodes whether or not execution reaches them #pause
  - This is the established BIP16 counting method #pause
  - Witness-script sigops use their existing accounting and are not part of this new limit
]

== Counting rules

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

== Why 2500?

#compact[
  - It is the tightest studied limit that preserves non-pathological standard transactions #pause
  - Ordinary multisig transactions hit existing size and policy limits first #pause
  - Exceeding 2500 without exceeding transaction-size policy requires contrived scripts #pause
  - The rule targets repeated signature work rather than disabling Script features #pause
  - Estimated result: roughly 40 times lower worst-case block validation time #pause
  - It also raises preparation cost enough to remove the plausible mining advantage
]

= Merkle trees

== Transactions and inner nodes

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

  #v(1em)
  An inner-node preimage is always 32 + 32 = 64 bytes.
]

== The 64-byte ambiguity

#align(center + horizon)[
  #block(width: 82%)[
    #flow-box([
      *Exactly 64 witness-stripped bytes* \
      can be parsed as a transaction serialization \
      or as two child hashes of a Merkle node
    ], fill: merkle-fill)
  ]

  #v(0.9em)
  #text(size: 0.82em)[Bitcoin's Merkle construction does not domain-separate leaves from inner nodes.]
]

== Consequences

#compact[
  - A Merkle proof can exploit the missing distinction between leaf and inner node #pause
  - An SPV verifier can be shown an apparent transaction inclusion that is not real #pause
  - Other systems consuming Bitcoin inclusion proofs inherit the same footgun #pause
  - Related block-validation cache bugs have existed in Bitcoin Core #pause
  - Workarounds exist
    - but every proof verifier must know and implement one correctly
]

== The rule

#align(center + horizon)[
  #flow-box([
    A transaction is invalid when its witness-stripped serialization is *exactly 64 bytes*.
  ], fill: merkle-fill)

  #v(0.9em)

  #compact[
    - 63 bytes remains valid #pause
    - 65 bytes remains valid #pause
    - Existing Bitcoin Core versions neither relay nor template 64-byte transactions #pause
    - They have not appeared on-chain since 2016 #pause
    - The proposal turns an existing policy restriction into consensus
  ]
]

== The trade-off

#compact[
  - Benefit: proof verifiers no longer need special protection for this ambiguity #pause
  - Cost: a surprising discontinuity in the valid transaction-size range #pause
  - Such a transaction can only create an anyone-can-spend or provably unspendable output today #pause
  - Alternative proposals modify Merkle-proof or inner-node validation instead #pause
  - BIP 54 chooses the smallest full-node rule and removes the problematic leaf case
]

= Coinbase uniqueness

== Coinbase transactions

#compact[
  - Every block begins with one coinbase transaction #pause
  - It creates the block subsidy and collects transaction fees #pause
  - Its input does not spend an earlier output #pause
  - Pools vary its data to produce new Merkle roots and hashing work #pause
  - Like every transaction, it has a txid #pause
  - Historically, some coinbase transactions were duplicated
]

== BIP30 and BIP34

#compact[
  - *BIP30*: do not overwrite still-unspent outputs from an older transaction with the same txid #pause
  - Two historical blocks are explicit exceptions #pause
  - *BIP34*: place the block height in the coinbase `scriptSig` #pause
  - This made modern coinbase transactions practically unique #pause
  - Bitcoin Core can therefore skip most explicit BIP30 checks #pause
  - But BIP34 does not prove uniqueness forever
]

== The future collision window

#compact[
  - Early pre-BIP34 coinbases sometimes begin with bytes that can later encode a block height #pause
  - At specific future heights, a new coinbase could reproduce an old txid #pause
  - The earliest such height is *1,983,702* #pause
  - Nodes would need to resume BIP30 validation before then #pause
  - That adds validation state and complicates alternative node designs such as Utreexo #pause
  - BIP 54 makes future coinbase uniqueness explicit instead
]

== Coinbase rule

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

  #v(0.9em)
  #text(size: 0.82em)[Together these make the coinbase valid at height `N`, but not at any earlier height.]
]

== Why height minus one?

#compact[
  - Bitcoin locktime records the last height at which a transaction is still locked #pause
  - A transaction with `nLockTime = N - 1` is final in block `N` #pause
  - It could not have been valid in any earlier block #pause
  - A non-final `nSequence` makes the locktime effective #pause
  - The height becomes directly readable from a fixed transaction field #pause
  - Therefore a post-activation coinbase cannot duplicate a historical one
]

= Operational impact

== Validity changes

#text(size: 0.75em)[
  #table(
    columns: (1.2fr, 1.45fr, 1.15fr),
    align: left,
    [*Area*], [*New invalid case*], [*Normal activity*],
    [Difficulty], [Malformed period-boundary timestamp], [Unchanged],
    [Script], [Transaction above 2500 legacy sigops], [Unaffected],
    [Serialization], [Exactly 64 stripped bytes], [Unaffected],
    [Coinbase], [Wrong locktime or final sequence], [Pool update required],
  )
]

== Full nodes

#compact[
  - Upgraded nodes enforce all four rules after activation #pause
  - Unupgraded nodes still accept compliant blocks #pause
  - They do not independently reject a violating block #pause
  - The sigops rule bounds adversarial validation work #pause
  - The Merkle rule simplifies assumptions for proof-verifying applications #pause
  - The coinbase rule lets implementations permanently avoid future BIP30 checks
]

== Wallets and applications

#compact[
  - Ordinary wallets do not need a migration #pause
  - Non-pathological standard transactions remain valid #pause
  - Script authors should avoid pathological legacy constructions above 2500 sigops #pause
  - Transaction generators must not produce exactly 64 witness-stripped bytes #pause
  - SPV, bridge, and sidechain software benefits from removing the Merkle ambiguity #pause
  - No address format, key, signature algorithm, or transaction relay protocol changes
]

== Mining pools

#compact[
  - Use `curtime` or `mintime` from `getblocktemplate` #pause
  - Exclude transactions violating the new consensus rules #pause
  - Construct coinbase with:
    - `nLockTime = block height - 1`
    - input `nSequence != 0xffffffff` #pause
  - The extranonce remains available in the coinbase `scriptSig` #pause
  - Pool software, not the ASIC, normally constructs these fields
]

== Stratum and hashing

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([*Pool template* \
      #text(size: 0.65em)[BIP-54-compliant coinbase]], fill: coinbase-fill),
    flow-arrow,
    flow-box([*Stratum job* \
      #text(size: 0.65em)[same job structure]], fill: neutral-fill),
    flow-arrow,
    flow-box([*ASIC* \
      #text(size: 0.65em)[same SHA-256d work]], fill: sigop-fill),
  )

  #v(0.85em)
  No Stratum protocol or proof-of-work algorithm change is required.
]

== Forward compatibility already present

#compact[
  - Bitcoin Core 29.0+ templates comply with the timestamp restriction #pause
  - Bitcoin Core 30.0+ policy excludes transactions above the new sigops limit #pause
  - Bitcoin Core 0.16.1+ excludes 64-byte stripped transactions from relay and templates #pause
  - The remaining practical integration point is pool coinbase construction #pause
  - These policies reduce activation risk but do not activate BIP 54
]

== Deployment remains separate

#compact[
  - BIP 54 specifies post-activation validity rules #pause
  - It deliberately does not select how or when mainnet activates them #pause
  - The Bitcoin Core implementation under review contains no mainnet activation #pause
  - Activation requires a separate coordination decision #pause
  - Until then, mainnet consensus is unchanged
]

== Takeaways

#compact[
  - BIP 54 is a four-part consensus hardening soft fork #pause
  - It limits timewarp, pathological legacy sigops, and Merkle ambiguity #pause
  - It also makes future coinbase uniqueness explicit #pause
  - Ordinary transactions, wallets, Stratum jobs, and SHA-256d mining remain unchanged #pause
  - Pools must update coinbase locktime and sequence before activation #pause
  - The specification is complete; mainnet deployment is not decided
]

== Q&A
