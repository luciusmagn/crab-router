#import "@preview/touying:0.5.3": *
#import themes.simple: *

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [BIP-110],
  config-info(
    title: [BIP-110],
    author: [Lukáš Hozda],
    institution: [Braiins],
  ),
  config-page(
    fill: rgb("#f8f5ee"),
  ),
  config-colors(
    neutral-lightest: rgb("#f8f5ee"),
  ),
)

#title-slide()[
  #align(center + horizon)[
    = BIP-110
  ]
]

== HL Agenda

- How soft fork activations work #pause
- What BIP-110 changes at the consensus level #pause
- Why its deployment is unusual #pause
- Where we are on the timeline right now #pause
- How this compares with SegWit and Taproot

= Soft forks

==

- A tightening of Bitcoin's consensus rules #pause
- Some transactions that were valid before become invalid #pause
- Old nodes still accept new blocks as valid #pause
- New nodes reject blocks that break the new rules #pause
- Contrast with a hard fork, which would split the network #pause
  - HF loosens rules so old nodes reject new nodes

== Activations are tricky

- Miners, node operators, wallets, and exchanges must agree #pause
- If roughly half the network enforces new rules and half doesn't, you can get two chains #pause
- Activation mechanisms exist to avoid that outcome #pause

== Version bits

- Each block header has a 32-bit version field #pause
- Bits in that field can be used as flags #pause
- A bit set means: "this miner is ready for proposal X" #pause
- Nodes can count how many recent blocks signal a given bit #pause
- This is how miners coordinate without a central authority

== Two families of activation

- MASF: Miner Activated Soft Fork #pause
- UASF: User Activated Soft Fork #pause

== MASF

- Miners signal readiness using version bits #pause
- Once a supermajority signals within a retarget window, the fork locks in #pause
  - BIP9 default is 95%, taproot speedy trial was 90%
- Miners effectively hold a veto #pause
- Works well when miners want the change

== MASF examples

- BIP65 (CLTV, 2015): adds CheckLockTimeVerify #pause
  - Lets a script require that coins cannot be spent before a given time or block #pause
- BIP68/112/113 (CSV, 2016): adds relative timelocks #pause
  - Lets a script say "wait N blocks after this coin was mined" #pause
- Both used the BIP9 framework and activated cleanly

== UASF

- Nodes enforce new rules on a flag day regardless of miner signaling #pause
  - Users signal by running a node that enforces the new rules on a flag day #pause
- Non-compliant blocks get rejected by those nodes #pause
- Miners either follow or risk building on a chain those nodes ignore #pause
- Power shifts from miners to economic full nodes

== UASF examples

- BIP16 (P2SH, 2012): Pay to Script Hash #pause
  - Let users send to the hash of a script, revealing the script later #pause
  - Activated by flag day, it did split the chain briefly #pause
  - Flag day March 31, 2012
- BIP148 (2017): SegWit pressure #pause
  - Would have rejected non-SegWit-signaling blocks after Aug 1, 2017 #pause
  - It was a threat, not the actual activation mechanism for SegWit #pause
- BIP-110 #pause
  - Miners cooperate by setting bit 4 or their blocks will be invalid

== BIP9

- The standard MASF framework used from 2015 onward #pause
- Signaling window is broken into 2016-block retarget periods #pause
- 95% of blocks in a period must signal for lock-in #pause
- Has a start time and a timeout (can end in FAILED) #pause
- Miners can veto by simply not signaling #pause
- States: DEFINED, STARTED, LOCKED_IN, ACTIVE, FAILED

== BIP8

- A BIP9 variant, proposed after the SegWit stalemate #pause
- Uses block heights instead of wall-clock time #pause
- Adds a LOT (Lock on Timeout) parameter: #pause
  - LOT=false behaves like BIP9 #pause
  - LOT=true guarantees activation at timeout even without miner support #pause
- Never activated a real deployment, but influenced later designs

== Speedy Trial

- A compromise design used for Taproot in 2021 #pause
- BIP8 with LOT=false and a short window (~3 months) #pause
- 90% threshold instead of 95% #pause
- If miners don't cooperate, it fails fast with low drama #pause
- If they do, activation is quick

== Taproot

- BIPs 340, 341, 342 (Schnorr signatures + Taproot + Tapscript) #pause
- Activated via Speedy Trial in November 2021 #pause
- Signaling reached near 100% in the lock-in period

== Mechanisms

#table(
  columns: (auto, auto, auto),
  align: left,
  [*Mechanism*],    [*Miner veto*], [*Example*],
  [BIP9],           [Yes],          [CLTV, CSV, SegWit],
  [BIP8 LOT=false], [Yes],          [Taproot (Speedy Trial)],
  [BIP8 LOT=true],  [No],           [Kinda Bip-110],
  [Flag-day UASF],  [No],           [BIP16 (P2SH), BIP148 (threat)],
)

= BIP-110

== Goal

