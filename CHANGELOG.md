# Changelog

## 2026-08-12

- Created the native Make Run macOS app.
- Added recursive Makefile discovery, target indexing, favorites, recent runs, captured output, notifications, unread badges, quick actions, and a menu bar companion.
- Fixed exit code 139 on systems with recursive or otherwise unsafe `.bashrc` files by matching standard login-shell startup behavior.
- Made recursive indexing visibly progressive: projects now appear before `make help` enrichment finishes, and redundant nested search roots are collapsed automatically.
- Fixed run selection incorrectly invoking macOS document creation when the main window title reflected the selected project.
- Fixed completed runs showing an ever-increasing “time since start” value; running timers are now live and completed durations remain frozen.
- Added whitespace-preserving, selectable, smart-wrapped console logs with no horizontal overflow, initial scroll-to-bottom, and respectful live-output auto-scrolling.
- Changed quick-run buttons to preserve both the beginning and end of long target names with middle truncation.
- Made run completion resilient to closed or killed Terminal sessions using exit/signal traps, launcher PID liveness checks, and legacy failed-log recovery.
- Deferred the console's initial scroll until AppKit completes its first real viewport and text-layout pass, reliably opening logs at the bottom.
- Removed redundant star icons from project rows already grouped in the Favorites section.
- Fixed a stack-overflow crash when changing font size by replacing a recursively self-mutating observed property with a clamped backing value.
- Added the selected project's directory path and an Open in Finder action to the project target view.
- Replaced visible Terminal windows with app-owned background login-Bash processes, direct live-log capture, and immediate process termination handling.
- Expanded text scaling to explicit proportional macOS fonts across sidebar sections, quick actions, project headings, target lists, descriptions, run metadata, and detail content; added rendered-pixel verification because macOS ignores SwiftUI dynamic type for these desktop styles.
- Added a live typography preview in Settings and updated verification to render the same production font modifier used throughout the app.
- Added repository ignore rules for generated Swift, Xcode, macOS, app-bundle, and icon artifacts.
