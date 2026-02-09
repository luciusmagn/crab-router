# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Quality Requirements

**NO SHORTCUTS, OVERSIMPLIFICATIONS, OR CHEAP HACKS.** When implementing features or fixing bugs:
- If asked to provide something that already exists, point it out instead of creating an alias
- Never leave TODOs, FIXMEs, or placeholder implementations
- Never simplify requirements without explicit approval
- Never use "good enough for now" solutions
- Implement everything properly and completely the first time
- If something is complex, implement the complexity - don't paper over it
- Never ship unlocalized UI/user-facing text unless explicitly requested; always use `t8n` keys and add new keys to all language files together

## Git Commit Policy

- **Commit messages**: Primitive style, title line only, <72 characters
- **No co-author**: Never add Co-Authored-By lines
- **Push immediately**: Push after each commit, don't batch commits
- **Prefer rebase**: Use rebase instead of merge, avoid merge commits
- **Frequent commits**: Make small, focused commits as you complete tasks
- **Development rationale**: Add short, dated entries to `docs/dev-rationale.org` for notable decisions or behavior changes

### Submodule Workflow (i18n)
- The `i18n/` directory is a git submodule pointing to `luciusmagn/hiisi-i18n`
- When modifying translations, commit and push inside the submodule first
- Then update the parent repo's submodule reference and push
- Always push to `master` branch (not `main`)
- **CRITICAL**: When adding new translation keys, add them to ALL language files at once (en, cs, fi, de, es, pt, it, no, sv, nl, pl, da, ru). Never add keys to only some languages.

## Project Overview

Hiisi is a language learning app combining AI-powered translation with spaced repetition flashcards. It uses a **dual-backend architecture**:

- **Rust backend** (port 28888): Authentication, payments, email, background tasks
- **Common Lisp backend** (port 18888): Core app logic, translations, flashcards, UI
- **Sozu reverse proxy** (port 8888): Routes traffic between backends

## Build & Run Commands

### Nix Development (Recommended)
```bash
nix develop                       # Enter dev shell with all dependencies
nix flake check                   # Run Rust tests, Lisp load, and Lisp tests
nix build .#rust                  # Build the Rust backend
```

### Local Dependencies (Required First)

Clone these into `~/quicklisp/local-projects/`:
```bash
cd ~/quicklisp/local-projects
git clone https://github.com/luciusmagn/shoelace-hsx.git
git clone https://github.com/eyedouble/cl-json-web-tokens.git
git clone https://github.com/luciusmagn/claude-cl.git claude-api
ln -s /path/to/hiisi hiisi
```

### Full Stack (Recommended)
```bash
# Terminal 1: Rust backend
cargo run --release

# Terminal 2: Common Lisp backend (SBCL REPL)
(ql:quickload :hiisi)
(in-package :hiisi)
(main)

# Terminal 3: Reverse proxy
sozu start -c sozu.toml
```

### Common Lisp REPL Shortcuts
```lisp
(start-sozu)                      ; Start proxy
(main)                            ; Start CL server
(unmain)                          ; Stop CL server
(stop-sozu)                       ; Stop proxy
(ql:quickload :hiisi :force t)    ; Reload all code
(load "cl/view/app.lisp")         ; Reload a specific view module
(load-translations)               ; Reload i18n files
```

### Database
```bash
diesel migration run              # Apply migrations
diesel migration generate NAME    # Create new migration
rm hiisi.db && diesel migration run  # Reset database
```

Always run `diesel migration run` after adding or changing migrations.
Never edit `src/schema.rs` by hand; regenerate it via Diesel instead.

## Architecture

### Request Routing (via Sozu)
| Path | Backend | Purpose |
|------|---------|---------|
| `/auth/*` | Rust | Registration, login, activation |
| `/subscribe/*` | Rust | Payments, subscription |
| `/static/*` | Rust | Static assets |
| `/app/*` | Common Lisp | Main app, translations, flashcards |
| `/` | Common Lisp | Landing page |

### Authentication Flow
1. User registers/logs in via Rust backend
2. Rust creates JWT, sets as HTTP-only cookie
3. Both backends share `SECRET` env var, both can verify JWT
4. CL backend serves authenticated routes at `/app`

