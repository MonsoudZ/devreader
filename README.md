# DevReader (macOS)

![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Enabled-blue)
![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)

DevReader is a SwiftUI macOS app for reading and annotating PDFs with notes, bookmarks, code/web scratchpads, and persistent settings.

## Features
- PDF reading with last-read-page restore per document
- Highlights and sticky notes (saved to annotated copy)
- Notes pane with tags, page notes, search/filter, and Markdown export
- Bookmarks per document
- Outline sidebar (Table of Contents) with navigation and current page sync
- In-PDF text search with Prev/Next and match highlights
- Library with import, multi-select remove, drag-out to Finder, sort options
- Code scratchpad with Monaco editor (two-way persistence)
- Web pane with history, bookmarks, and Open in default browser
- Sketch window: undo, pen color/width, resizable canvas, insert as PDF page
- Recent Documents with pin/unpin and clear
- Settings: default zoom, highlight color, autosave toggle and interval
- Structured logging + user error toasts

## Architecture
- SwiftUI + MVVM
  - Models: `NoteItem`, `LibraryItem`, `SessionData`
  - ViewModels: `PDFController`, `NotesStore`, `LibraryStore`
  - Views in folders: `PDF`, `Notes`, `Library`, `Web`, `Code`, `Sketch`, `Settings`, `Onboarding`
- Services: `PersistenceService`, `FileService`, `AnnotationService`
- Utils: `Extensions` (incl. logger + toasts), `Shell`, `Dependencies`
- Lightweight DI via `EnvironmentValues.deps` and `@EnvironmentObject ToastCenter`

## Build & Run
- Requires Xcode 15+ (macOS 15 SDK or newer)
- Open `DevReader.xcodeproj` and run the `DevReader` scheme
- Or build via CLI:
```bash
xcodebuild -project DevReader.xcodeproj -scheme DevReader -configuration Debug build
```

## Usage Tips
- Import PDFs: Toolbar → “Import PDFs…” or “Open PDF…”
- Outline: Toggle via “Show/Hide Outline”
- Search: Use the toolbar search box (Find/Prev/Next/Clear)
- Notes: Add/Edit notes in the Notes pane; tag notes; export Markdown
- Bookmarks: Toggle for current page via toolbar
- Recents: Toolbar → “Recent” (supports Pin/Unpin/Clear Recents)
- Sketch: “New Sketch Page” to draw and insert into the PDF

## Settings
- Settings → PDF Display: Highlight Color, Default Zoom
- Settings → Data: Autosave toggle and interval (15s/30s/1m/5m)
- Changes apply live to the current PDF view

## Persistence
- UserDefaults for app/session state and per-PDF data
- Annotated PDFs stored under Application Support → DevReader → Annotations

## Logging & Error Toasters
- Logger: `log(AppLog.pdf, "message")` and `logError(AppLog.pdf, "message")`
- Toasts: injected via `ToastCenter` and shown with `toastCenter.show("Title", "Message", style: .error)`

## Tests
- Unit tests in `DevReaderTests/`: `PersistenceServiceTests`, `NotesStoreTests`, `PDFControllerTests`
- Run:
```bash
xcodebuild -project DevReader.xcodeproj -scheme DevReader -configuration Debug -destination 'platform=macOS' test
```

## Roadmap
- PDF search result list + jump
- Enhanced Markdown export presets
- More robust Monaco bridging (multi-file, language switch)
- Structured logs viewer inside the app

## Screenshots
⚠️ **Screenshots not yet captured** - See `docs/screenshots/README.md` for guidelines.

<!-- Place images under `docs/screenshots/` and they will render here.

![Library](docs/screenshots/library.png)
![PDF + Outline](docs/screenshots/pdf_outline.png)
![Notes](docs/screenshots/notes.png)
![Code](docs/screenshots/code.png)
![Web](docs/screenshots/web.png)
![Sketch](docs/screenshots/sketch.png) -->

## Contributing
- Fork and PRs welcome.
- Keep code readable, adhere to existing style, and include tests where reasonable.

## License
MIT
