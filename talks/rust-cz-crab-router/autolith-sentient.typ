#import "@preview/touying:0.5.3": *
#import themes.simple: *

// Interlisp Paper: one substrate, black ink, small semantic accents.
#let page-fill = rgb("#fffefa")
#let ink = rgb("#000000")
#let accent-red = rgb("#8a1c1c")
#let accent-green = rgb("#12633a")
#let accent-blue = rgb("#003a70")

#let flow-box(body, stroke: ink) = block(
  width: 100%,
  inset: 9pt,
  radius: 0pt,
  fill: page-fill,
  stroke: 1pt + stroke,
)[
  #set text(top-edge: "ascender")
  #align(center)[#body]
]

#let flow-down = align(center)[
  #text(size: 1.2em, weight: "bold")[#sym.arrow.b]
]

#let compact(body) = text(size: 0.82em)[#body]

#show: simple-theme.with(
  aspect-ratio: "16-9",
  footer: self => [Autolith · Lambda Symbolics OÜ],
  config-info(
    title: [Autolith],
    author: [Lukáš Hozda],
    institution: [Lambda Symbolics OÜ],
  ),
  config-page(
    fill: page-fill,
  ),
  config-colors(
    neutral-lightest: page-fill,
    neutral-darkest: ink,
  ),
  config-common(
    show-strong-with-alert: false,
  ),
)

#set text(font: "Times New Roman MT Std", fill: ink)
#show raw: set text(font: "CMU Typewriter Text")
#show table.cell: set text(top-edge: "ascender")

== Autolith

A live, self-modifiable, introspectable terminal agent runtime inside a Common Lisp image.

#grid(
  columns: (1.1fr, 1fr),
  column-gutter: 18pt,
  align: top,
  compact[
    #table(
      columns: (auto, 1fr),
      stroke: 0.5pt + ink,
      inset: (x: 7pt, y: 7pt),
      align: horizon,
      [*Website*], link("https://lambda-symbolics.com/autolith")[lambda-symbolics.com/autolith],
      [*Source*], link("https://github.com/lambda-symbolics/autolith")[github.com/lambda-symbolics/autolith],
      [*Author*], [Lukáš Hozda],
      [*Status*], [in development since June 2026],
    )
  ],
  block(breakable: false)[
    #align(center)[#image("autolith-mascot.png", height: 210pt)]
  ],
)

== The status quo (?)

#compact[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 22pt,
    align: top,
    [
      *Contemporary agent harnesses*

      - Fixed orchestration loop
      - Opaque state and tool execution
      - No budgets and capability limits
      - Often just one provider, or a predefined list
    ],
    [
      *Autolithic alternative*

      - A live, programmable runtime transparently available to the model
      - State, tools, policy, ledgers: inspectable data
      - Budgets, capabilities, isolation: explicit objects
      - Providers are interchangeable clients
    ],
  )

  #v(1em)
    What does an agent look like built as a live computing system, rather than a chat wrapper?

    Models are now capable enough that the runtime around them increasingly determines their autonomy, reliability, and controllability.
]

== Contemporary Autolith (what we have)

