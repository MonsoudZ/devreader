# DevReader Smoke Test Suite

## 🧪 Overview

This document outlines the comprehensive smoke test suite for DevReader v1.0. These tests verify that all critical functionality works correctly and performance meets the required benchmarks.

## ⚡ Quick 15-Minute Smoke Test

### Essential Functionality Validation
1. **Import 3 PDFs** (small, huge, scanned) → All load successfully
2. **Navigate via TOC**; close app; reopen → Last-read page restored
3. **Add highlight + sticky note**; quit; reopen → Persists correctly
4. **Search text**; next/prev; verify result count and focus
5. **Create tags**; filter notes; export Markdown; open exported file
6. **Sketch**: draw; undo/redo; save; reopen
7. **Scratchpad**: edit code; quit; reopen → Changes persist
8. **Pull network** (if any remote ops) → No hangs; friendly error
9. **Turn on VoiceOver**; keyboard-tab through reader + notes list
10. **Open a 500+ page PDF**; flip 20 pages quickly → No jank

**✅ All 10 steps must pass for release readiness**

## 🚀 Quick Smoke Test (5 minutes)

### 1. App Launch & Basic Navigation
- [ ] **Cold Start**: App launches in ≤ 2s on M1/M2 Mac
- [ ] **UI Responsiveness**: All UI elements load and respond immediately
- [ ] **Memory Usage**: Initial memory usage < 100MB
- [ ] **No Crashes**: App launches without errors or crashes

### 2. PDF Loading & Display
- [ ] **Small PDF (2-10 pages)**: Loads in ≤ 1s
- [ ] **Medium PDF (100-200 pages)**: Loads in ≤ 2s  
- [ ] **Large PDF (500+ pages)**: Loads in ≤ 3s
- [ ] **Page Navigation**: Arrow keys, page up/down work smoothly
- [ ] **Zoom Controls**: Zoom in/out works without lag
- [ ] **Page Numbers**: Display correct current page and total pages
- [ ] **Progress Bar**: Shows accurate reading progress

### 3. Text Selection & Highlighting
- [ ] **Text Selection**: Can select text with mouse/trackpad
- [ ] **Highlight Creation**: ⌘⇧H creates highlight annotation
- [ ] **Highlight Persistence**: Highlights remain after page navigation
- [ ] **Highlight Colors**: Different highlight colors work
- [ ] **No UI Freeze**: Highlighting doesn't freeze the app

### 4. Notes & Annotations
- [ ] **Sticky Notes**: ⌘⇧S creates sticky note
- [ ] **Note Persistence**: Notes remain after app restart
- [ ] **Note Editing**: Can edit note content
- [ ] **Note Search**: Can search through notes
- [ ] **Note Export**: Can export notes to markdown

### 5. Search Functionality
- [ ] **Text Search**: Can search within PDF text
- [ ] **Search Results**: Shows correct number of matches
- [ ] **Search Navigation**: Can navigate between search results
- [ ] **Search Performance**: First results appear in ≤ 1s
- [ ] **Large PDF Search**: Full search completes in ≤ 3s for 500+ page PDFs

## 🔍 Comprehensive Smoke Test (30 minutes)

### 6. Code Editor (Monaco)
- [ ] **Editor Loads**: Monaco editor initializes without errors
- [ ] **Language Support**: All 12 languages work (Python, Ruby, JS, Swift, Bash, Go, C, C++, Rust, Java, SQL)
- [ ] **Syntax Highlighting**: Language-specific highlighting works
- [ ] **Code Execution**: Can run code in all supported languages
- [ ] **File Operations**: Save/load code files works
- [ ] **Export Options**: Can export to VSCode, Vim, Emacs, JetBrains formats
- [ ] **No Memory Leaks**: Editor doesn't consume excessive memory

### 7. Web Browser
- [ ] **Web Navigation**: Can navigate to websites
- [ ] **JavaScript Support**: Modern websites work correctly
- [ ] **Bookmarks**: Can add/remove bookmarks
- [ ] **History**: Navigation history works
- [ ] **Loading States**: Shows loading indicators for web pages

### 8. Library Management
- [ ] **PDF Import**: Can import multiple PDFs
- [ ] **Library Display**: Shows all imported PDFs
- [ ] **PDF Opening**: Can open PDFs from library
- [ ] **Recent Documents**: Shows recently opened PDFs
- [ ] **Pinned Documents**: Can pin/unpin documents
- [ ] **Library Persistence**: Library state persists across app restarts

