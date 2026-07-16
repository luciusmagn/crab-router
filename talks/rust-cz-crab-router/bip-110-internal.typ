#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let bg = rgb("#f8f5ee")

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [BIP-110],
  config-info(
    title: [BIP-110],
    author: [Lukáš Hozda],
    institution: [Braiins],
  ),
  config-page(fill: bg),
  config-colors(neutral-lightest: bg),
)

#title-slide()[
  #align(center + horizon)[
    = BIP-110
  ]
]

= Overview

== Metadata

#table(
  columns: (auto, auto),
  align: left,
  [*Field*], [*Value*],
  [BIP], [110],
  [Title], [Reduced Data Temporary Softfork],
  [Layer], [Consensus (soft fork)],
  [Type / status], [Specification / Draft],
  [Author], [Dathon Ohm],
  [Assigned], [2025-12-03],
  [Snapshot date], [2026-06-19],
)

== What BIP-110 is

- A proposed temporary soft fork
- Target: large arbitrary-data patterns in Bitcoin transactions
- Duration: 52,416 active blocks, roughly one year
- Existing UTXOs created before activation are exempt
- After expiry, the extra restrictions stop applying

== Why it exists

- Supporters see inscriptions and similar protocols as abusive data storage
- Their concern is long-term cost for node operators
- The proposal tries to push Bitcoin back toward monetary use
- It is also meant to send a social signal
- The BIP does not claim to make all arbitrary data impossible

= Context

== Consensus vs relay policy

- Relay policy decides what a node accepts into its mempool and forwards
- Consensus decides whether a block is valid
- BIP-110 is a consensus proposal
- During the active window, enforcing nodes reject blocks with violating transactions
- Non-upgraded nodes validate those same blocks under the old rules

== Outputs, pushes, witness

#text(size: 0.8em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Term*], [*Meaning here*],
    [`scriptPubKey`], [The output locking script. If the output is unspent, it lives in the UTXO set.],
    [`OP_RETURN`], [A provably unspendable output type. BIP-110 gives it a separate 83-byte allowance.],
    [`OP_PUSHDATA\*`], [Script opcodes that push byte strings onto the stack. BIP-110 caps their payloads at 256 bytes.],
    [Witness data], [SegWit data area for signatures, scripts, and script arguments. It is discounted, which made it attractive for inscriptions.],
  )
]

== Taproot terms

#text(size: 0.8em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Term*], [*Meaning here*],
    [Key path], [Spend a Taproot output with a signature. No script is revealed.],
    [Script path], [Spend a Taproot output by revealing one script alternative.],
    [Tapleaf], [One script-path alternative inside Taproot.],
    [Taptree], [The Merkle tree of Tapleaves committed by the Taproot output.],
    [Control block], [Proof that the revealed Tapleaf belongs to the Taptree. Size is `33 + 32 * depth`.],
    [Annex], [Optional Taproot witness element reserved for future use. Currently undefined.],
  )
]

== Tapscript hooks

- Tapscript is the script language used for Taproot script-path spends
- `OP_SUCCESS\*` opcodes are reserved upgrade hooks
- Today, encountering `OP_SUCCESS\*` makes validation succeed
- `OP_IF` / `OP_NOTIF` are conditional branches
- BIP-110 restricts these because they are useful places to hide skipped payloads

== Proposed changes

#text(size: 0.82em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Area*], [*Temporary restriction*],
    [`scriptPubKey`], [New output scripts over 34 bytes invalid, except `OP_RETURN` up to 83 bytes],
    [`OP_PUSHDATA\*`], [Payloads over 256 bytes invalid, except BIP-16 redeemScript push],
    [Witness arguments], [Script argument witness items over 256 bytes invalid],
    [Undefined witness / Tapleaf versions], [Spending them invalid],
    [Taproot annex], [Witness stacks with an annex invalid],
    [Taproot control block], [Control blocks over 257 bytes invalid],
    [Tapscript], [`OP_SUCCESS\*` invalid; executed `OP_IF` / `OP_NOTIF` invalid],
  )
]

= Effects

== Main targets

- Large data in spendable output scripts
- Large contiguous script pushes
- Large script argument witness items
- Undefined witness and Tapleaf version spends
- Taproot annex usage
- Very deep Taproot script trees
- Tapscripts using `OP_SUCCESS\*`, executed `OP_IF`, or executed `OP_NOTIF`

== Practical reading

- The proposal blocks common, visible data-carrier patterns
- It does not block every possible encoding
- It makes some forms of data embedding more fragmented or expensive
- It also restricts some future-upgrade surfaces for one year
- That tradeoff is the center of the technical objection

== Wallet and contract impact

- Common payment outputs fit inside the limits
- Taproot key-path spends are not the target
- Some Miniscript-generated Tapleaves may need adjustment
- Large Taptrees may need shallower constructions
- Pre-signed Taproot transactions need special care if they must confirm and spend during the active window

== Grandfathering

- Inputs spending UTXOs created before activation are exempt
- New outputs created after activation are checked
- Hidden Taproot script paths matter because they are revealed only when spent
- After expiry, UTXOs of all heights are unrestricted again
- The rule is height-sensitive, not only transaction-format-sensitive

= Activation

== Deployment parameters

