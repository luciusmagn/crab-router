#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let bg = rgb("#f8f5ee")

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [BIP-110: proposed changes and dates],
  config-info(
    title: [BIP-110: proposed changes and dates],
    author: [Lukáš Hozda],
    institution: [Braiins],
  ),
  config-page(fill: bg),
  config-colors(neutral-lightest: bg),
)

#title-slide()[
  #align(center + horizon)[
    = BIP-110
    Proposed changes and dates
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
  [Snapshot date], [2026-05-26],
)

== Summary

- BIP-110 proposes temporary consensus checks against several large-data transaction patterns
- The checks apply during an active window of 52,416 blocks, roughly one year
- Inputs spending UTXOs created before activation are exempt
- After expiry, the added restrictions stop applying
- This deck describes the proposal, not whether it should activate

== Proposed checks

#text(size: 0.88em)[
  #table(
    columns: (auto, 1fr),
    align: left,
    [*Object*], [*Restriction while active*],
    [`scriptPubKey`], [New output scripts over 34 bytes invalid, except `OP_RETURN` up to 83 bytes],
    [`OP_PUSHDATA\*`], [Payloads over 256 bytes invalid, except BIP-16 redeemScript push],
    [Script argument witness items], [Items over 256 bytes invalid],
    [Undefined witness / Tapleaf versions], [Spending them invalid],
    [Taproot annex], [Witness stacks with an annex invalid],
    [Taproot control block], [Blocks over 257 bytes invalid],
    [Tapscript opcodes], [`OP_SUCCESS\*` invalid; executed `OP_IF` / `OP_NOTIF` invalid],
  )
]

= Technical Context

== Consensus rule, not relay policy

- Relay policy controls mempool acceptance and transaction forwarding
- Consensus controls whether a block is valid
- BIP-110 is a consensus proposal
- If active, enforcing nodes reject blocks containing violating transactions
- Non-upgraded nodes still validate those blocks using pre-BIP-110 rules

== Outputs and scriptPubKeys

- A transaction output contains an amount and a `scriptPubKey`
- The `scriptPubKey` locks the output to a spending condition
- Unspent outputs live in the UTXO set
- Common output forms already fit within 34 bytes:
  P2PKH 25, P2SH 23, P2WPKH 22, P2WSH 34, P2TR 34
- `OP_RETURN` is provably unspendable and gets a separate 83-byte allowance

== Pushes, scripts, and witness

- Script push opcodes place byte strings on the execution stack
- `OP_PUSHDATA1`, `OP_PUSHDATA2`, and `OP_PUSHDATA4` support explicitly sized payloads
- SegWit witness data carries signatures, scripts, and script arguments outside the legacy txid
- BIP-110 caps large contiguous pushes and script argument witness items at 256 bytes
- It does not simply cap all scripts at 256 bytes

== Taproot objects

- A Taproot output can be spent by key path or script path
- Script-path spending reveals one Tapleaf script and a control block
- The control block proves that the revealed leaf is in the committed Taptree
- Control block size is `33 + 32 * Merkle-depth`
- The annex is a currently undefined optional Taproot witness element

== Tapscript hooks

- BIP-342 defines Tapscript for Taproot script-path spends
- `OP_SUCCESSx` opcodes are reserved upgrade hooks that currently make validation succeed
- `OP_IF` and `OP_NOTIF` provide conditional branching
- BIP-110 temporarily restricts both surfaces
- This is one reason the BIP is temporary: the rules constrain future upgrade mechanisms

= Proposed Rules

== Rule 1: output scripts

- New output `scriptPubKey`s over 34 bytes are invalid
- Exception: `OP_RETURN` outputs may be up to 83 bytes
- Standard payment output forms fit within the limit
- Large spend conditions can still be committed by hash or Taproot output key
- The direct target is large spendable output scripts

== Rule 2: large data chunks