### 9. Settings & Preferences
- [ ] **Settings Panel**: All settings categories accessible
- [ ] **Zoom Settings**: Default zoom can be changed
- [ ] **Highlight Colors**: Can change default highlight color
- [ ] **Auto-save**: Auto-save settings work
- [ ] **Data Management**: Backup/restore functionality works
- [ ] **Performance Monitor**: Shows real-time performance metrics

### 10. Error Handling & Recovery
- [ ] **Corrupted PDFs**: Gracefully handles corrupted PDFs
- [ ] **Memory Pressure**: Responds to memory pressure without crashing
- [ ] **Network Errors**: Handles network issues in web browser
- [ ] **File Access Errors**: Handles permission issues gracefully
- [ ] **Error Messages**: Shows user-friendly error messages

## 🏃‍♂️ Performance Stress Test (15 minutes)

### 11. Large PDF Performance
- [ ] **1000+ Page PDF**: Can load and navigate without issues
- [ ] **Memory Usage**: Stays under 800MB with large PDFs
- [ ] **CPU Usage**: Idle CPU < 3% when not actively using
- [ ] **Page Navigation**: Page flips in ≤ 50ms (warm)
- [ ] **Search Performance**: Search in large PDFs completes in reasonable time
- [ ] **Outline Building**: PDF outline builds without blocking UI

### 12. Memory Management
- [ ] **Memory Pressure**: App responds to memory pressure notifications
- [ ] **Cache Clearing**: Clears caches when memory is low
- [ ] **Memory Recovery**: Memory usage decreases after clearing caches
- [ ] **No Memory Leaks**: Memory usage doesn't continuously grow
- [ ] **Large File Handling**: Can handle multiple large PDFs

### 13. Concurrent Operations
- [ ] **Multiple PDFs**: Can have multiple PDFs open simultaneously
- [ ] **Background Tasks**: Background operations don't block UI
- [ ] **Async Operations**: All heavy operations run asynchronously
- [ ] **UI Responsiveness**: UI remains responsive during heavy operations

## 🧪 Edge Case Testing (20 minutes)

### 14. PDF Edge Cases
- [ ] **Encrypted PDFs**: Handles password-protected PDFs
- [ ] **Scanned PDFs**: Works with image-only PDFs
- [ ] **Malformed PDFs**: Gracefully handles corrupted PDFs
- [ ] **Very Small PDFs**: Works with 1-2 page PDFs
- [ ] **Very Large PDFs**: Works with 2000+ page PDFs
- [ ] **PDFs with Complex Graphics**: Handles PDFs with heavy graphics

### 15. System Integration
- [ ] **File Associations**: PDFs open in DevReader when double-clicked
- [ ] **Drag & Drop**: Can drag PDFs into the app
- [ ] **Keyboard Shortcuts**: All keyboard shortcuts work
- [ ] **Accessibility**: VoiceOver can read the interface
- [ ] **Dark Mode**: App works in both light and dark modes

### 16. Data Persistence
- [ ] **App Restart**: All data persists across app restarts
- [ ] **System Restart**: Data persists across system restarts
- [ ] **Data Integrity**: No data corruption after crashes
- [ ] **Backup/Restore**: Can backup and restore all data
- [ ] **Export/Import**: Can export and import data

## 🐛 Known Issues to Watch For

### Critical Issues (Must Fix)
- [ ] **App Crashes**: No crashes during normal usage
- [ ] **Data Loss**: No loss of notes, highlights, or bookmarks
- [ ] **Memory Leaks**: No continuous memory growth
- [ ] **UI Freezing**: No UI freezing during operations
- [ ] **Performance Degradation**: No significant performance degradation over time

### Minor Issues (Should Fix)
- [ ] **Slow Loading**: PDFs load within acceptable time limits
- [ ] **UI Glitches**: No visual glitches or rendering issues
- [ ] **Error Messages**: All error messages are user-friendly
- [ ] **Accessibility**: All features accessible via keyboard
- [ ] **Documentation**: All features have appropriate help text

## 📊 Performance Benchmarks

### Launch Performance
- [ ] **Cold Start**: ≤ 2s on M1/M2 Mac
- [ ] **Warm Start**: ≤ 1s
- [ ] **Memory Usage**: < 100MB initial

### PDF Loading Performance
- [ ] **Small PDF (2-10 pages)**: ≤ 1s
- [ ] **Medium PDF (100-200 pages)**: ≤ 2s
- [ ] **Large PDF (500+ pages)**: ≤ 3s
- [ ] **Very Large PDF (1000+ pages)**: ≤ 5s

