#import "@preview/touying:0.5.3": *
#import themes.simple: *

#let page-fill = rgb("#f8f5ee")
#let sender-fill = rgb("#dce8f2")
#let receiver-fill = rgb("#dcebdc")
#let chain-fill = rgb("#eee7c8")
#let legacy-fill = rgb("#f1ddd7")
#let neutral-fill = rgb("#e7e0ed")
#let line-color = rgb("#89939a")

#let flow-box(body, fill: sender-fill) = block(
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
  footer: self => [Silent Payments / BIP 352],
  config-info(
    title: [Silent Payments],
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
    = Silent Payments
    #text(size: 0.62em)[BIP 352]
  ]
]

== Agenda

- The static-address problem #pause
- Prior art: Stealth addresses, BIP47, BIP351 #pause
- BIP 352's history and status #pause
- Sender derivation and receiver scanning #pause
- Trade-offs and constraints regarding wallets #pause

= Privacy problems

== A donation address is a graph node

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,
    flow-box([*Alice* \
      #text(size: 0.7em)[donates]], fill: sender-fill),
    flow-arrow,
    flow-box([*bc1...same address* \
      #text(size: 0.7em)[publicly reused]], fill: legacy-fill),
    flow-arrow,
    flow-box([*Bob* \
      #text(size: 0.7em)[recipient]], fill: receiver-fill),
  )

  #v(0.8em)
  #text(size: 0.82em)[Every payment to the address is trivially linked]
]

== Fresh addresses require a delivery channel

#compact[
  - Best practice: give every sender a fresh address #pause
  - But that generally needs an interaction #pause
  - A public static address removes the interaction but creates permanent on-chain linkage #pause
  - Silent Payments aim for both #pause
      - one reusable public identifier
      - one unique on-chain output per payment
]

== Goals

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 14pt,
    align: top,
    flow-box([*Reusable* \
      #text(size: 0.7em)[publish one identifier]], fill: neutral-fill),
    flow-box([*Unlinked* \
      #text(size: 0.7em)[each payment has a different output key]], fill: receiver-fill),
    flow-box([*Non-interactive* \
      #text(size: 0.7em)[no invoice or notification round trip]], fill: sender-fill),
  )

  #v(1em)
  The hard part is letting the recipient find the payment without giving observers the same signal.
]

= Prior art

== Le galerie

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr, 1fr, 1fr),
    column-gutter: 10pt,
    align: top,
    flow-box([*Static address* \
      #text(size: 0.65em)[no setup, payments link]], fill: legacy-fill),
    flow-box([*Stealth address* \
      #text(size: 0.65em)[unique output, ephemeral-key signal]], fill: neutral-fill),
    flow-box([*BIP47* \
      #text(size: 0.65em)[unique outputs, notification step]], fill: chain-fill),
    flow-box([*BIP352* \
      #text(size: 0.65em)[unique outputs, scan every candidate]], fill: receiver-fill),
  )
]

== Classic stealth addresses

#compact[
  - Long-standing construction: recipient publishes a public key or key pair #pause
  - Sender creates an ephemeral key and derives a one-time destination with ECDH #pause
  - Recipient needs the sender's ephemeral public key to discover the payment #pause
  - That key must be carried on-chain or otherwise delivered #pause
  - Silent Payments retain one-time ECDH derivation (Elliptic Curve Diffie-Helman)
      - but reuse the transaction inputs as the public data instead of adding an announcement
]

== BIP47 reusable payment codes

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,
    flow-box([*Payment code*], fill: receiver-fill),
    flow-arrow,
    flow-box([*Notification transaction* \
      #text(size: 0.68em)[establishes the sender-recipient channel]], fill: legacy-fill),
    flow-arrow,
    flow-box([*Derived payment addresses*], fill: sender-fill),
  )

  #v(0.85em)
  BIP47 avoids address reuse, but the one-time notification adds cost and a visible protocol footprint.
]

== BIP47 and BIP352

#text(size: 0.77em)[
  #table(
    columns: (1.3fr, 1fr, 1fr),
    align: left,
    [*Property*], [*BIP47*], [*BIP352*],
    [Public recipient identifier], [Payment code], [Silent payment address],
    [First payment], [On-chain notification], [Direct payment],
    [On-chain recognizability], [Notification is recognizable], [No special marker],
    [Recipient work], [Watch derived addresses], [Scan eligible transactions],
    [Output type], [Protocol-dependent], [Taproot v1],
    [Sender linkage], [Recipient learns sender channel], [No persistent channel],
  )
]

== BIP351

#compact[
  - 2022 informational proposal by Alfred Hodler and Clark Moody #pause
  - Also uses reusable payment codes and derived payment addresses #pause
  - Sender publishes a 40-byte `OP_RETURN` notification to establish a channel #pause
  - Adds explicit address-type flags to the payment code #pause
  - Like BIP47, it optimizes recipient scanning with a notification step #pause
  - BIP352 instead avoids that step and pays for recipient-side transaction scanning
]

= BIP 352

== History

#text(size: 0.82em)[
  1. *2015* - Justus Ranvier proposes BIP47 reusable payment codes #pause
  2. *13 March 2022* - Ruben Somsen publishes the original Silent Payments proposal #pause
  3. *28 March 2022* - public bitcoin-dev discussion begins #pause
  4. *9 March 2023* - assigned BIP 352 #pause
  5. *8 May 2024* - BIP 352 v1.0 merged #pause
]

== BIP 352

#compact[
  - Application-layer payment protocol #pause
  - Specification status: *Complete* #pause
  - Authors: josibake, Ruben Somsen, Sebastian Falbesoner #pause
  - Uses BIP340/341 Taproot and Bech32m primitives #pause
  - No consensus change and no special transaction output #pause
    - Therefore no soft fork lol #pause
  - A silent payment output is an ordinary single-key Taproot output
]

== Address format

#align(center)[
  #block(width: 76%)[
    #flow-box([
      *Silent payment address* \
        #text(size: 0.72em)[`sp1q...` = Bech32m(scan public key `B_scan` || spend public key `B_spend`)]
    ], fill: receiver-fill)
  ]
]

#v(0.8em)

#compact[
  - The scan key lets an online wallet detect payments #pause
  - The spend key controls the received funds #pause
  - Separating them allows scanning without keeping spending material online #pause
  - Version 0 sends only to Taproot outputs
  - The addresses are pretty long btw, 116 chars (117 on testnet)
]

== Two keys

#align(center + horizon)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 18pt,
    align: top,
    flow-box([
      *Scan key* \
      #text(size: 0.7em)[online secret used to test candidate transactions]
    ], fill: chain-fill),
    flow-box([
      *Spend key* \
      #text(size: 0.7em)[offline secret, tweaked to spend each received output]
    ], fill: receiver-fill),
  )

  #v(0.95em)
  If the scan key is stolen, the attacker gets discovery, but not control of the funds
]