### Database
- SQLite shared between both backends
- Rust uses Diesel ORM, schema in `src/schema.rs`
- Common Lisp uses Mito ORM, models in `cl/types/`
- Migrations managed by Diesel in `migrations/`
- **CRITICAL**: Never modify existing/old Diesel migration files. Always create a new migration for schema changes.

## Key Directories

| Directory | Contents |
|-----------|----------|
| `src/` | Rust backend (Rocket framework) |
| `src/types/` | Rust domain models (user, translation, bookmark, dislike) |
| `cl/` | Common Lisp backend (Caveman2/Hunchentoot) |
| `cl/types/` | CL domain models (user, translation, bookmark, flashcard, dislike) |
| `ai/` | Claude API prompt templates (system.prompt, example.prompt) |
| `migrations/` | Diesel SQL migrations |
| `i18n/` | Translation data (git submodule) |
| `grammar-terms/` | Grammar term knowledge base data |
| `static/` | Static assets (images/CSS) |
| `logs/` | Runtime logs for both backends |

## Coding Style & Naming Conventions

- **Rust**: Format with `rustfmt` (see `rustfmt.toml`); `snake_case` for vars/functions, `CamelCase` for types
- **Common Lisp**: See detailed Common Lisp Style Guide below

## Common Lisp Style Guide

### Package Structure
- Use specific imports with `:import-from` rather than wholesale `:use`
- Only `:use` core packages (`#:cl`, main framework)
- Import specific symbols (e.g., `(:import-from :anaphora :aif :it)`)

### Formatting & Alignment
**Vertical alignment is mandatory** for readability:

```lisp
;; Slot definitions - align types, accessors, and defaults
(defclass translation-data ()
  ((original   :initarg :original   :accessor original   :type string)
   (translated :initarg :translated :accessor translated :type string)
   (lang--from :initarg :lang--from :accessor lang--from :type string) ; -- is translated to _ in the mito and json thingies
   (forms      :initarg :forms      :accessor forms      :type list)
   (note       :initarg :note       :accessor note       :type string)))

;; Function calls with keyword arguments
(mito:create-dao 'flashcards
                 :user-id             (bookmark-user-id bookmark)
                 :bookmark-id         bookmark-id
                 :last-reviewed-at    nil
                 :next-review-at      nil
                 :ease-factor         2.5
                 :interval-days       0
                 :consecutive-correct 0
                 :created-at          now)

;; Let bindings
(let* ((system-prompt (replace-pairs *system-prompt* replacements))
       (examples      (claude-api:make-text-content *examples*))
       (original-text (claude-api:make-text-content original))
       (message       (claude-api:make-message role contents)))
  ...)
```

### Naming Conventions
- **Constants**: `+snake-case+` (e.g., `+max-input-length+`)
- **Special variables**: `*snake-case*` (e.g., `*app*`, `*translation-retries*`)
- **Functions**: `kebab-case`, entity-prefixed (e.g., `user-find`, `bookmark-create`)
- **Private/internal functions**: `entity--function` (e.g., `translation--retry-generation`)
- **Predicates**: `-p` suffix (e.g., `alistp`, `user-subscribed`)
- **Conversion functions**: `->` infix (e.g., `unix-time->universal-time`)
- **Classes**: Singular lowercase (e.g., `user`, `translation-data`)
- **Database tables**: Plural lowercase (e.g., `users`, `translations`)
- **Accessors**: Prefix with entity name (e.g., `user-id`, `card-original`)
- No abbreviations in identifiers, following modern lisp tradition and readability
- Prefer `(first ...)` and `(rest ...)` over `(car ...)` and `(cdr ...)` in application code.

### Type System
Always declare types using Serapeum's `->` notation:
```lisp
(-> function-name (input-types) output-type)
(-> user-find (number) users)
(-> language-parse ((option string)) (option language))
(-> setup-db () boolean)
```

Custom type definitions for clarity:
```lisp
(deftype option (inner-type)
  `(or null ,inner-type))
