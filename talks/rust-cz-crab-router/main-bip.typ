#import "@preview/touying:0.5.3": *
#import themes.simple: *

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [BIP-110: Activation and Timeline],
  config-info(
    title: [BIP-110: Activation and Timeline],
    author: [Lukáš Hozda],
    institution: [Braiins],
  ),
)

#set page(fill: rgb("#f8f5ee"))

#align(center + horizon)[
  #image("braiins-symbol-black-rgb.png", width: 28%)
]

#title-slide()[
  #align(center + horizon)[
    = BIP-110: Activation and Timeline
  ]
]

= Intro

== Lukáš Hozda

- Rust/Lisp programmer #pause
- Bitcoin, Emacs, HTMX, Linux enthusiast #pause
- Teaching Rust at MatFyz, sometimes commercial Rust courses #pause
- Marketing at Braiins #pause
- Frequent yapper on twitter \@LukasHozda

==

#align(center)[
  #image("lukas-rust-book.png", height: 86%)
]

== Today

- How soft fork activations work #pause
- What BIP-110 changes at the consensus level #pause
- Why its deployment is unusual #pause
- Where we are on the timeline right now #pause
- How this compares with SegWit and Taproot

= Soft forks

== Měkké vidličky?

- A tightening of Bitcoin's consensus rules #pause
- Some transactions that were valid before become invalid #pause
- Old nodes still accept new blocks as valid #pause
- New nodes reject blocks that break the new rules #pause
- Contrast with a hard fork, which would split the network #pause
  - HF loosens rules so old nodes reject new nodes

== Why activations are tricky

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
- Miners can veto by simply not signaling

== BIP9 states

- DEFINED: waiting for start time #pause
- STARTED: signaling window is open #pause
- LOCKED_IN: threshold was reached, activation scheduled #pause
- ACTIVE: new rules are enforced #pause
- FAILED: timeout hit without reaching threshold

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
- Signaling reached near 100% in the lock-in period #pause
- The current baseline for "how Bitcoin upgrades are done"

== Mechanisms summary

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

== High-level goal

- Push back against non-monetary data embedding at the consensus level #pause
- Temporarily invalidate several ways of embedding large payloads #pause
- One-year sunset: rules automatically expire #pause
- Stated intent is to "send a message" more than to fix data embedding forever

== Terms

- Before listing the restrictions, we need definitions #pause
- scriptPubKey, PUSHDATA, witness data, taproot annex, control block, tapscript opcodes #pause
- These come straight from Bitcoin's script system #pause

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

== Inscription envelope

```
<32-byte x-only pubkey>
OP_CHECKSIG
OP_FALSE
OP_IF
  OP_PUSHBYTES_3 "ord"
  OP_PUSHNUM_1
  OP_PUSHBYTES_9 "image/png"
  OP_0
  OP_PUSHDATA2 <520 bytes>
  OP_PUSHDATA2 <520 bytes>
  OP_PUSHDATA2 <520 bytes>
  OP_PUSHDATA2 <440 bytes>
OP_ENDIF
```
OP_PUSHBYTES is not a real opcode, it's a raw direct push of 1-75 bytes

== Witness data

- Added by SegWit in 2017 #pause
- A separate area of the transaction for signatures and script arguments #pause
- Weighed at 1 unit per byte instead of 4 (the "witness discount") #pause
- This discount is why inscriptions live there: it's the cheapest space #pause
- Post-Taproot, witness data can include scripts, signatures, or arbitrary payloads

== Tapscript

- The scripting language used inside a Taproot script-path spend #pause
  - FYI also has a key-path spend
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

== 

- Caps the size of individual data chunks to 256 bytes #pause
- Closes off large Taptrees beyond 128 leaves #pause
- Bans two conditional opcodes often used to skip over embedded data #pause
- Locks down parts of the protocol reserved for future upgrades #pause
- Leaves normal payments untouched

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

== Why this combination is unusual

- 55% is well below recent precedent #pause
- Mandatory signaling means activation is effectively built in #pause
- It is the first soft fork designed to expire automatically #pause
- The window is compressed (~9 months) #pause

== Threshold context

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

- Current block height: 946,182 (as of April 22, 2026) #pause
- Current retarget period: 469 #pause
- Roughly 8 retarget periods until mandatory signaling begins #pause
- That is about 16 weeks, give or take difficulty adjustments

== Observed signaling so far

#table(
  columns: (auto, auto, auto),
  align: left,
  [*Period*], [*Range*],         [*Signaling*],
  [465],      [937440--939455],  [0.05% (1/2016)],
  [466],      [939456--941471],  [0%],
  [467],      [941472--943487],  [0.15% (3/2016)],
  [468],      [943488--945503],  [0.10% (2/2016)],
  [469],      [945504--947519],  [0% so far],
)

== Signalling

- Required: 1109 signaling blocks in a retarget period #pause
- Observed so far: 0 to 3 signaling blocks per period #pause
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

== Important nuance

- People often say "SegWit was activated by UASF" #pause
- That's not quite right #pause
- BIP148 (UASF) was a threat that changed incentives #pause
- BIP91 (MASF variant) did the actual forcing work on miners #pause
- SegWit's own BIP9 deployment then reached 100% signaling under pressure

== SegWit timeline

- Nov 15, 2016: BIP9 signaling begins #pause
- Mar to Jun 2017: stalemate near 30% #pause
- Mar 12, 2017: BIP148 proposed #pause
- May 22, 2017: BIP91 proposed #pause
- Jul 2017: BIP91 locked in and activated #pause
- Aug 9, 2017: SegWit locked in #pause
- Aug 24, 2017: SegWit activated at block 481,824

== Side by side

#table(
  columns: (auto, auto, auto, auto),
  align: left,
  [],                  [*SegWit*],        [*Taproot*],  [*BIP-110*],
  [Threshold],         [95%],             [90%],        [55%],
  [Window],            [~1 year],         [~3 months],  [~9 months],
  [Forced activation], [No (only threat)],[No],         [Yes (built-in)],
  [Permanent],         [Yes],             [Yes],        [No (1 year)],
  [Peak signaling],    [Reached 100%],    [~99%],       [\<0.2% so far],
)

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

== Open questions

- Will Bitcoin Core merge an implementation? #pause
  - PR closed: https://github.com/bitcoin/bitcoin/pull/34930 #pause
- Will any major mining pool run it? #pause
- What does "activation" mean if almost no one enforces it? #pause
- Does mandatory signaling matter if the rule-checking nodes are a tiny minority?

== Differences from SegWit

- SegWit: wide user demand, miner resistance #pause
- BIP-110: vocal minority support, no visible miner or Core support #pause
- SegWit: activation came from public negotiation and pressure #pause
- BIP-110: forced activation is written directly into the deployment #pause

= End

== Q&A
