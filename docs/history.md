# Repository and historical POC inspection

Inspected `https://github.com/michael-lins/ruphy-studio` on 2026-09-14. Restored
its Git checkout and created `feature/herb-rad-poc` from main `b333b47`.

| Ref | Inspected head | Finding |
| --- | --- | --- |
| main | b333b47 | JRuby/Glimmer mascot shell, Rails generation and Ruphino injection by writing partials and substituting layout/routes source. No Herb integration. |
| feature/glimmer-poc | a79113a | Shared ancestry and desktop-shell iteration; README, task list and main implementation explain the JRuby/Rails 7.1 constraints. |
| feature/go-poc | 7c25f2f | Wails template; Go exposes Move/Hide/Show window operations. No reusable structural source editing. |
| feature/tauri-poc | a5e379d | Rust/Tauri desktop shell; `create_and_run_project` orchestrates Docker-based Rails creation, bundling and database setup. |
| desktoper | 9842e51 | Related Tauri/Docker project creation with Bun tooling. |
| feature/borderless-touch | 7aa1710 | Earlier Rails 8 builder. Stimulus serializes dropped component positions and recreates DOM nodes; separate drop-zone/layout state, not real ERB source editing. |

Implementation reads included main's `app/ui/ruphino_window.rb`, Go's `app.go`,
Tauri/desktoper's `src-tauri/src/lib.rs`, and borderless-touch's
`app/javascript/controllers/builder_controller.js` and Gemfile. Git logs across
all remote branches were inspected before coding.

Reused `icons/ruphino.png` as the injected browser mascot. Removed active
JRuby/Glimmer entry points and their obsolete task list and replaced toolchain
instructions. Old experiments remain in Git history.

Prior layout/routes substitutions, the generated `/ruphy` canvas, Wails window
control, Docker orchestration and component-position persistence are not used.