(deftype list-of (element-type)
  `(serapeum:soft-list-of ,element-type))
```

You can add these, but keep them in one place (e.g. types.lisp)

### Documentation Structure
```lisp
;;;; -- Major Section --
;;; Minor section
;; Regular comment
; Inline comment (rare)

(defun function (&key args)
  "Brief description of what function does.
   Additional details if needed."
  ...)

(define-condition my-condition ()
  ()
  (:documentation "What this condition represents")
  (:report (lambda (condition stream)
             (format stream "Human-readable error: ~A"
                     (slot condition)))))
```

Always use documentation strings and documentation slots

### Code Organization
1. File structure:
   - Package definition (only one package per project unless stated otherwise)
   - Types/classes
   - Generic function declarations
   - Method implementations
   - Functions (public then private)
   - Conditions

2. Within sections: Group by functionality, not alphabetically

### Database Patterns
Consistent CRUD naming:
- `entity-find` - single record by ID
- `entity-create` - create new record
- `entity-update` - update existing
- `entity-delete` - delete record
- `entity-by-*` - scoped queries
- `entity-fetch-*` - complex retrievals

Always validate foreign keys before operations.

We use mito from fukamachi. If a query is too long and could be difficult to express in mito, just rawdog the SQL string.

### Error Handling
- Define domain-specific conditions
- Use structured error data
- Provide helpful `:report` functions
- Use `handler-case` for expected errors
- Early returns with `(block nil ... (return ...))`

### Macros
- `with-` prefix for context/resource macros
- Use gensyms or `block` names to avoid capture
- Document macro expansion behavior
- Prefer functions when possible

### Return Values
- Boolean functions return exactly `t` or `nil`
- Use `(values)` for multiple returns
- Document return types with `->`

### Spacing
- One blank line between function definitions
- Two blank lines between major sections
- No trailing whitespace
- Consistent indentation (2 spaces)
- In conditional branch clauses, put the branch body on a new line:
```lisp
;; BAD
((null row) nil)

;; GOOD
((null row)
 nil)
```
- In `(labels ...)`, keep an empty line between local function definitions:
```lisp
(labels ((first-helper ()
           ...)

         (second-helper ()
           ...))
  ...)
```

### Anaphoric Style
Use anaphora when it improves readability:
```lisp
(aif (find-thing)
     (process it)
     (handle-not-found))
```

This requires the :anaphora dependency. If you do not already see usage of aif and similar or the dependency already added, ask the user if we can add this, if you feel it is needed.

### HTML Generation
Use HSX with semantic structure:
```lisp
(hsx
  (<>  ; Fragment for multiple elements
    (div :class "semantic-class-names"
      content)))
```

### Approach to solutions

Prefer stupid, established, readable solutions over overly smart ones. We can all hallucinate stuff. Solutions should be reasonably generic, and code should be reasonably stratified (no unreadable low-level diddling in business logic functions). Prefer smaller functions, that are easier to document, even at the cost they may only be used once. Use OOP in Common Lisp as applicable.

This style emphasizes **clarity**, **consistency**, and **semantic naming**. Code should be self-documenting, with types and formatting that make intent obvious.

When generating code, do not abbreviate and insert todos unless the user asks you to.

Never use any em-dashes anywhere.

## Feature Implementation Patterns

### Adding a Rust endpoint
1. Add route in `src/main.rs`
2. Add view template in `src/views.rs` (uses Maud)
3. Add/modify types in `src/types/`

### Adding a CL endpoint
1. Add route in the appropriate file under `cl/view/` (uses HSX for HTML)
2. Add API logic in `cl/api.lisp` if needed
3. Add/modify models in `cl/types/`

### Adding a database table
1. `diesel migration generate table_name`
2. Write SQL in `migrations/*/up.sql` and `down.sql`
3. `diesel migration run`
4. Add Rust model in `src/types/` with Diesel derives
5. Add CL model in `cl/types/` with Mito class definition

## Key Technologies

- **Frontend**: Shoelace web components, HTMX, HyperScript, Pico CSS
- **HTML templating**: Maud (Rust), Shoelace-HSX (CL)
- **AI**: Claude API via `claude-api` Quicklisp package
- **Email**: Mailgun API (`src/email.rs`)
- **Spaced repetition**: SM-2 algorithm in `cl/types/flashcard.lisp`

### UI Visual Rules

- No rounded corners anywhere, including emails. Buttons, cards, inputs, and containers should use sharp corners.

### Shoelace-HSX Templating Pattern

When using control flow (`when`, `if`, `mapcar`, `loop`) inside a `shoelace-hsx` template to generate nested HTML, the inner template must be wrapped in its own `(shoelace-hsx ...)` call:

```lisp
;; CORRECT - inner mapcar wrapped in shoelace-hsx
(shoelace-hsx
 (ul
   (mapcar (lambda (item)
             (shoelace-hsx
              (li (name item))))
           items)))

;; WRONG - will not render correctly
(shoelace-hsx
 (ul
   (mapcar (lambda (item)
             (li (name item)))  ; Missing shoelace-hsx wrapper!
           items)))
```

This applies to `mapcar`, `loop ... collect`, `when`, `if`, and any other construct that returns HTML elements within a template.

### Shoelace sl-select Quirk

When using `sl-select` with `sl-option` children, you must include an empty string `""` as the first child before the options. Otherwise, the first option will be broken/invisible:

```lisp
;; CORRECT - empty string before options
(sl-select :name "lang-to" :label "Target" :required
  ""
  (sl-option :value "EN" "English")
  (sl-option :value "CS" "Czech"))

;; WRONG - first option will be broken
(sl-select :name "lang-to" :label "Target" :required
  (sl-option :value "EN" "English")
  (sl-option :value "CS" "Czech"))
```

This is a quirk of how Shoelace-HSX renders the component.

### Shoelace Form Data with HTMX

Shoelace form elements (`sl-input`, `sl-select`, `sl-textarea`) don't work with standard HTML form serialization. HTMX's `hx-vals` attribute is also unreliable with Shoelace components.

**Most reliable approach**: Use hidden `<input>` elements with explicit IDs and `hx-include` by ID:

```lisp
;; MOST RELIABLE - hidden inputs with explicit IDs
(input :type "hidden" :id "data-id" :name "item_id" :value item-id)
(input :type "hidden" :id "data-val" :name "item_val" :value some-value)
(sl-button :hx-post "/api/endpoint"
  :hx-include "#data-id, #data-val"
  :hx-target "#result"
  "Submit")
```

**Alternative for forms**: Use `closest sl-form, closest form` for Shoelace form inputs:

```lisp
;; OK for sl-input/sl-select inside sl-form
(sl-button :hx-post "/api/endpoint"
  :hx-include "closest sl-form, closest form"
  :hx-target "#result"
  "Submit")
```

**Avoid**: Don't use `hx-vals` with Shoelace components - the JSON values often don't get captured:

```lisp
;; UNRELIABLE - hx-vals doesn't work reliably with Shoelace
(sl-button :hx-post "/api/endpoint"
  :hx-vals "{\"key\": \"value\"}"  ; Often fails!
  "Submit")
```

See `cl/types/translation.lisp` bookmark button for the hidden input pattern.

### Redirects
Use the universal redirect helpers so both HTMX and regular browser requests work.

Common Lisp:
```lisp
;; Works for both HTMX (HX-Redirect header) and regular requests (303 redirect)
(universal-redirect "/target/path")
```

Rust:
- Use `UniversalRedirect` when you need to redirect from a handler so HTMX gets `HX-Redirect`.

### Type Definitions in Common Lisp

When defining custom types, **never use weak type aliases** that just expand to `list` or other generic types. Always use `(satisfies predicate-fn)` to actually validate the structure:

```lisp
;; WRONG - weak alias, no validation
(deftype plist ()
  'list)

;; CORRECT - validates structure
(defun plistp (x)
  (and (listp x)
       (evenp (length x))
       (loop for (key val) on x by #'cddr
             always (keywordp key))))

(deftype plist ()
  '(satisfies plistp))
```

See `cl/util.lisp` for existing `alistp`/`alist` and `plistp`/`plist` type definitions.

### Mito ORM Accessors

**Never use `mito:object-id`** to access the ID of a Mito DAO object. Mito does not automatically generate this method. Instead, use the model-specific accessor defined in the class:

```lisp
;; WRONG - mito:object-id is not implemented
(mito:object-id user)

;; CORRECT - use the accessor from the class definition
(user-id user)
```

Each model in `cl/types/` has its own ID accessor (e.g., `user-id`, `translation-id`, `bookmark-id`).

### Mito Boolean Filtering

When using `mito:count-dao`, `mito:select-dao`, or similar filtering functions, filter boolean fields with `1` and `0`, not `t` and `nil`. SQLite stores booleans as integers.

```lisp
;; WRONG - t causes exception, nil matches NULL/empty fields
(mito:count-dao 'user :activated t)
(mito:count-dao 'user :activated nil)

;; CORRECT - use integers
(mito:count-dao 'user :activated 1)
(mito:count-dao 'user :activated 0)
```

### Redirects in Common Lisp

Use `universal-redirect` for all redirects. It handles both HTMX and regular browser requests automatically:

```lisp
;; Works for both HTMX (HX-Redirect header) and regular requests (303 redirect)
(universal-redirect "/target/path")
```

See `cl/util.lisp` for the implementation.

## Environment Variables

```bash
DATABASE_URL=hiisi.db
SECRET=<jwt-shared-secret>
ANTHROPIC_KEY=<claude-api-key>
BASE_URL=https://yourdomain.com  # Used in emails, defaults to http://localhost:8888
ADMIN_PASSWORD=<admin-password>  # Defaults to S0esW04cMoa8
MAILGUN_API_KEY=<key>
MAILGUN_DOMAIN=<domain>
MAILGUN_FROM=<from-email>
SERVICE_EMAIL=me@mag.wiki  # Test/sample emails and admin notifications
EMAIL_PREVIEW_TO=          # BCC all emails to this address
POLAR_WEBHOOK_SECRET=<polar-webhook-secret>
POLAR_PRODUCT_ID_MONTHLY=<product-id>
POLAR_PRODUCT_ID_ANNUAL=<product-id>
```

## Logs

- Rust: `logs/hiisi.log.YYYY-MM-DD`
- Common Lisp: `logs/hiisi-cl.log.YYYY-MM-DD`

## Documentation

- `README.org` - Setup instructions and development workflow
- `docs/hiisi-spec.org` - Full project specification, architecture details, and TODO list
- `PLAN.md` - Development roadmap and business plan

## Testing

### Automated Tests
```bash
# Rust tests (use --release due to cranelift dev backend)
cargo test --release

# Common Lisp: load system and run tests
./check-lisp

# Full environment check (Recommended)
nix flake check
```

**Always run `./check-lisp` after modifying Common Lisp code** to verify the system loads without compilation errors and all tests pass.

**Permission note**: You do not need to ask before running `cargo test --release` or `./check-lisp` after making code changes. After you make a change and run tests, always commit and push the changes.

### Paren Check Tool

The `tools/paren-check` tool validates Lisp code before loading:

```bash
# Build and run
rustc tools/paren-check.rs -o tools/paren-check
./tools/paren-check cl

# Or use via check-lisp (runs automatically before loading)
./check-lisp
```

This tool detects:
- Unbalanced parentheses (file-level count)
- Missing closing parens (based on indentation analysis)
- Extra closing parens (negative balance detection)

It ignores parens inside strings and comments. Always ensure this passes before attempting to load Lisp code.

### Manual Testing Flow
1. Register at `/auth/register`
2. Check logs for activation link (email in development)
3. Activate via `/auth/api/activate/TOKEN`
4. Login at `/auth/login`
5. Access app at `/app`

### API Testing Example
```bash
curl -X POST http://localhost:8888/app/api/translate \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "original=Hello world&lang-to=FI" \
  --cookie "token=YOUR_JWT_TOKEN"
```

## Troubleshooting

### Clean Reset
```bash
pkill -f sozu
pkill -f hiisi
pkill -f sbcl
cargo clean
cargo build --release
rm hiisi.db
diesel migration run
```

## Security Notes

- Use a strong JWT secret (minimum 32 characters)
- Configure Mailgun and Polar.sh webhooks for production

## Known Issues

None currently tracked.