- `OP_PUSHDATA\*` payloads over 256 bytes are invalid
- Script argument witness items over 256 bytes are invalid
- The BIP-16 redeemScript push in P2SH scriptSigs is exempt
- Revealed witness scripts and Tapleaf scripts are not script argument witness items
- Their executed pushes are still subject to the push-size rule

== Rule 3: undefined versions

- Spending undefined witness versions is invalid
- Spending undefined Tapleaf versions is invalid
- Defined versions remain valid: SegWit v0, Taproot, and P2A as named by the BIP
- Creating outputs with undefined witness versions remains valid
- Technical effect: this upgrade space cannot be spent during the active period

== Rules 4 and 5: annex and control blocks

- Witness stacks with a Taproot annex are invalid
- Taproot control blocks larger than 257 bytes are invalid
- 257 bytes means maximum Merkle depth 7
- A balanced depth-7 Taptree can contain up to 128 leaves
- Deep or deliberately unbalanced Taptrees may be affected

== Rules 6 and 7: Tapscript opcodes

- Tapscripts containing `OP_SUCCESS\*` anywhere are invalid
- This applies even if the opcode would not otherwise execute
- Tapscripts executing `OP_IF` or `OP_NOTIF` are invalid
- The condition result does not matter
- Some Miniscript-generated Tapleaves may need adjustment

== Grandfathering and expiry

- Inputs spending UTXOs created before activation are exempt from all new checks
- New outputs created after activation are checked at creation and, where applicable, when spent
- This matters because Taproot trees are hidden at output creation time
- After expiry, UTXOs of all heights are unrestricted again
- The proposal is height-sensitive, not only transaction-format-sensitive

== What stays unchanged

- Monetary supply rules
- Proof-of-work and block header format
- Block weight limit
- Ordinary P2PKH, P2SH, P2WPKH, P2WSH, and P2TR outputs
- Taproot key-path spends
- Commitment-by-hash patterns

= Deployment

== Parameters

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

== Differences from BIP-9

#table(
  columns: (auto, 1fr),
  align: left,
  [*Standard BIP-9*], [*BIP-110*],
  [95% threshold], [55% threshold],
  [Timeout can fail], [`NO_TIMEOUT`; no ordinary `FAILED` state],
  [No mandatory signaling], [Mandatory signaling before maximum activation],
  [`ACTIVE` is terminal], [`ACTIVE` later becomes `EXPIRED`],
  [Permanent once active], [Temporary: 52,416 active blocks],
)

== Important heights and dates

#text(size: 0.88em)[
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

== Activation paths

- Early path: any retarget period reaches 1,109 signaling blocks
- Mandatory path: blocks 961,632 through 963,647 must signal bit 4
- Lock-in to activation is one retarget period, about two weeks
- If activation is at 965,664, expiry is at 1,018,080
- Calendar dates are estimates; heights are the exact consensus boundaries

= Effects

== Affected patterns

- Large data in spendable output scripts
- Large contiguous script pushes
- Large script argument witness items
- Undefined witness and Tapleaf version spends
- Taproot annex usage
- Very deep Taproot script trees
- Tapscripts using `OP_SUCCESS\*`, executed `OP_IF`, or executed `OP_NOTIF`

== Wallet and contract notes

- Wallets creating post-activation Taproot scripts must avoid banned constructs
- Miniscript compilers may need temporary policy changes
- Protocols using large Taptrees may need shallower constructions
- Pre-signed Taproot transactions need attention if they must confirm and spend during the active period
- The BIP describes narrow possible fund-freezing or fund-loss scenarios

= Sources

== Primary sources

- #link("https://github.com/bitcoin/bips/blob/master/bip-0110.mediawiki")[BIP-110: Reduced Data Temporary Softfork]
- #link("https://github.com/bitcoin/bips/blob/master/bip-0009.mediawiki")[BIP-9: Version bits with timeout and delay]
- #link("https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki")[BIP-16: Pay to Script Hash]
- #link("https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki")[BIP-141: Segregated Witness consensus layer]
- #link("https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki")[BIP-341: Taproot]
- #link("https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki")[BIP-342: Tapscript]

== Q&A
