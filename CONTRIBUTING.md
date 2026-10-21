# Contributing to Ruphy

Ruphy is an early Rails/Herb proof of concept. Start with the
[README](README.md) for the working experiment and its boundaries. Small,
reproducible improvements and questions are welcome.

## Plan the work

Use [Issues](https://github.com/michael-lins/ruphy-studio/issues) for bugs,
features and bounded research spikes. Search existing issues before opening one.
Use [Discussions](https://github.com/michael-lins/ruphy-studio/discussions) for
questions and early ideas. Issues own the backlog; repository docs explain the
system and record verified results.

Each implementation issue should identify the problem, smallest useful scope,
acceptance criteria and verification. A spike should name the uncertainty and
the evidence needed to resolve it. Link prerequisites explicitly. Discuss new
dependencies and broader architecture changes before implementing them.

The [Ruphy Development board](https://github.com/users/michael-lins/projects/2)
uses these statuses:

| Status | Meaning |
| --- | --- |
| Backlog | Captured, but not yet ready to start |
| Ready | Scope and acceptance criteria are clear; prerequisites are resolved |
| In progress | Someone is actively working on it |
| In review | Implementation and verification are ready for review |
| Done | Acceptance criteria are verified and the change is merged, or the spike's findings are recorded |

Keep one implementation issue in progress per contributor. Use milestones for
observable outcomes, not speculative deadlines. Apply `bug`, `enhancement`,
`documentation` or `spike` to describe work; status belongs on the board.
Reserve `good first issue` for well-understood work with clear guidance.

The first outcome is the
[Direct editing POC milestone](https://github.com/michael-lins/ruphy-studio/milestone/1).
Use GitHub's blocked-by relationships for prerequisites. Adding an issue to the
board defaults it to Backlog. Moving a card to Done does not automatically close
its issue; verify acceptance and close through the completed PR or spike review.

## Make a small change

1. Agree on an issue's scope and comment before starting to avoid duplicated work.
2. Follow the [mise setup](README.md#run) and create a focused branch from `main`,
   which contains the current Rails/Herb implementation. Target `main` with new
   pull requests. The former desktop implementation is preserved on
   `codex/legacy-desktop-poc` for historical reference.
3. For behavior changes, write a focused test, observe the expected failure,
   implement the smallest fix, then refactor with tests green. For documentation,
   review content and links; do not add tests merely to mirror prose.
4. Run `mise run test`. For UI changes, also exercise the real Rails page. Restore
   any example source changed during verification. Stop the servers, residents
   and watchers you started, and verify that their processes and sockets are gone.
5. Open a focused PR linking the issue, explaining the outcome and recording
   verification and limitations. Use `Closes #123` when it completes that issue.
   Check acceptance criteria before merging and closing; partial work keeps its
   issue open.

Verify Herb APIs against the relevant release and source. Do not edit ERB with
regex. Keep framework adapters small and source mutation separate from browser
interaction. See [decisions](docs/decisions.md) and
[Herb research](docs/herb-research.md) for existing constraints.

Update [decisions](docs/decisions.md) when a technical tradeoff changes, and
[progress](docs/progress.md) for completed milestones and reproducible
verification. Link issues instead of duplicating their backlog in these files.