#compact[
  #grid(
    columns: (1.2fr, 1fr),
    column-gutter: 20pt,
    align: top,
    [
      - Live self-modification tools: redefine, exercise, commit, append-only mutation journal
      - Crash capsules, pristine recovery image, image generations
      - 7 providers, plus any OpenAI-compatible endpoint
      - Isolated workers, confined resources
      - Recursive Language Model (RLM) tools
      - 50+ people on Zulip
      - Linux, macOS, FreeBSD, NetBSD, OpenBSD
    ],
    align(center + horizon)[
      #flow-box[
        *Active image*
        #v(0.3em)
        #grid(
          columns: (1fr, 1fr),
          gutter: 6pt,
          flow-box[#compact[terminal UI]],
          flow-box[#compact[provider client]],
          flow-box[#compact[tool registry]],
          flow-box[#compact[conversation store]],
          flow-box[#compact[mutation journal]],
          flow-box[#compact[agenda · memory]],
        )
      ]
      #v(0.4em)
      #grid(
        columns: (1fr, 1fr),
        gutter: 6pt,
        flow-box(stroke: accent-blue)[#compact[worker images]],
        flow-box(stroke: accent-blue)[#compact[RLM frames]],
      )
      #v(0.4em)
      #flow-box(stroke: accent-green)[#compact[saved image generations · replay scripts]]
    ],
  )
]

== Example RLM call

#grid(
  columns: (1.05fr, 1fr),
  column-gutter: 20pt,
  align: horizon,
  block(breakable: false)[
    #image("autolith-screenshot.png", height: 300pt)
  ],
  compact[
    - The task is to ingest the entire Autolith codebase and discover and describe condition classes      
    - An `rlm.complete` call is issued: 32 child calls, 400k tokens, at depth 2
    - 3.1 MB example corpus enters as `workspace:autolith-source.txt` as programmable data to RLM instances
    - Completed in 3 min 15 s; full recording is on the project page

    #v(0.4em)
    #text(size: 0.82em, style: "italic")[Recorded (v0.35), unedited.]
  ],
)

== Recursive inference (RLM)

#compact[
  #grid(
    columns: (1fr, 1.1fr),
    column-gutter: 20pt,
    align(center + horizon)[
      #set block(spacing: 5pt)
      #flow-box[*parent inference*]
      #flow-down
      #grid(
        columns: (1fr, 1fr),
        gutter: 8pt,
        flow-box[
          *child inference* \
          #compact[
            context · output contracts \
            capability set \
            call · token · depth budget
          ]
        ],
        flow-box[
          *child inference* \
          #compact[
            context · output contracts \
            capability set \
            call · token · depth budget
          ]
        ],
      )
      #flow-down
      #flow-box(stroke: accent-blue)[inspectable traces #sym.arrow parent evaluation]
    ],
    [
      - Call, token, and depth budgets are shared down the tree
      - Parallel children are exceuted against one pool; output metered in tranches
      - RLM Children inherit nothing, the corpus lives in an isolated environment
      - The model sees label, size, digest; works via slices, searches, sub-inferences
      - Every frame leaves a replayable trace (`inference:ID`)
      - Budget exhaustion triggers a typed condition the parent agent can work with
    ],
  )
]

== Autolith openness

- Autolith is licensed under the very permissive ISC license
- Runtime and accumulated state inspectable down to source
- Provider-independent: subscriptions, API keys, self-hosted endpoints
- Pieces ship as libraries: image generations, budgets, provider clients
  - We want to share as much as possible with the broader ecosystem to encourage development
- Execution and capability policy is user-editable code
- A reference implementation for agent researchers, with or without Autolith itself
- Closing it would remove an inspectable implementation that researchers can modify down to its inference and execution policy
- 
== What the grant unlocks

#compact[
  #grid(
    columns: (1.15fr, 1fr),
    column-gutter: 20pt,
    align: top,
    [
      Six months of focus time to turn the experimental RLM work into a
      robust, reusable subsystem:

      - enforceable shared limits: tokens, calls, depth, context, capabilities
      - better sandboxing, recovery, inspectable execution traces
      - local and provider-independent models
      - reproducible benchmarks against other agent harnesses
      - standalone libraries from generally useful components
      - documentation, packaging, release infrastructure
    ],
    [
      #table(
        columns: (1fr, auto),
        stroke: 0.5pt + ink,
        inset: (x: 7pt, y: 7pt),
        align: (left + horizon, right + horizon),
        [R&D time; primarily mine, partly Jack Chakany's], [\$38k],
        [Model inference, benchmark runs, compute], [\$6k],
        [Release infrastructure, hosting, hardware], [\$3k],
        [External security review, research travel], [\$3k],
      )
    ],
  )
]

== The broader question

#align(center)[
  #v(2em)
    #block(stroke: 1pt + ink, inset: 16pt, width: 78%)[
      #set text(top-edge: "ascender")
      #text(size: 1.15em, style: "italic")[
        Can AI agents look more like programmable computers: systems which
        can be modified and introspected, whose reasoning, state, resource use
        and actions can be observed and deliberately constrained?
      ]
    ]
]
