# Earlier Ruphy experiments

The original goal was a Delphi-inspired Rails development experience, including
a companion that guides developers through Ruby/Rails setup. The following
snapshots explain the move from desktop shells to editing the running Rails page.

| Snapshot | Approach | Lesson for the current design |
| --- | --- | --- |
| main at `b333b47` | JRuby/Glimmer mascot shell, Rails generation, partial injection and layout/routes substitutions | Keep the companion identity; inject tooling through a development gem instead of changing application setup files. |
| feature/glimmer-poc at `a79113a` | Desktop interaction experiments with JRuby/SWT | Window behavior does not establish safe editing of Rails source. |
| feature/go-poc at `7c25f2f` | Wails shell exposing Move/Hide/Show | A different shell does not solve structural source editing. |
| feature/tauri-poc at `a5e379d` and desktoper at `9842e51` | Tauri/Docker Rails creation and setup | Guided onboarding remains a product goal; it is separate from the first editing proof. |
| feature/borderless-touch at `7aa1710` | Rails 8 builder storing component positions and recreating dropped DOM elements | A separate layout model can diverge from application source; use the real Rails page as the canvas. |

The current implementation reuses the Ruphino image, now stored in the gem's
assets. The desktop entry points, separate designer canvas and component-position
persistence are retired. Earlier implementations remain available in Git history.
See [current decisions](decisions.md) for the Rails/Herb architecture.
