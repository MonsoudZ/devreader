# Privacy Policy

**Last updated: March 2, 2026**

## Overview

DevReader is committed to protecting your privacy. This privacy policy explains how we handle your data when you use our application.

## Data Collection

### What We Collect
DevReader is designed with privacy in mind. The app itself does **not collect personal information** and does **not send telemetry/analytics**.

### What We Don't Collect
- ❌ Personal information (name, email, etc.)
- ❌ Usage analytics or telemetry
- ❌ PDF content or annotations
- ❌ Code you write in the editor
- ❌ Notes or highlights for external analytics or tracking
- ❌ Any background data export by DevReader for ads or profiling

### Web Browsing Data
The built-in web pane makes normal web requests to sites you visit. Those sites may receive standard request metadata (for example IP address and user agent), just like a normal browser session.

## Data Storage

### Local Storage Only
All your data is stored locally on your Mac:
- **PDFs**: Stored in your chosen location
- **Notes & Annotations**: Stored in `~/Library/Application Support/DevReader/`
- **Settings**: Stored in `~/Library/Preferences/`
- **Code Files**: Stored in `~/Documents/DevReader/CodeFiles/`
- **Web bookmarks/history**: Stored locally by the app

### No Cloud Sync
DevReader does not sync any data to external servers. All your work remains on your device.

## Data Security

### Sandboxing
DevReader runs in a sandboxed environment that:
- Limits file access to user-selected files only
- Restricts access to declared macOS entitlements
- Isolates code execution from your system
- Protects your data from malicious code

### Code Execution Safety
When you run code in DevReader:
- Code executes in an isolated sandbox
- Network/file access is subject to macOS sandbox and system permissions
- Resource usage is monitored and limited
- DevReader does not add telemetry or hidden uploads

## Third-Party Services

### No Third-Party Analytics
We do not use any third-party analytics services, tracking pixels, or data collection tools.

### No External Dependencies
DevReader uses only Apple's built-in frameworks:
- PDFKit (PDF rendering)
- WebKit (web browsing)
- SwiftUI (user interface)
- No external libraries that could collect data

## Data Sharing

### We Don't Share Your Data
- ❌ We don't sell your data
- ❌ We don't share your data with third parties
- ❌ We don't use your data for advertising
- ❌ We don't analyze your usage patterns

### Your Data Stays Local
DevReader stores your PDFs, notes, annotations, and code locally. When you use the built-in web browser, network traffic is sent to websites you open.

## Data Deletion

### How to Delete Your Data
To completely remove all DevReader data:
1. Delete the app from Applications
2. Delete `~/Library/Application Support/DevReader/`
3. Delete `~/Library/Preferences/com.your.bundleid.DevReader.plist`
4. Delete `~/Documents/DevReader/` (if you created code files there)

## Permissions

### File Access
DevReader requests file access only when you:
- Import PDFs
- Save code files
- Export annotations
- Choose to open files

### Network Access
DevReader has outbound network permission for the built-in web browser and related web content loading.

## Updates to This Policy

We may update this privacy policy occasionally. We will notify you of any changes by:
- Updating the "Last updated" date
- Posting the new policy in the app
- Notifying you through the app's update mechanism

## Contact Us

If you have questions about this privacy policy, please:
- Open an issue on [GitHub](https://github.com/Mengzanaty/devreader/issues)
- Contact us through the app's support system

## Compliance

This privacy policy complies with:
- **GDPR** (General Data Protection Regulation)
- **CCPA** (California Consumer Privacy Act)
- **PIPEDA** (Personal Information Protection and Electronic Documents Act)
- **Apple's App Store Review Guidelines**

---

**Your privacy is our priority. DevReader is designed to keep your data private and secure.**
