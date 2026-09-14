# Ruphy Studio

A small Herb-based RAD experiment: the running Rails page is the visual canvas.

Open Ruphino, click a Customer form field, and change its placeholder. The
development-only Ruphy gem sends a structured mutation to a resident Ruby
process. Herb locates the input in the real ERB, validates the candidate, and
computes its structural diff. The file is saved and Rails reloads in the browser.

Ruphy's broader aim is a straightforward Ruby/Rails development experience,
including guided setup like the installation wizards of earlier desktop tools.
The original desktop companion explored that onboarding role using Glimmer.
That goal remains relevant; a desktop toolkit or installer is not part of this
Rails/Herb proof. For now, mise provides the reproducible development setup.

## Run

Ruby and tooling are managed by [mise](https://mise.jdx.dev/). The experiment pins
Ruby 3.4.9, Rails 8.1.3's railties/actionpack, Puma 7.0.4 and Herb 0.10.3.
Gems and gem caches stay inside the ignored `vendor/` directories.

```sh
mise trust
mise install
mise run setup
mise run test
mise run dev
```

Visit http://127.0.0.1:3000. Click the Ruphino mascot at bottom right, then click
Name or Email in the actual Rails form. Enter a placeholder and click **Apply to
Rails view**. After reload, open Ruphino to inspect **Last Herb diff**.

`mise run dev` starts and supervises both the resident process and Rails. Ctrl-C
stops both. Use `PORT=3001 mise run dev` to choose another Rails port. A second
resident for the same socket is refused. If a hard kill leaves
`examples/customer/tmp/ruphy.sock`, verify its owner is gone before removing it.

## Code map

- `examples/customer/`: tiny Rails app; no database or asset pipeline.
- `gems/ruphy/lib/ruphy.rb`: development-only Railtie injection.
- `gems/ruphy/lib/ruphy/assets/ruphino.js`: browser controls over the live page.
- `gems/ruphy/lib/ruphy/project.rb`: Herb traversal, range edit, validation, diff and write.
- `gems/ruphy/lib/ruphy/resident.rb`: resident owner, JSON over a local Unix socket.
- `test/poc_test.rb`: source preservation, rejection cases and middleware tests.

The only editable source is `examples/customer/app/views/customers/new.html.erb`.
The only operation is `set_placeholder` on its two uniquely identified literal
inputs. The gem loads through a local path in the development group; no gem
publication or packaging workflow is involved.

## Boundaries

Herb main was inspected separately from the pinned released gem running this
proof. Ruby exposes parsing and diffing; its source-location edit fallback is
used because no equivalent of Herb's TypeScript rewriter was found in Ruby.

The browser reloads; it does not apply Herb AST paths directly to the DOM. Input
state can be lost on reload. Dynamic attributes, repeated/conditional inputs,
arbitrary views and mutations are unsupported. An unavailable resident leaves
Rails usable and displays an error in Ruphino.

The socket transport targets local macOS/Linux development. The resident rejects
stale revisions and checks the source before an atomic rename; an external editor
that writes in the final check-to-rename interval is still a race. This is a
single-owner POC, not a general collaborative editor.

See [decisions](docs/decisions.md), [verification results](docs/progress.md),
[Herb source research](docs/herb-research.md), and [historical POCs](docs/history.md).
