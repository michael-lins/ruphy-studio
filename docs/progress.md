# Milestones and verification

## Partial editing and one-level undo — completed 2026-09-14

The Customer page now renders `customers/_form.html.erb`. The resident targets
that explicitly configured partial and leaves its caller untouched. The latest
successful edit can be undone through Ruphino if source revision and change ID
still match. No automatic discovery, multi-level history or redo is implemented.

Verification on the environment recorded below:

- Test-first partial increment: two expected failures, then 19 tests / 59 assertions passed.
- Test-first undo increment: five expected missing-undo errors, then passing tests;
  final suite including socket undo: **24 tests / 86 assertions, no failures, errors or skips**.
- Tests verify exact undo bytes (including Unicode and CRLF), file mode, reverse
  Herb diff, consumed history, stale IDs, external source edits, latest-only undo,
  no-op/failure preservation and restart behavior. A separate resident handles
  both edit and undo through the same mutation transport.
- Browser: selected Name, changed its placeholder to `Full name from partial`,
  observed reload and `attribute_value_changed`, then clicked **Undo last edit**.
  The original placeholder returned, undo became disabled, and no console errors
  were reported. Byte comparisons confirmed that the partial was restored exactly
  and the caller stayed unchanged throughout.

These results extend the first proof below. Undo shares the existing final
compare/rename race limitation; see [decisions](decisions.md#one-level-undo).

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
6. Inspect `examples/customer/app/views/customers/_form.html.erb`: only the selected
   placeholder's contents should change. Confirm the saved file parses:

```sh
mise exec -- bundle exec ruby -rherb -e 'result = Herb.parse(File.read("examples/customer/app/views/customers/_form.html.erb")); abort result.errors.map(&:message).join("\n") unless result.errors.empty?; puts "ERB valid"'
```

7. Click **Undo last edit** in Ruphino. Confirm reload, the original placeholder,
   a reverse `attribute_value_changed` diff and a disabled Undo button.
8. Compare the partial with its starting contents and confirm `new.html.erb` is
   unchanged. Automated tests additionally assert byte-for-byte restoration.

This exercise writes to the example partial. Undo before restarting the resident:
source edits survive a restart, but undo history and the last diff do not.

## What the first milestone established

Browser action → structured mutation → Herb selection → deterministic ERB edit
→ reparse and postcondition → Herb diff → source write → Rails reload.

The first milestone covered one fixed view and two literal inputs. It did not
establish partial editing, general DOM-to-source mapping, undo or arbitrary visual
editing. Partial editing and undo are covered by the later milestone above;
automatic discovery remains unsupported. Reload can lose form state, and an external editor can still race the
final source comparison and rename. See [decisions](decisions.md) for boundaries
and [Herb research](herb-research.md) for the API evidence.
