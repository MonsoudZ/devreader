import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedSection: HelpSection = .keyboard
    
    enum HelpSection: String, CaseIterable, Identifiable {
        case keyboard = "Keyboard Shortcuts"
        case features = "Features"
        case troubleshooting = "Troubleshooting"
        case about = "About"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .keyboard: return "keyboard"
            case .features: return "star.fill"
            case .troubleshooting: return "wrench.and.screwdriver"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(HelpSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedSection {
                    case .keyboard:
                        KeyboardShortcutsView()
                    case .features:
                        FeaturesView()
                    case .troubleshooting:
                        TroubleshootingView()
                    case .about:
                        AboutView(isPresented: .constant(true))
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("DevReader Help")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Keyboard Shortcuts View

struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Master DevReader with these essential keyboard shortcuts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ShortcutGroupView(
                    title: "File Operations",
                    shortcuts: [
                        ("⌘O", "Open PDF"),
                        ("⌘⇧I", "Import PDFs"),
                        ("⌘W", "Close PDF"),
                        ("⌘Q", "Quit DevReader")
                    ]
                )
                
                ShortcutGroupView(
                    title: "Navigation",
                    shortcuts: [
                        ("⌘F", "Search in PDF"),
                        ("⌘G", "Find Next"),
                        ("⌘⇧G", "Find Previous"),
                        ("⌘⇧F", "Search in Notes")
                    ]
                )
                
                ShortcutGroupView(
                    title: "Annotations",
                    shortcuts: [
                        ("⌘⇧H", "Highlight Text"),
                        ("⌘⇧S", "Add Sticky Note"),
                        ("⌘⇧K", "Create Sketch"),
                        ("⌘⇧N", "Add Note")
                    ]
                )
                
                ShortcutGroupView(
                    title: "Interface",
                    shortcuts: [
                        ("⌘1", "Show Library"),
                        ("⌘2", "Show Outline"),
                        ("⌘3", "Show Notes"),
                        ("⌘4", "Show Code"),
                        ("⌘5", "Show Web")
                    ]
                )
                
                ShortcutGroupView(
                    title: "Application",
                    shortcuts: [
                        ("⌘,", "Preferences"),
                        ("⌘⇧O", "Show Onboarding"),
                        ("⌘?", "Show Help"),
                        ("⌘⇧H", "Hide DevReader")
                    ]
                )
                
                ShortcutGroupView(
                    title: "Code Editor",
                    shortcuts: [
                        ("⌘R", "Run Code"),
                        ("⌘S", "Save Code"),
                        ("⌘O", "Open Code File"),
                        ("⌘⇧E", "Export Code")
                    ]
                )
            }
            
            Divider()
            
            Text("Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                TipView(
                    icon: "lightbulb",
                    text: "Hold ⌘ while hovering over buttons to see their keyboard shortcuts."
                )
                
                TipView(
                    icon: "arrow.clockwise",
                    text: "Use ⌘Z to undo most actions, including annotations and sketches."
                )
                
                TipView(
                    icon: "magnifyingglass",
                    text: "Search works across PDFs, notes, and code files for comprehensive results."
                )
            }
        }
    }
}

// MARK: - Features View

struct FeaturesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DevReader Features")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Discover the powerful features that make DevReader the ultimate PDF reader for developers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                FeatureCardView(
                    icon: "doc.text.magnifyingglass",
                    title: "PDF Reading",
                    description: "High-performance PDF rendering with memory optimization for large documents.",
                    features: ["Text highlighting", "Sticky notes", "Search functionality", "Outline navigation"]
                )
                
                FeatureCardView(
                    icon: "curlybraces.square",
                    title: "Code Editor",
                    description: "Monaco editor with syntax highlighting and multi-language support.",
                    features: ["12+ languages", "Code execution", "File management", "Export options"]
                )
                
                FeatureCardView(
                    icon: "safari",
                    title: "Web Browser",
                    description: "Modern WebKit integration for browsing documentation and resources.",
                    features: ["JavaScript support", "Bookmark management", "Developer tools", "Security controls"]
                )
                
                FeatureCardView(
                    icon: "highlighter",
                    title: "Note-Taking",
                    description: "Smart note organization with tags, search, and markdown export.",
                    features: ["Tag system", "Search across notes", "Markdown export", "Data persistence"]
                )
                
                FeatureCardView(
                    icon: "pencil.and.outline",
                    title: "Sketch & Drawing",
                    description: "Built-in sketch pad for diagrams and PDF annotations.",
                    features: ["Drawing tools", "Undo/redo", "Export to PDF", "Annotation tools"]
                )
                
                FeatureCardView(
                    icon: "folder.fill",
                    title: "Library Management",
                    description: "Organize your PDFs with smart categorization and quick access.",
                    features: ["Smart organization", "Quick access", "Search functionality", "Import/export"]
                )
            }
        }
    }
}

