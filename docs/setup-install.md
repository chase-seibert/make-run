# Setup and Installation

1. Install Xcode and select its command-line tools.
2. Run `make test` to verify the toolchain.
3. Run `make run` to assemble and launch `build/Make Run.app`.
4. In Make Run, choose **File → Add Search Folder…** and select a directory.
5. Allow notifications when prompted. Terminal may ask for normal macOS automation/opening confirmation on first use.

Make Run invokes `/bin/bash -lic`, matching Bash login-shell behavior. Bash reads `~/.bash_profile`, which may source `~/.bashrc` according to the user's normal shell configuration. Make sure your Bash profile scripts are safe to run non-manually. Removing `~/Library/Application Support/Make Run/` resets the local index and logs.
