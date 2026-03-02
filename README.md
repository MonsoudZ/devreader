# DevReader

DevReader is a macOS app that combines PDF reading, annotation, coding, and web browsing in one workspace.

[![CI/CD](https://github.com/Mengzanaty/devreader/workflows/CI/CD%20Pipeline/badge.svg)](https://github.com/Mengzanaty/devreader/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

## Features

- Fast PDF rendering and navigation
- Highlights, notes, and annotation workflows
- Integrated Monaco-based code editor and code execution
- Built-in WebKit browser pane
- Markdown note export
- Local JSON persistence and backup/restore utilities

## Requirements

- macOS 12.0+
- Xcode 15+
- Apple Silicon or Intel Mac

## Build And Run

```bash
git clone https://github.com/Mengzanaty/devreader.git
cd devreader
open DevReader.xcodeproj
```

From Xcode, select the `DevReader` scheme and run.

## Test

```bash
# smoke checks
./Scripts/smoke.sh

# full test run
xcodebuild test -scheme DevReader -destination "platform=macOS,arch=arm64"
```

## Release

```bash
./Scripts/release.sh 1.0.0
```

## Repository Layout

```text
App/               Application entry and app wiring
Models/            Data models
Services/          Core services (PDF, storage, execution, etc.)
Utils/             Shared utility code
ViewModels/        View models and state management
Views/             SwiftUI views and panes
DevReaderTests/    Unit tests
DevReaderUITests/  UI tests
Scripts/           CI and local automation scripts
docs/              Operational checklist(s)
```

## Documentation

- [CHANGELOG.md](CHANGELOG.md)
- [PRIVACY.md](PRIVACY.md)
- [docs/SHIP_CHECKLIST.md](docs/SHIP_CHECKLIST.md)

## Contributing

1. Create a branch from `main`.
2. Make changes and run `./Scripts/smoke.sh`.
3. Open a pull request with a clear summary and test notes.

## License

MIT. See [LICENSE](LICENSE).
