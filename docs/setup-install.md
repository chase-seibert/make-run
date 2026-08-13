# Setup and Installation

1. Install Xcode and select its command-line tools.
2. Run `make test` to verify the toolchain.
3. Run `make run` to assemble and launch `build/Make Run.app`.
4. In Make Run, choose **File → Add Search Folder…** and select a directory.
5. Allow notifications when prompted.

Make Run invokes `/bin/bash -lc` as an app-owned noninteractive background process. Bash reads `~/.bash_profile`, which may source `~/.bashrc` according to the user's shell configuration. Make sure profile scripts are safe for noninteractive runs. Removing `~/Library/Application Support/Make Run/` resets the local index and logs.
