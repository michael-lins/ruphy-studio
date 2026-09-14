# Ruphy Studio decisions

## Scope — 2026-09-14

The desktop companion originally aimed to guide developers through Ruby/Rails
setup, similar to a traditional installation wizard. The current design keeps that
product intent without retaining the Glimmer implementation. No desktop framework
or installer is selected in this POC; mise handles its current development setup.
See [earlier experiments](history.md) for the architectural background.

## Rails page, gem, resident

The Customer page is an actual Rails-rendered view with an ERB heading and literal
name/email inputs. No separate designer canvas, database, or component model.

A local path gem installs a Railtie middleware only in development. It injects
Ruphino into the HTML response; it does not rewrite application layouts or
routes. JavaScript and mascot assets are served by the gem. Browser controls use
plain JavaScript and a shadow root for style isolation.

A separate Ruby process owns the fixed view, revision checks, mutation ordering
and last diff. The Rails adapter forwards bounded JSON messages over a local
Unix socket. No extra HTTP/WebSocket framework or Node runtime is needed. The
transport currently targets macOS/Linux. This is a deliberate local POC limit.

## One mutation and explicit target identity

`set_placeholder` accepts only target, value, operation and revision. Targets are
`customer_name` and `customer_email` in one server-owned view path. HTML IDs are
explicit POC source-to-DOM identity; there is no claim of general render
provenance. Repeated/conditional targets, dynamic attributes and unsupported
source structures are rejected. Values are escaped as HTML text before insertion.

The browser keeps the source revision captured before the Rails render. A stale
page cannot silently retarget a newer file. Local, same-origin JSON checks guard
the development mutation endpoint; there is no authentication subsystem.

## Herb API choice and source safety

Inspected main: `d36f73737f43b7306f561efa32283b89e3b39c6f`.
Executed version: official `herb` 0.10.3 arm64-darwin gem, with libherb 0.10.3 and
libprism 1.9.0. Using a pinned release avoids making main's unreleased APIs a
runtime requirement. The installed release's parsing, AST traversal/locations and
`Herb.diff` were verified in the [first milestone](progress.md). Pinned source
references are in [Herb research](herb-research.md).

Herb provides supported TypeScript rewriting backed by IdentityPrinter. No
corresponding Ruby source-rewriter/identity-printer API was found. The selected
fallback edits only the inner range of a structurally selected, quoted,
literal placeholder. Herb character positions are converted to Ruby UTF-8
character offsets; unrelated bytes, line endings and quote style are preserved.
No regex edits ERB.

Original and candidate must parse without Herb errors. The candidate's target
value is checked and its real Herb diff must be identical or one
`attribute_value_changed`. Source hashes and repeated source comparisons detect
stale or intervening edits. A same-directory temporary file is flushed and
atomically renamed, preserving file mode. Mutations are serialized by the
resident. A non-cooperating external editor can still race the last comparison
and rename; multi-writer filesystem transactions are outside this proof.

## Browser refresh and render graph

Successful source changes trigger a full Rails page reload; the last Herb diff is
available in Ruphino after reload. No-op operations do not reload. Reload can
lose form input state. The resident's last-change record is in memory and resets
on process restart.

Herb AST paths are not interpreted as DOM paths. Current Herb browser patching
uses runtime/compiler metadata, regions and slots. No ReActionView or renderer
replacement is introduced. Render-graph APIs were inspected but are deferred for
a single fixed view. Static graph completeness is not general runtime provenance.

## Tooling

`mise.toml` pins Ruby 3.4.9 and provides setup/test/dev tasks. The bundle pins
Rails 8.1.3 railties/actionpack, Puma 7.0.4 and Herb 0.10.3 for reproducibility.
Gems and caches stay in ignored local directories. The toy app uses Rails-specific
defaults; core source mutation code has no Rails API dependency.

## Candidate upstream Herb contribution

A Ruby source-edit/identity-print facility equivalent in purpose to the existing
TypeScript rewriter would spare Ruby consumers from implementing range edits.
A minimal proposal should cover explicit coordinate semantics, expected-source
checks, non-overlapping edits, preservation of untouched bytes and reparsing
examples. This remains a candidate: no upstream issue or patch has been sent,
and no general-purpose Ruphy rewriting subsystem has been built.
