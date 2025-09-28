# DevReader

> A modern PDF reader and development environment for macOS

[![CI/CD](https://github.com/Mengzanaty/devreader/workflows/CI/CD%20Pipeline/badge.svg)](https://github.com/Mengzanaty/devreader/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

DevReader combines PDF reading, code editing, and web browsing in a single, powerful application designed for developers and technical professionals.

## ✨ Features

### 📄 PDF Reading & Annotation
- **High-performance PDF rendering** with memory optimization
- **Text highlighting** and annotation system
- **Sticky notes** and free-form annotations
- **Search functionality** with chunked processing for large documents
- **Outline navigation** with smart grouping for large PDFs
- **Page tracking** with accurate progress indicators
- **Large PDF support** (500+ pages) with optimized loading

### 💻 Code Editor
- **Monaco Editor** (VS Code editor) integration
- **Multi-language support**: Python, JavaScript, C++, Rust, Go, Swift, Java, SQL, and more
- **Syntax highlighting** and IntelliSense
- **Code execution** with sandboxed environment
- **File management** with save/load functionality
- **Export options** for various IDEs (VSCode, Vim, Emacs, JetBrains)

### 🌐 Web Browser
- **Modern WebKit** integration
- **JavaScript support** with security controls
- **Bookmark management**
- **Developer tools** access

### 📝 Note-Taking & Organization
- **Smart note organization** by PDF and page
- **Tag system** for categorization
- **Markdown export** with customizable templates
- **Search across all notes**
- **Data persistence** with JSON storage

### 🎨 Sketch & Drawing
- **Built-in sketch pad** for diagrams and annotations
- **Undo/redo functionality**
- **Export to PDF** integration
- **Annotation tools** for PDF markup

## 🚀 Getting Started

### System Requirements
- **macOS 12.0** or later
- **Apple Silicon (M1/M2)** or Intel processor
- **4GB RAM** minimum (8GB recommended for large PDFs)
- **100MB disk space**

### Installation

#### Option 1: Download (Recommended)
1. Download the latest release from [GitHub Releases](https://github.com/Mengzanaty/devreader/releases)
2. Open the DMG file
3. Drag DevReader to your Applications folder
4. Launch DevReader from Applications

#### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/Mengzanaty/devreader.git
cd devreader

# Open in Xcode
open DevReader.xcodeproj

# Build and run
# Or use the release script
./scripts/release.sh 1.0.0
```

## 📖 Usage

### Basic Workflow
1. **Import PDFs** - Drag and drop or use File → Import
2. **Read and annotate** - Highlight text, add notes, use the outline
3. **Code alongside** - Switch to the Code tab for development
4. **Browse resources** - Use the Web tab for documentation
5. **Organize notes** - Use tags and search to find information

### Keyboard Shortcuts
- `⌘O` - Open PDF
- `⌘⇧H` - Highlight selected text
- `⌘⇧S` - Add sticky note
- `⌘F` - Search in PDF
- `⌘⇧F` - Search in notes
- `⌘⇧O` - Show onboarding
- `⌘,` - Open settings

### Advanced Features
- **Large PDF optimization** - Automatically detects and optimizes for 500+ page documents
- **Memory management** - Intelligent caching and cleanup
- **Performance monitoring** - Real-time memory and CPU usage
- **Data backup** - Automatic backup and restore functionality

## 🛠 Development

### Project Structure
```
DevReader/
├── App/                    # Main application files
├── Models/                 # Data models
├── ViewModels/             # Business logic
├── Views/                  # SwiftUI views
├── Services/               # Core services
├── Utils/                  # Utilities and extensions
├── DevReaderTests/         # Unit tests
├── DevReaderUITests/       # UI tests
└── scripts/               # Build and release scripts
```

### Building
```bash
# Run tests
./scripts/smoke.sh

# Create release
./scripts/release.sh 1.0.0

# Run specific tests
xcodebuild test -scheme DevReader -destination "platform=macOS,arch=arm64"
```

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📊 Performance

### Benchmarks
- **Cold start**: ≤ 2 seconds
- **500-page PDF load**: ≤ 3 seconds
- **Page navigation**: ≤ 50ms average
- **Search (first results)**: ≤ 1 second
- **Memory usage**: ≤ 600-800MB for 1000-page documents
- **CPU usage (idle)**: < 3%

### Optimization Features
- **Lazy loading** for large documents
- **Memory pressure handling** with automatic cleanup
- **Chunked search** for responsive UI
- **Image processing optimization** for scanned PDFs
- **Background processing** for heavy operations

## 🔒 Security & Privacy

### Data Protection
- **Local storage only** - No data leaves your machine
- **Sandboxed execution** - Code runs in isolated environment
- **Secure file access** - Limited to user-selected files
- **No telemetry** - No usage data collection

### Code Execution Safety
- **Sandboxed environment** - Isolated from system
- **Limited permissions** - No network or file system access
- **Timeout protection** - Prevents infinite loops
- **Resource limits** - Memory and CPU constraints

## 🐛 Troubleshooting

### Common Issues
- **PDF not loading**: Try the repair function in settings
- **High memory usage**: Enable large PDF optimizations
- **Code execution fails**: Check sandbox entitlements
- **Performance issues**: Monitor memory usage in settings

### Getting Help
- **GitHub Issues**: [Report bugs and request features](https://github.com/Mengzanaty/devreader/issues)
- **Documentation**: [Wiki and guides](https://github.com/Mengzanaty/devreader/wiki)
- **Discussions**: [Community support](https://github.com/Mengzanaty/devreader/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **PDFKit** - Apple's PDF framework
- **Monaco Editor** - Microsoft's code editor
- **WebKit** - Apple's web engine
- **SwiftUI** - Apple's UI framework
- **Community contributors** - Thank you for your support!

## 📈 Roadmap

### v1.1 (Planned)
- [ ] Plugin system for extensions
- [ ] Cloud sync integration
- [ ] Advanced search filters
- [ ] Custom annotation tools
- [ ] Team collaboration features

### v1.2 (Future)
- [ ] Mobile companion app
- [ ] AI-powered note organization
- [ ] Advanced export options
- [ ] Performance analytics
- [ ] Custom themes

---

**Made with ❤️ for developers who love to read and code**