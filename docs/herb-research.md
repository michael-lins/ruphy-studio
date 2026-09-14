# Herb source inspection

Inspected on 2026-09-14 at main commit `d36f73737f43b7306f561efa32283b89e3b39c6f`. Claims below describe source inspection, not a runtime compatibility guarantee for a released gem.

## Ruby parsing and AST

[`lib/herb.rb`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb.rb) defines `Herb.parse(source, **options)` and delegates to `Backend.parse`. [`ext/herb/extension.c`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/ext/herb/extension.c) registers the native parse and diff entry points. `Herb.parse_ruby(source)` is a separate Prism wrapper; it does not parse HTML+ERB.

[`ParseResult`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/parse_result.rb) exposes `value`, `options`, `errors`, `visit`, and `locate`. Its errors include recursive AST errors. [`AST::Node`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/ast/node.rb) exposes `location`, `child_nodes`, and `compact_child_nodes`. Use the actual classes/traversal, not pattern matching on ERB text.

The [Ruby reference](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/docs/docs/bindings/ruby/reference.md) includes parser, visitor, and locate examples. Locations have one-based lines, zero-based character columns and exclusive ends. [`src/lexer.c`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/src/lexer.c) advances byte positions separately from UTF-8 character columns. Tokens also expose a range; nodes expose locations. Do not interchange character columns, byte offsets, and browser UTF-16 offsets. Runtime tests must cover non-ASCII text before a selected attribute and CRLF input.

## Rewriting/mutation

The supported [`@herb-tools/rewriter`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/rewriter/README.md) offers `ASTRewriter`, `StringRewriter`, `rewrite`, and `rewriteString`, with concrete examples. [`rewrite.ts`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/rewriter/src/rewrite.ts) applies transformations and calls `IdentityPrinter.print`. It catches individual rewriter errors; `rewriteString` returns the original input on parse failure. Callers must not equate returned output with successful mutation.

No equivalent Ruby source-rewriter/identity-printer interface was found in `lib/` or the Ruby public wrapper. This is a binding-specific gap, not a claim that Herb lacks rewriting altogether. For the proposed Ruby process, use a small deterministic source-location edit and independently validate its result. Do not introduce a JS bridge without revisiting dependency scope.

## Diff

[`Herb.diff`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb.rb) takes two source strings, optionally `track_whitespace_changes:`, and returns `Herb::Diff::Result`. [`Result`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/diff/result.rb) exposes `identical?`, `changed?`, `operations`, and `operation_count`. Operations carry type, AST path, old/new nodes, and indices.

[`test/diff/diff_test.rb`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/test/diff/diff_test.rb) demonstrates `:attribute_value_changed`, `:text_changed`, insertion/removal, moves and ERB changes. Compute this actual diff; do not substitute a text diff labeled as Herb. AST paths do not establish rendered DOM identity.

## Dev server and browser

The [dev-server documentation](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/docs/docs/projects/dev-server.md) describes `herb dev`, file watching, WebSocket messages, patching and reload fallback, and marks the server experimental.

Current implementation is richer than that overview: [`Classifier`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/dev/classifier.rb) reparses and computes Herb diff; [`Pipeline`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/dev/pipeline.rb) tracks versions, manifests and diagnostics, using an optional compiler. Browser [`hot-reload.ts`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/javascript/packages/dev-tools/src/dev-server/hot-reload.ts) explicitly distinguishes missing runtime, regions, slots, server mode, and standalone operation. Therefore merely starting `herb dev` does not prove arbitrary Rails DOM patching.

For the first POC, return the computed diff to Ruphino for visibility and reload the Rails page after a successful write. This meets the requested update-or-reload outcome without requiring ReActionView or implementing a generic patcher.

## Render graph

[`Herb::Analysis::RenderGraph`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/analysis/render_graph.rb) stores callers, roots, unresolved renders and skipped files; `complete?` distinguishes incomplete analysis. Its [`Builder`](https://github.com/marcoroth/herb/blob/d36f73737f43b7306f561efa32283b89e3b39c6f/lib/herb/analysis/render_graph/builder.rb) consumes a partial index and parses with `render_nodes`, `prism_nodes`, and `action_view_helpers`. This is static render analysis, not universal runtime DOM-to-source provenance. Defer integrating it for the single-view proof.

## Issues inspected

- [#1615: Convert to `tag.pre`](https://github.com/marcoroth/herb/issues/1615), open: illustrates nontrivial semantics of helper rewrites. Literal HTML attribute editing avoids this transformation.
- [#2215: Embedded JS backend for Node-free linting](https://github.com/marcoroth/herb/issues/2215), open in inspected search results: relevant to Ruby/JS capability boundaries, but not evidence of a supported Ruby source rewriter.
- [#2294: Non-root view paths](https://github.com/marcoroth/herb/issues/2294), open: render analysis does not universally resolve multi-root Rails applications; irrelevant to one fixed toy view but material to future expansion.
- [#2352: Compiled line-number preservation](https://github.com/marcoroth/herb/issues/2352), open: reinforces keeping source locations distinct from generated Ruby locations.

Issue searches were targeted samples, not an exhaustive issue audit. A GitHub API search for issues labeled `dev-server` returned zero results; it does not establish an absence of dev-server defects.
