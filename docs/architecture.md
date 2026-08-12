# Architecture

Make Run is a SwiftUI menu-bar-and-window app backed by an observable main-actor `AppStore`.

## Components

- `AppStore` owns persisted projects, targets, roots, run metadata, selection, indexing, and status polling.
- `MakefileParser` first publishes recursively discovered projects and locally parsed targets, then enriches missing descriptions from conventional `make help` output in a second phase so slow help targets never make the crawler appear empty.
- `TerminalRunner` writes a small `.command` launcher per run. Terminal.app executes it through interactive login Bash, `tee` captures output, and an atomic status sidecar reports the real Make exit code. Exit and signal traps cover ordinary termination, while a launcher-PID sidecar lets the app recognize a vanished process if Terminal or the shell is killed before status reporting.
- Views use a three-column `NavigationSplitView`: projects and quick actions, target/recent-run sections, and target/run detail.
- A `MenuBarExtra` exposes favorite and recent projects with the same quick actions.

## Persistence

Metadata is encoded as JSON at `~/Library/Application Support/Make Run/index.json`. Run logs, launchers, and status files live below `Runs/<run UUID>/`. Paths are intentionally local and inspectable. Project identity is the standardized directory path, which preserves `createdAt` and favorites across rescans.

## Security and tradeoffs

The app is intentionally not sandboxed because its core job is executing arbitrary local Make targets and accessing user-selected development trees. It never uploads source or logs. Help execution is bounded and only attempted when a declared `help` target exists. External Terminal execution provides authentic terminal interaction at the cost of polling a status file for completion.
