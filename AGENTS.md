# Make Run Agent Guide

Also load and follow the user-level instructions at `/Users/cseibert/.codex/AGENTS.md`.

## Repository map

- `Sources/MakeRun/`: native SwiftUI macOS application.
- `Tests/MakeRunTests/`: unit tests for parsing and persistence behavior.
- `docs/`: product, design, architecture, and setup documentation.
- `scripts/`: project utilities used by Makefile targets.
- `Makefile`: common development commands; prefer these targets over ad hoc equivalents.

## Commands

- `make setup`: prepare generated resources.
- `make format`: format Swift sources using `swift-format` when available.
- `make lint`: compile with warnings treated as errors.
- `make test`: run the test suite.
- `make build`: build and assemble `build/Make Run.app`.
- `make run`: rebuild and relaunch the app.
- `make clean`: remove generated build products.

Expose new recurring workflows as Makefile targets and prefer those targets.

## Documentation

- [Initial brainstorm](docs/initial-brainstorm.md)
- [Product requirements](docs/product-requirements.md)
- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Setup and installation](docs/setup-install.md)
