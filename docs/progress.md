# Milestones and verification

## First Rails/Herb editing loop — completed 2026-09-14

Implemented in commit `6bad733`. The actual Rails page is the canvas; a
development-only gem connects Ruphino to a resident Ruby process that edits one
real ERB view through Herb. The supported operation changes the placeholder of
`customer_name` or `customer_email`.

Recorded verification environment: Ruby 3.4.9 on arm64-darwin25, Rails 8.1.3,
Puma 7.0.4, Herb/libherb 0.10.3 and libprism 1.9.0.

| Check | Recorded result |
| --- | --- |
| `mise run setup` | Bundle installed successfully |
| `mise run test` | 17 runs, 50 assertions, no failures, errors or skips |
| Browser editing loop | Selected Name, changed its placeholder, observed reload and the new DOM value |
| Source and diff | Saved ERB reparsed successfully; Herb reported one `attribute_value_changed` |
| Browser console | No errors observed during the proof |
| Process lifecycle | Graceful stop/restart succeeded; a second socket owner was refused |

These are dated results, not claims that a server is currently running or that
later revisions have been tested. Rack mock requests emitted a Ruby
future-frozen-string warning without failing the suite.

## Reproduce automated verification

From the repository root, follow the [setup instructions](../README.md#run), then:

```sh
mise run test
```

The [test suite](../test/poc_test.rb) covers source preservation, Unicode and CRLF,
HTML/ERB escaping, empty/no-op edits, stale revisions, intervening file changes,
ambiguous IDs (including entity-equivalent IDs), dynamic/conditional targets,
malformed source, missing/unquoted placeholders, symlinks and unsupported requests.
It also checks middleware failures and origin restrictions, competing requests to
a separate resident process, and Rails boots in development, test and production.

## Reproduce the browser proof

1. Run `mise run dev` and visit http://127.0.0.1:3000.
2. Open Ruphino and click the Name field on the actual Customer form.
3. Note its original placeholder, enter a different value and click **Apply to Rails view**.
4. Confirm that the page reloads and the field displays the new placeholder.
5. Open **Last Herb diff**: expect one `attribute_value_changed` operation. Its
   AST path depends on source structure; it is not a stable DOM identifier.
6. Inspect `examples/customer/app/views/customers/new.html.erb`: only the selected
   placeholder's contents should change. Confirm the saved file parses:

```sh
mise exec -- bundle exec ruby -rherb -e 'result = Herb.parse(File.read("examples/customer/app/views/customers/new.html.erb")); abort result.errors.map(&:message).join("\n") unless result.errors.empty?; puts "ERB valid"'
```

This exercise writes to the example view. Restore the original placeholder
through Ruphino when finished. Source edits survive a process restart; the
resident's in-memory last diff does not.

## What this milestone establishes

Browser action → structured mutation → Herb selection → deterministic ERB edit
→ reparse and postcondition → Herb diff → source write → Rails reload.

This proof covers one fixed view and two literal inputs. It does not establish
partial discovery, general DOM-to-source mapping, undo or arbitrary visual
editing. Reload can lose form state, and an external editor can still race the
final source comparison and rename. See [decisions](decisions.md) for boundaries
and [Herb research](herb-research.md) for the API evidence.
