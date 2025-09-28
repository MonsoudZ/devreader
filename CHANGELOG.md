# Changelog

All notable changes to DevReader will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive CI/CD pipeline with GitHub Actions
- Automated smoke testing
- Security scanning in CI
- Performance monitoring and optimization
- Memory pressure handling
- JPEG2000 error suppression
- Large PDF optimization (500+ pages)
- Modern UI components and layouts
- Monaco editor integration with multi-language support
- Code execution for 12+ programming languages
- Web browser with modern WebKit
- JSON-based data storage system
- Backup and restore functionality
- Toast notification system
- Loading state management
- Comprehensive test suite (100% pass rate)

### Changed
- Migrated from UserDefaults to JSON file storage
- Updated to modern WebKit APIs
- Improved PDF loading with multiple fallback strategies
- Enhanced highlighting and annotation system
- Optimized memory usage and CPU performance
- Redesigned user interface with modern components

### Fixed
- PDF loading issues with problematic files
- Highlighting freeze during annotation saving
- Page tracking accuracy for large PDFs
- Session handling and data persistence
- Swift 6 concurrency warnings
- Deprecation warnings for WebKit APIs
- Build warnings and unreachable code
- Memory leaks and performance issues
- JPEG2000 rendering errors
- CPU usage spikes during monitoring

### Security
- Implemented sandbox entitlements for code execution
- Added hardened runtime configuration
- Enhanced error handling and recovery
- Improved data validation and integrity checks

## [1.0.0] - 2024-12-01

### Added
- Initial release of DevReader
- PDF reading and annotation capabilities
- Code editor with syntax highlighting
- Web browser integration
- Note-taking and highlighting system
- Library management
- Search functionality
- Outline navigation
- Sketch annotation support
- Multi-language code execution
- Data export and import
- Settings and preferences
- Onboarding walkthrough

### Technical Details
- Built with SwiftUI for macOS
- PDFKit integration for PDF handling
- Monaco editor for code editing
- WebKit for web browsing
- JSON-based data persistence
- Sandboxed code execution
- Memory-optimized PDF rendering
- Accessibility support
- Keyboard navigation
- Modern macOS design patterns

---

## Release Notes Format

### Version Numbering
- **Major** (X.0.0): Breaking changes, major new features
- **Minor** (0.X.0): New features, backwards compatible
- **Patch** (0.0.X): Bug fixes, minor improvements

### Categories
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

### Links
- [GitHub Releases](https://github.com/Mengzanaty/devreader/releases)
- [Documentation](https://github.com/Mengzanaty/devreader/wiki)
- [Issue Tracker](https://github.com/Mengzanaty/devreader/issues)
