# Design

The main window uses a native three-column split view with a source-list sidebar, compact desktop rows, toolbars, searchable targets, system materials, context menus, and standard controls.

Project rows show unread badges and up to three quick-run buttons: the most recently run target followed by up to two favorite targets. Projects are grouped into Favorites and Projects; both are alphabetical. The target column is grouped into Favorite Targets, Recent Runs, and All Targets. Selecting a run opens its saved log and marks it read.

Project rows in the Favorites section omit per-row star icons because the section already communicates favorite status; ordinary project rows retain their folder icons.

Quick-run target labels show the full target whenever it fits and use middle truncation under space pressure, preserving both the target prefix and suffix so similarly named targets remain distinguishable.

The target browser includes a compact location bar showing the selected project's full directory path with middle truncation, selectable text, and a one-click Finder action.

The menu bar companion shows favorite projects and a bounded list of recent projects. Notifications state project, target, and outcome and open the corresponding saved log. Command-plus, Command-minus, and Command-zero control a persisted content scale also available in Settings.

Recursive indexing immediately shows a searching state, publishes projects as soon as filesystem discovery completes, and then displays a second-phase description-loading status. Selecting an ancestor search folder automatically removes redundant descendant roots.

Run output uses a native read-only macOS text view with monospaced preformatted text, preserved spaces, tabs, and line breaks, vertical scrolling, selectable text, Find support, and smart wrapping without horizontal scrolling. Logs initially open at the newest output; live output continues following the bottom only while the user is already near it.
