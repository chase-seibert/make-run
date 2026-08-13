# Architecture

Make Run is a SwiftUI menu-bar-and-window app backed by an observable main-actor `AppStore`.

## Components

- `AppStore` owns persisted projects, targets, roots, run metadata, selection, indexing, active background processes, and recovery polling.
- `MakefileParser` first publishes recursively discovered projects and locally parsed targets, then enriches missing descriptions from conventional `make help` output in a second phase so slow help targets never make the crawler appear empty.
- `BackgroundProcessRunner` launches login Bash directly as an app-owned `Process` in the project directory. Standard output and error write directly to the persisted log, and `terminationHandler` reports completion immediately. Atomic exit-status and PID sidecars provide recovery if the app quits or crashes during a run.
- Views use a three-column `NavigationSplitView`: projects and quick actions, target/recent-run sections, and target/run detail.
- A `MenuBarExtra` exposes favorite and recent projects with the same quick actions.

## Persistence

Metadata is encoded as JSON at `~/Library/Application Support/Make Run/index.json`. Run logs and recovery sidecars live below `Runs/<run UUID>/`. Paths are intentionally local and inspectable. Project identity is the standardized directory path, which preserves `createdAt` and favorites across rescans.

## Security and tradeoffs

The app is intentionally not sandboxed because its core job is executing arbitrary local Make targets and accessing user-selected development trees. It never uploads source or logs. Help execution is bounded and only attempted when a declared `help` target exists. Background runs are noninteractive: targets that require a TTY or user input will fail rather than opening a Terminal window.