// MARK: - Troubleshooting View

struct TroubleshootingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Troubleshooting")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Common issues and their solutions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                TroubleshootingItemView(
                    problem: "PDF not loading",
                    solution: "Try the repair function in Settings → Data Management → Validate Data Integrity",
                    icon: "doc.badge.gearshape"
                )
                
                TroubleshootingItemView(
                    problem: "High memory usage",
                    solution: "Enable large PDF optimizations in Settings → Performance",
                    icon: "memorychip"
                )
                
                TroubleshootingItemView(
                    problem: "Code execution fails",
                    solution: "Check sandbox entitlements in Settings → Security",
                    icon: "terminal"
                )
                
                TroubleshootingItemView(
                    problem: "Performance issues",
                    solution: "Monitor memory usage in Settings → Performance and restart the app",
                    icon: "speedometer"
                )
                
                TroubleshootingItemView(
                    problem: "App crashes",
                    solution: "Export crash logs from Settings → Support → Export Logs",
                    icon: "exclamationmark.triangle"
                )
            }
            
            Divider()
            
            Text("Getting Help")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                HelpLinkView(
                    title: "GitHub Issues",
                    description: "Report bugs and request features",
                    url: "https://github.com/Mengzanaty/devreader/issues"
                )
                
                HelpLinkView(
                    title: "Documentation",
                    description: "Comprehensive guides and tutorials",
                    url: "https://github.com/Mengzanaty/devreader/wiki"
                )
                
                HelpLinkView(
                    title: "Community Support",
                    description: "Get help from other users",
                    url: "https://github.com/Mengzanaty/devreader/discussions"
                )
            }
        }
    }
}

// MARK: - About View (moved to Views/About/AboutView.swift)

struct OldAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About DevReader")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("A modern PDF reader and development environment for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                InfoRowView(label: "Version", value: "1.0.0")
                InfoRowView(label: "Build", value: "2024.12.01")
                InfoRowView(label: "Platform", value: "macOS 12.0+")
                InfoRowView(label: "Architecture", value: "Apple Silicon & Intel")
            }
            
            Divider()
            
            Text("Built with")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• SwiftUI - Modern macOS UI framework")
                Text("• PDFKit - Apple's PDF rendering engine")
                Text("• Monaco Editor - VS Code editor integration")
                Text("• WebKit - Modern web browsing")
                Text("• JSON Storage - Fast, reliable data persistence")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Divider()
            
            Text("Privacy & Security")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Local storage only - No data leaves your device")
                Text("• Sandboxed execution - Code runs in isolated environment")
                Text("• No telemetry - No usage data collection")
                Text("• GDPR/CCPA compliant - Privacy-first design")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Divider()
            
            Text("Open Source")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("DevReader is open source and available on GitHub under the MIT License.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/Mengzanaty/devreader") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Report Issue") {
                    if let url = URL(string: "https://github.com/Mengzanaty/devreader/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Supporting Views

struct ShortcutGroupView: View {
    let title: String
    let shortcuts: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(shortcuts, id: \.0) { shortcut, description in
                    HStack {
                        Text(shortcut)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(description)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FeatureCardView: View {
    let icon: String
    let title: String
    let description: String
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TroubleshootingItemView: View {
    let problem: String
    let solution: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(problem)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(solution)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HelpLinkView: View {
    let title: String
    let description: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InfoRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct TipView: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.caption)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HelpView()
}