- Push back against non-monetary data embedding at the consensus level #pause
- Temporarily invalidate several ways of embedding large payloads #pause
- One-year sunset: rules automatically expire #pause
- Stated intent is to "send a message" more than to fix data embedding forever

== Terms

- Before listing the restrictions, some definitions #pause
- scriptPubKey, PUSHDATA, witness data, taproot annex, control block, tapscript opcodes #pause
- All related Bitcoin's script system #pause

If you don't know, scripts are essentially mini programs attached to coins

== scriptPubKey

- The "locking script" on each transaction output #pause
- Defines the conditions to spend those coins #pause
- Modern addresses produce small scriptPubKeys (often ~22 to 34 bytes) #pause
  - Quantum resistant pubkeys are much bigger, but you'd commit via hash #pause
    - Commit now reveal later is a better idea anyway and we use it (P2PKH and onwards) #pause
- Every unspent output's scriptPubKey lives in the UTXO set forever #pause
  - Embedding data here does bloat the UTXO set #pause

== PUSHDATA

- Script opcodes that push bytes onto the execution stack #pause
- OP_PUSHDATA1, 2, and 4 take 1, 2, or 4-byte length prefixes #pause
- Used for legitimate things: public keys, signatures, hashes #pause
- Also the main vehicle for inscribing arbitrary data inside scripts

== Witness data

- Added by SegWit in 2017 #pause
- A separate area of the transaction for signatures and script arguments #pause
- Weighed at 1 unit per byte instead of 4 (the "witness discount") #pause
- This discount is why inscriptions live there: it's the cheapest space #pause
- Post-Taproot, witness data can include scripts, signatures, or arbitrary payloads

== Tapscript

- The scripting language used inside a Taproot script-path spend #pause
  - FYI also has a key-path spend #pause
- Each script-path alternative is called a Tapleaf #pause
- All of a user's Tapleaves together form a Merkle tree called the Taptree #pause
- Only the leaf you actually spend needs to be revealed #pause
  - No scripts will be revealed if you use the script-path spend

== Control blocks

- Part of a Taproot script-path spend #pause
- Proves that the revealed Tapleaf is really part of the committed Taptree #pause
- Contains the internal public key, parity bit, and a Merkle path #pause
- Size grows with tree depth: 33 bytes + 32 bytes per level #pause
- Size of the control block limits how deep the Taptree can be #pause
- Can be used to embed arbitrary data by making the taptree lopsided and using arbitrary 32 byte siblings

== Taproot annex

- An optional extra element in a Taproot witness stack #pause
- Reserved for future upgrades, currently has no defined meaning #pause
- No size limit in the current rules #pause
- Today, wallets don't use it AFAIK

== Tapscript opcodes we care about

- OP_SUCCESS\*: reserved opcodes for future soft forks #pause
  - If encountered, the script succeeds unconditionally #pause
- OP_IF / OP_NOTIF: conditional branching inside a script #pause
  - Execute one branch if a value is true, another if false #pause
- All three can be abused to stuff data into scripts that never executes

== BIP-110 restrictions

- scriptPubKey ≤ 34 bytes (OP_RETURN up to 83) #pause
- PUSHDATA payloads and script argument witness items ≤ 256 bytes #pause
- No spending of undefined witness or Tapleaf versions #pause
- No Taproot annex in witness stacks #pause
- Control blocks ≤ 257 bytes (max 128 leaves) #pause
- No OP_SUCCESS\*, OP_IF, or OP_NOTIF in tapscripts

== Deployment parameters

- name: `reduced_data` #pause
- bit: 4 #pause
- starttime: ~December 2025 #pause
- timeout: NO_TIMEOUT #pause
- max_activation_height: 965664 (~September 2026) #pause
- active_duration: 52416 blocks (~1 year) #pause
- threshold: 1109/2016 = 55%

== Deviations from BIP9

1. Threshold is 55% instead of 95% #pause
2. No timeout: uses max_activation_height instead #pause
3. Mandatory signaling period before max_activation_height #pause
4. Auto-expires after active_duration (1 year of ACTIVE) #pause
5. Introduces a new terminal state, EXPIRED

== State machine

- DEFINED → STARTED (at starttime) #pause
- STARTED → LOCKED_IN (threshold hit, or forced by mandatory signaling) #pause
- LOCKED_IN → ACTIVE (one retarget period later) #pause
- ACTIVE → EXPIRED (after about one year) #pause
- FAILED is never reached: deployment cannot fail by timeout

== Other tresholds

#table(
  columns: (auto, auto, auto),
  align: left,
  [*Fork*],    [*Threshold*], [*Mechanism*],
  [CLTV, CSV], [95%],         [BIP9],
  [SegWit],    [95%],         [BIP9 (later 80% via BIP91)],
  [BIP91],     [80%],         [BIP9 variant],
  [Taproot],   [90%],         [Speedy Trial],
  [BIP-110],   [55%],         [Modified BIP9 with BIP8-style forcing],
)

