# Herb capabilities used by Ruphy

Source inspection dated 2026-09-14, pinned to Herb main commit
`d36f73737f43b7306f561efa32283b89e3b39c6f`. Runtime verification used the released
Herb 0.10.3 native gem (libherb 0.10.3, libprism 1.9.0). Main-only APIs are not
assumed to exist in that release. See [verification](progress.md) and
[architecture decisions](decisions.md).

## Parsing, locations and diffing

| Capability | Verified source contract | Ruphy use |
| --- | --- | --- |
| `Herb.parse(source, **options)` | [Ruby wrapper][ruby] delegates to the [native backend][native]; `ParseResult` exposes the tree and errors | Parse original and candidate with whitespace tracking; reject parse errors |
| AST traversal | [Node][node] exposes child nodes and locations; [ParseResult][parse] includes recursive errors | Find a unique literal input and its quoted placeholder |
| Source coordinates | [Ruby reference][reference] and [lexer][lexer] distinguish character columns from byte positions; lines are one-based, columns zero-based and ends exclusive | Convert locations to UTF-8 character offsets; preserve unrelated source and line endings |
| `Herb.diff(old, new)` | [Result][diff-result] contains operations with type, path, old/new nodes and indices; [tests][diff-tests] demonstrate attribute, text and structural changes | Require an identical diff or one `attribute_value_changed`; report the real diff |

`Herb.parse_ruby` wraps Prism for Ruby code; HTML+ERB uses `Herb.parse`. AST paths
are structural source paths, not browser DOM identity. The POC's tests cover
Unicode (including astral characters), CRLF and actual attribute diffs.

## Rewriting gap in the Ruby binding

The supported TypeScript [rewriter][rewriter] offers `ASTRewriter`,
`StringRewriter`, `rewrite` and `rewriteString`. Its [implementation][rewrite]
applies transformations and prints through `IdentityPrinter`. It catches
individual rewriter errors, and `rewriteString` returns unchanged input on parse
failure; returned output alone does not establish a successful mutation.

No equivalent Ruby source-rewriter/identity-printer API was found in the inspected
Ruby implementation. Ruphy therefore edits the inner source range of one literal
attribute, then reparses and checks the result. This is a Ruby binding gap, not
an absence of rewriting across Herb. A small Ruby source-edit/identity-print API
is a [candidate upstream contribution](decisions.md#candidate-upstream-herb-contribution).

## Dev server and browser patching

The [dev-server overview][dev] describes file watching, WebSocket updates,
patching and reload fallback, and labels the server experimental. At the pinned
revision, [Classifier][classifier] reparses and diffs sources, while
[Pipeline][pipeline] also tracks compiler versions, manifests and diagnostics.
The browser [hot-reload implementation][hot-reload] distinguishes missing
runtime, regions, slots, server mode and standalone operation.

Starting `herb dev` alone does not establish arbitrary Rails DOM patching.
Ruphy's first proof uses a full Rails reload and exposes Herb's diff for inspection;
it does not require ReActionView or replace the Rails rendering engine.

## Render graph

[RenderGraph][graph] tracks callers, roots, unresolved renders and skipped files;
`complete?` reports incomplete analysis. Its [Builder][builder] consumes a partial
index and parses with render-node, Prism-node and Action View helper options.
This is static render analysis, not universal runtime DOM-to-source provenance.
The single-view POC does not integrate it.

## Relevant upstream issues

These issues were inspected on 2026-09-14; their current status may differ.

- [#1615](https://github.com/marcoroth/herb/issues/1615): helper rewriting can have nontrivial output semantics. Literal attribute edits avoid that conversion.
- [#2215](https://github.com/marcoroth/herb/issues/2215): embedded JavaScript linting explores binding boundaries; it does not establish a supported Ruby source rewriter.
- [#2294](https://github.com/marcoroth/herb/issues/2294): multi-root view resolution matters before expanding static render analysis to arbitrary Rails projects.
- [#2352](https://github.com/marcoroth/herb/issues/2352): generated Ruby line preservation reinforces the distinction between source and compiled locations.

[ruby]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb.rb
[native]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/ext/herb/extension.c
[node]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/ast/node.rb
[parse]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/parse_result.rb
[reference]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/docs/docs/bindings/ruby/reference.md
[lexer]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/src/lexer.c
[diff-result]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/diff/result.rb
[diff-tests]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/test/diff/diff_test.rb
[rewriter]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/rewriter/README.md
[rewrite]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/rewriter/src/rewrite.ts
[dev]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/docs/docs/projects/dev-server.md
[classifier]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/dev/classifier.rb
[pipeline]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/dev/pipeline.rb
[hot-reload]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/dev-tools/src/dev-server/hot-reload.ts
[graph]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/analysis/render_graph.rb
[builder]: https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/analysis/render_graph/builder.rb
