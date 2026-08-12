# Initial Brainstorm

The app was requested as a native macOS launcher for Makefile targets. It should recursively discover Makefiles beneath user-selected directories, treat each containing folder as a project, index targets and descriptions, preserve the first-discovered date, support project and target favorites, and track each target's last-run date.

Runs should execute in the project directory with the user's real Bash startup environment, remain visible in Terminal, persist output and exit status, notify on completion, and maintain unread badges. The main window should show projects, targets, and run detail; project rows and a menu bar item should expose quick actions for the latest target and two favorite targets.