= Timeline

== Key heights

- starttime: ~Dec 1, 2025 #pause
- Mandatory signaling window: blocks 961,632 to 963,647 #pause
- Latest possible lock-in: block 963,648 #pause
- Activation: block 965,664 (~Sep 2026) #pause
- Expiry: block 1,018,080 (~Sep 2027)

== Where we are now

- Current block height: 954,391 (as of June 19, 2026) #pause
- Current retarget period: 473 #pause
- Roughly 3.6 retarget periods until mandatory signaling begins #pause
- => About 7 weeks, give or take difficulty adjustments

== Observed signaling so far

#table(
  columns: (auto, auto, auto),
  align: left,
    [*Period*], [*Range*],         [*Signaling*],
    [465],      [937440--939455],  [0.05% (1/2016)],
    [466],      [939456--941471],  [0% (0/2016)],
    [467],      [941472--943487],  [0.15% (3/2016)],
    [468],      [943488--945503],  [0.10% (2/2016)],
    [469],      [945504--947519],  [0% (0/2016)],
    [470],      [947520--949535],  [0% (0/2016)],
    [471],      [949536--951551],  [0.35% (7/2016)],
    [472],      [951552--953567],  [0.79% (16/2016)],
    [473],      [953568--955583],  [0.24% so far (2/820)]
)

== Signalling

- Required: 1109 signaling blocks in a retarget period #pause
- Completed periods so far: 0 to 16 signaling blocks per period #pause
- Current period: 2 signaling blocks out of 820 observed #pause
- Natural lock-in through organic signaling looks very unlikely #pause
- The practical activation path is mandatory signaling #pause
- That only matters if enough nodes and pools actually run the rule

== Two paths to activation

1. Natural: some retarget period reaches 55% → LOCKED_IN #pause
2. Forced: during the mandatory signaling window, non-signaling blocks are rejected #pause
#pause
- Both paths converge on ACTIVE at block 965,664 #pause
- The only way to stop activation is for the client to not be adopted

= SegWit

== SegWit comparison

- Most recent contested activation #pause
- Illustrated all three dynamics: MASF stall, UASF pressure, miner compromise #pause
- Led directly to the design of BIP8 and Speedy Trial #pause
- Good mirror for thinking about BIP-110

== SegWit (BIP141) initial deployment

- Activation: BIP9, 95% threshold #pause
- Signaling window: Nov 15, 2016 to Nov 15, 2017 #pause
- Used bit 1 in the block version field #pause
- 26 retarget periods available

== The stall

- Miner signaling stuck around 30% for months #pause
- A handful of large pools actively opposed it #pause
- BIP9's 5% veto margin was easy to hit #pause
- Users and businesses grew increasingly frustrated

== BIP148 (the UASF threat)

- Proposed flag day: August 1, 2017 #pause
- BIP148 nodes would have rejected blocks that didn't signal SegWit #pause
- A user-driven threat, not a developer consensus #pause
- Created a real possibility of chain split

== BIP91 (the compromise)

- 80% threshold over a short 336-block window #pause
- Once active, orphaned any block not signaling SegWit #pause
- Came out of the New York Agreement between miners and businesses #pause
- Locked in and activated before BIP148's flag day #pause
- This is what actually triggered SegWit's lock-in

== Segwit wasn't UASF

- People often say "SegWit was activated by UASF" #pause
- BIP148 (UASF) was a threat that changed incentives #pause
- BIP91 (MASF variant) did the actual forcing work on miners #pause
- SegWit's own BIP9 deployment then reached 100% signaling under pressure

= Where we are

== Current state

- BIP-110 status: Draft #pause
- Implemented in: Bitcoin Knots #pause
- Not implemented in: Bitcoin Core #pause
- Observed pool signaling: effectively zero #pause
- No public commitments from major mining pools

== Possible scenarios

- A: Pools reach 55% in some retarget period → natural lock-in #pause
- B: Mandatory signaling forces activation mid-2026 #pause
- C: The client is not adopted, the deployment has no network-wide effect #pause
- From the rest of the ecosystem's perspective, C is indistinguishable from the BIP not existing

= Sentiment

== Supporter frame

- Bitcoin is money, not data storage #pause
- Data embedding imposes costs on node operators #pause
- A temporary restriction buys time #pause
- Consensus can express a social boundary #pause
- Better to resist now than let the pattern become normal

== Opponent frame

- Bitcoin should validate rules, not transaction purpose #pause
- Fee-paying valid transactions should remain neutral #pause
- Data can move into other encodings anyway #pause
- Temporary restrictions still create precedent #pause
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

- Major exchanges: Coinbase, Binance, Kraken #pause
- Hardware-wallet vendors: Ledger, Trezor #pause
- Most wallet companies #pause
- Most public Bitcoin treasury companies #pause
- Most payment apps and custodians #pause
- Most mining pools

== Q&A