### Navigation Performance
- [ ] **Page Flip (warm)**: ≤ 50ms
- [ ] **Page Flip (cold)**: ≤ 100ms
- [ ] **Zoom Operations**: ≤ 100ms
- [ ] **Search First Results**: ≤ 1s
- [ ] **Search Full Results**: ≤ 3s

### Memory Performance
- [ ] **Idle Memory**: < 200MB
- [ ] **Large PDF Memory**: < 800MB
- [ ] **Idle CPU**: < 3%
- [ ] **Active CPU**: < 50%

## 🚨 Failure Criteria

### Automatic Test Failure
- [ ] **App Crashes**: Any crash during testing
- [ ] **Data Loss**: Any loss of user data
- [ ] **Performance**: Any operation exceeds 2x the benchmark
- [ ] **Memory Leaks**: Memory usage grows continuously
- [ ] **UI Freezing**: UI becomes unresponsive for > 5 seconds

### Manual Review Required
- [ ] **Error Messages**: Unclear or unhelpful error messages
- [ ] **Accessibility**: Features not accessible via keyboard
- [ ] **Documentation**: Missing or incorrect help text
- [ ] **UI Issues**: Visual glitches or rendering problems
- [ ] **User Experience**: Confusing or unintuitive workflows

## 📋 Test Execution Checklist

### Pre-Test Setup
- [ ] **Clean Environment**: Fresh app installation
- [ ] **Test Data**: Prepare test PDFs of various sizes
- [ ] **System State**: Close other applications
- [ ] **Network**: Stable internet connection for web tests
- [ ] **Permissions**: Grant necessary file access permissions

### Test Execution
- [ ] **Follow Order**: Execute tests in the specified order
- [ ] **Record Results**: Document all pass/fail results
- [ ] **Note Issues**: Record any issues or unexpected behavior
- [ ] **Performance**: Measure and record performance metrics
- [ ] **Screenshots**: Capture screenshots of any issues

### Post-Test Cleanup
- [ ] **Data Cleanup**: Remove test data
- [ ] **Log Collection**: Collect relevant logs
- [ ] **Issue Reporting**: Report any failures
- [ ] **Performance Analysis**: Analyze performance results
- [ ] **Recommendations**: Provide improvement recommendations

## 🎯 Success Criteria

### Must Pass (100%)
- [ ] **No Crashes**: Zero crashes during testing
- [ ] **Data Integrity**: No data loss or corruption
- [ ] **Core Functionality**: All core features work
- [ ] **Performance**: Meets all performance benchmarks
- [ ] **Accessibility**: Basic accessibility requirements met

### Should Pass (95%)
- [ ] **UI Responsiveness**: UI remains responsive
- [ ] **Error Handling**: Graceful error handling
- [ ] **User Experience**: Intuitive user experience
- [ ] **Documentation**: Helpful error messages and documentation
- [ ] **Edge Cases**: Handles edge cases gracefully

### Nice to Have (90%)
- [ ] **Advanced Features**: All advanced features work
- [ ] **Performance**: Exceeds performance benchmarks
- [ ] **Accessibility**: Full accessibility compliance
- [ ] **Documentation**: Comprehensive documentation
- [ ] **User Experience**: Exceptional user experience

---

## 📝 Test Report Template

### Test Summary
- **Date**: [Date]
- **Tester**: [Name]
- **Version**: [Version]
- **Duration**: [Duration]
- **Result**: [Pass/Fail]

### Critical Issues
- [ ] **Issue 1**: [Description]
- [ ] **Issue 2**: [Description]
- [ ] **Issue 3**: [Description]

### Performance Results
- **Cold Start**: [Time]
- **Large PDF Load**: [Time]
- **Memory Usage**: [MB]
- **CPU Usage**: [%]

### Recommendations
- [ ] **Fix Critical Issues**: [List]
- [ ] **Improve Performance**: [List]
- [ ] **Enhance UX**: [List]
- [ ] **Update Documentation**: [List]

### Release Decision
- [ ] **Ready for Release**: All critical issues resolved
- [ ] **Needs Fixes**: Critical issues must be resolved
- [ ] **Major Issues**: Significant issues require attention
- [ ] **Not Ready**: Multiple critical failures

---

**Status**: 🔄 **READY FOR TESTING**

This smoke test suite provides comprehensive coverage of all DevReader functionality and ensures the app meets production quality standards.