= Explanation

== Variables

#text(size: 0.76em)[
  #table(
    columns: (0.75fr, 2.4fr),
    align: left,
    [*Symbol*], [*Meaning*],
    [`a`], [sender private input key / scalar],
    [`A = a * G`], [sender public key / curve point],
    [`b_scan`], [recipient scan private key],
    [`B_scan`], [recipient scan public key],
    [`b_spend`], [recipient spend private key],
    [`B_spend`], [recipient spend public key],
    [`S`], [shared secret curve point],
    [`t`], [payment-specific tweak],
    [`P`], [one-time Taproot output key],
    [`G`], [secp256k1 generator point],
  )
]


- lowercase (a,b) = private scalar, uppercase (A,B) = public curve point


== 1. shared secret derivation

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 14pt,
    align: center + horizon,

    flow-box([
      *Sender* \
      #text(size: 0.7em)[
        knows `a` and `B_scan` \
        \
        `S = a * B_scan`
      ]
    ], fill: sender-fill),

    flow-bidir,

    flow-box([
      *Receiver* \
      #text(size: 0.7em)[
        knows `b_scan` and `A` \
        \
        `S = b_scan * A`
      ]
    ], fill: receiver-fill),
  )

  #v(0.9em)

  #text(size: 0.8em)[
    Since `A = a * G` and `B_scan = b_scan * G`, both sides derive the same `S`.
  ]

  #v(0.45em)

  #text(size: 0.65em)[
    BIP352 also binds this derivation to the concrete transaction inputs.
  ]
]


== 2. Shared secret computes a unique output

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 10pt,
    align: center + horizon,

    flow-box([
      *Shared secret* \
      `S`
    ], fill: neutral-fill),

    flow-arrow,

    flow-box([
      *Tweak* \
      #text(size: 0.72em)[`t = H(S || k)`]
    ], fill: chain-fill),

    flow-arrow,

    flow-box([
      *Output key* \
      #text(size: 0.72em)[`P = B_spend + t * G`]
    ], fill: receiver-fill),
  )

  #v(0.9em)

  #text(size: 0.79em)[
    `k` starts at 0 and allows several outputs to the same recipient in one transaction.
  ]

  #v(0.45em)

  #text(size: 0.79em)[
    The sender pays to `P` as an ordinary Taproot output.
  ]
]


== 3. receiver finds the payment

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    column-gutter: 9pt,
    align: center + horizon,

    flow-box([
      *Transaction inputs* \
      #text(size: 0.67em)[recover sender public-key material `A`]
    ], fill: sender-fill),

    flow-arrow,

    flow-box([
      *Derive `S`, `t`, `P`* \
      #text(size: 0.67em)[using private `b_scan`]
    ], fill: neutral-fill),

    flow-arrow,

    flow-box([
      *Compare outputs* \
      #text(size: 0.67em)[does this transaction contain `P`?]
    ], fill: receiver-fill),
  )

  #v(0.9em)

  #text(size: 0.8em)[
    If `P` appears among the Taproot outputs, the receiver knows that output belongs to him.
  ]
]


== Why silent?

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 14pt,
    align: center + horizon,

    flow-box([
      *Public information already in the transaction* \
      #text(size: 0.68em)[sender input keys]
    ], fill: sender-fill),

    flow-arrow,

    flow-box([
      *Ordinary Taproot output `P`* \
      #text(size: 0.68em)[no notifs anywhere onchain]
    ], fill: chain-fill),
  )

  #v(0.9em)

  The sender constructs `P`; the receiver independently rediscovers it.

  #v(0.45em)

  #text(size: 0.78em)[
    Spending it is a regular Taproot key-path spend with recipient's
    spend key plus the same tweak.
  ]
]

= Trade-offs
== Trade-offs
#compact[
  - Receiver-side scanning is way heavier than conventional wallet scanning #pause
    - each eligible candidate transaction requires elliptic-curve calcs #pause
  - Full-node scanning is straightforward, but light-client support is probably more involved #pause
  - Both sender and recipient wallets must implement the protocol #pause
  - V0 requires Taproot outputs #pause
  - Collaborative transaction support is not currently recommended
    - no formal security proof for the required coordination
]

== Scanning

#align(center + horizon)[
  #grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 14pt,
    align: center + horizon,
    flow-box([
      *Classic wallet* \
      #text(size: 0.7em)[look up known scripts in UTXO set or filters]
    ], fill: sender-fill),
    [],
    flow-box([
      *Silent payment wallet* \
      #text(size: 0.7em)[derive a candidate key from each eligible transaction]
    ], fill: receiver-fill),
  )
]

== Q&A
