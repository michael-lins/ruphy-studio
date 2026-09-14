# Ruphy Studio progress

## 2026-09-14 — Completed first end-to-end proof

Branch: `feature/herb-rad-poc`, based on main `b333b47`.

### Inspection before coding

- Inspected main and all five historical/POC branches. Findings: `docs/history.md`.
- Inspected Herb main commit `d36f73737f43b7306f561efa32283b89e3b39c6f`, docs,
  examples, relevant issues, Ruby/native APIs, locations, rewriting, diffing,
  dev server, browser patching and render graph. Sources: `docs/herb-research.md`.
- Verified actual installed Herb 0.10.3 parsing/AST/diff APIs before implementing.

### Implemented

- Real Rails 8 Customer form, with name/email inputs and a rendered ERB heading.
- Local development-only Ruphy gem injects browser controls into rendered HTML.
- Separate resident Ruby process owns state and mutation processing over a Unix socket.
- One structured mutation: select a literal input and change its placeholder.
- Herb-based structural selection; deterministic source-location edit; candidate
  reparse and postcondition; actual Herb diff; atomic write; browser reload.
- mise configuration and setup/test/dev tasks, README and decisions documentation.
- Removed active desktop-shell code; reused only the Ruphino image.

### Commands and results

- `mise exec -- ruby -v`: Ruby 3.4.9, arm64-darwin25.
- `mise exec -- gem install herb -v 0.10.3 --no-document`: installed the official
  native gem into the workspace-local gem directory.
- `mise exec -- bundle check`: dependencies satisfied.
- `mise run setup`: success; 5 Gemfile dependencies, 48 gems available to bundle.
- `mise run test`: **17 runs, 50 assertions, 0 failures, 0 errors, 0 skips**.
- `git diff --check`: passed.
- `mise run dev`: resident and Puma started; Rails served on 127.0.0.1:3000.
- Herb reparsed the actual edited Customer view without errors.
- Browser console inspection: no errors.

Tests cover exact source preservation, Unicode before ranges (including astral
characters), CRLF, HTML/ERB escaping, empty and unchanged values, stale revisions,
external changes during validation, duplicate/entity-equivalent IDs, dynamic and
conditional targets, malformed source, unquoted/missing placeholders, symlink
rejection, unknown operations, unavailable resident and middleware origin checks.
A separate-process socket test sends two competing mutations at the same revision:
one succeeds and the other returns 409. Separate Rails boots confirm the middleware
is present in development and absent in test and production.

The first test run exposed a missing `rack/request` require; this was fixed.
Initial Rails HTTP inspection exposed the minimal controller's missing explicit
application layout; this was fixed before the browser proof. Rack mock requests
emit a Ruby future-frozen-string warning, but all assertions pass.

### Browser proof (real UI actions)

1. Opened the running Rails page in the browser; saw the rendered New customer heading.
2. Opened the injected Ruphino mascot controls.
3. Clicked the actual Name input on the Rails page.
4. Changed its placeholder from `Full name` to `Customer full name` and clicked
   **Apply to Rails view**.
5. Observed browser navigation/reload and read the new placeholder from the DOM.
6. Opened **Last Herb diff** and verified `attribute_value_changed` at path `[0,7,3,3]`.
7. Read the real file and resident state; reparsed the saved ERB with Herb.

Recorded first mutation revisions:

- Before: `051634150fcd28a58895aa6e2b0409c136d80837d8c3ef165d8fca3716157f94`
- After: `5a9aea1a4bef208ac98633727c64188adf66d90fa87a184fbbea5480101398a4`

These are source hashes, not Git commits. The observed diff is produced by
`Herb.diff`, not a text diff. AST paths are retained as evidence only.

### Scope and limitations

No AI generation, React, component DSL, ViewComponent, Phlex, authentication,
packaging/publishing, production integration, generic DOM patcher or general
render-provenance system. One fixed view and two literal IDs only. Full reload
may lose input state. Resident history is in memory. Non-cooperating external
editors can race the final compare/rename interval. See decisions for details.

### Final restart check

Stopped the supervisor gracefully and restarted with `mise run dev`; both child
processes restarted and the Rails page loaded successfully. The existing-socket
guard also refused an attempted second owner. Final saved source reparsed with
Herb successfully and `git diff --check` remained clean. The resident's last diff
correctly resets on restart; source edits persist on disk.

A later Email placeholder value `name@example.com!` was observed and preserved;
the first mutation hashes above remain historical evidence, not a claim about
the final file hash. The demo is left running for inspection. Work is local on
`feature/herb-rad-poc`; no commit, push, or upstream issue was created.

### Follow-up: remove obsolete desktop remnants

Removed the unused root mascot copy (SHA-256 matched the active gem asset), empty desktop directories and old
frontend/desktop ignore rules. Documented the companion's original guided
Ruby/Rails setup purpose without selecting another desktop framework.
Historical research remains as an audit record.

Verification: `mise run test` passed again (17 runs, 50 assertions); `git diff
--check` passed. Searches found no Glimmer/JRuby/SWT/Tauri/Wails/qdns or removed
asset/entry-point references in active code, dependencies or mise configuration.
`git check-ignore` confirms local gems, caches and runtime sockets remain ignored.