#table(
  columns: (auto, auto),
  align: left,
  [*Parameter*], [*Value*],
  [Deployment name], [`reduced_data`],
  [Version bit], [4],
  [Start time], [2025-12-01 00:00:00 UTC],
  [Timeout], [`NO_TIMEOUT`],
  [Max activation height], [965,664],
  [Active duration], [52,416 blocks],
  [Threshold], [1,109 / 2,016 blocks (55%)],
)

== State machine

1. `DEFINED`: before start time
2. `STARTED`: miners may signal bit 4
3. `LOCKED_IN`: threshold reached, or forced no later than height 963,648
4. `ACTIVE`: one retarget period after lock-in; new rules enforced
5. `EXPIRED`: activation height plus 52,416 blocks; new rules stop applying

== Important dates and heights

#text(size: 0.86em)[
  #table(
    columns: (auto, auto, 1fr),
    align: left,
    [*When*], [*Height*], [*Meaning*],
    [2025-12-01 00:00 UTC], [n/a], [Start time],
    [2025-12-03], [n/a], [BIP assigned],
    [~Aug 2026], [961,632-963,647], [Mandatory signaling window],
    [~Aug 2026], [963,648], [Latest lock-in boundary],
    [~Sep 2026], [965,664], [Latest activation height],
    [~1 year after activation], [activation + 52,416], [Expiry],
  )
]

== Two activation paths

- Early path: any retarget period reaches 1,109 signaling blocks
- Mandatory path: blocks 961,632 through 963,647 must signal bit 4
- Lock-in to activation is one retarget period, about two weeks
- If activation is at 965,664, expiry is at 1,018,080
- Calendar dates are estimates; heights are the exact boundaries

== What is unusual

#text(size: 0.84em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Standard BIP-9*], [*BIP-110*],
    [95% threshold], [55% threshold],
    [Can time out into `FAILED`], [`NO_TIMEOUT`; no normal failed state],
    [No mandatory signaling], [Mandatory signaling before maximum activation],
    [`ACTIVE` is terminal], [`ACTIVE` later becomes `EXPIRED`],
    [Permanent once active], [Temporary: 52,416 active blocks],
  )
]

== Compared with prior activations

#text(size: 0.88em)[
  #table(
    columns: (auto, auto, auto, auto),
    align: left,
    [], [*SegWit*], [*Taproot*], [*BIP-110*],
    [Threshold], [95%], [90%], [55%],
    [Mechanism], [BIP9 + BIP91 pressure], [Speedy Trial], [Modified BIP9 / BIP8-style forcing],
    [Miner veto], [Initially yes], [Yes], [No, after mandatory window],
    [Duration], [Permanent], [Permanent], [Temporary],
  )
]

= Sentiment

== Supporter frame

- Bitcoin is money, not data storage
- Data embedding imposes costs on node operators
- A temporary restriction buys time
- Consensus can express a social boundary
- Better to resist now than let the pattern become normal

== Opponent frame

- Bitcoin should validate rules, not transaction purpose
- Fee-paying valid transactions should remain neutral
- Data can move into other encodings anyway
- Temporary restrictions still create precedent
- A contentious UASF risks splitting social and economic consensus

== Public supporters

#text(size: 0.8em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Person / project*], [*Public signal*],
    [Dathon Ohm], [BIP-110 author],
    [Luke Dashjr], [Original draft/advice credit; Bitcoin Knots maintainer],
    [Bitcoin Knots], [Ships RDTS / BIP-110 support],
    [Léo Haf], [Contributor to the Knots implementation],
    [Bitcoin Mechanic], [Publicly aligned with the pro-BIP-110 / OCEAN / Knots camp],
    [hodlonaut], [Published pro-BIP-110 / anti-Core-capture essays linked from bip110.org],
    [Matthew Kratter / Bitcoin University], [Repeated public advocacy and run-BIP-110 guides],
  )
]

== Public opponents

#text(size: 0.78em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Person / group*], [*Public signal*],
    [Jameson Lopp], [Published a long critique calling BIP-110 reckless and likely to fail],
    [Peter Todd], [Argued the activation path risks two coins and data remains publishable],
    [Adam Back], [Warned about downgrade, user-space breakage, and minority-fork risk],
    [Wang Chun / F2Pool], [Publicly rejected BIP-110 signaling],
    [Antoine Riard], [Rejected the legal / coercion rationale on the bitcoin-dev thread],
    [Erik Aronesty], [Rejected the legal-liability framing and emphasized uncensorability],
    [Taproot Wizards / Udi Wertheimer], [Naturally opposed as inscription-oriented builders],
  )
]

== Companies and projects

#text(size: 0.78em)[
  #table(
    columns: (auto, auto, 1fr),
    align: left,
    [*Entity*], [*Read*], [*Caveat*],
    [Bitcoin Knots], [Supportive], [Ships RDTS / BIP-110 support],
    [bip110.org], [Supportive], [Campaign site, not a neutral standards body],
    [Barefoot Mining], [Supportive], [Produced a signaling block via Ocean infrastructure],
    [F2Pool], [Opposed], [Cofounder Wang Chun publicly rejected signaling],
    [Bitcoin Core contributors], [Directionally opposed], [Relay-policy statement conflicts with BIP-110 philosophy; not a formal BIP vote],
  )
]

== No verified public stance

- Major exchanges: Coinbase, Binance, Kraken
- Hardware-wallet vendors: Ledger, Trezor
- Most wallet companies
- Most public Bitcoin treasury companies
- Most payment apps and custodians
- Most mining pools

