# Make Run

Make Run is a native macOS command center for Makefile projects. Pick one or more folders, let the app index projects and targets, then run common targets from the main window or menu bar. Commands run as app-owned background login-Bash processes while their live output and exit code are captured for review.

## Development

Requires macOS 14 or newer and Xcode 16 or newer.

```sh
make test
make run
```

The assembled app is written to `build/Make Run.app`. App data is stored locally under `~/Library/Application Support/Make Run/`.

See [setup and installation](docs/setup-install.md) for details.
