import SwiftUI
import PDFKit

struct ModernHeaderView: View {
    @ObservedObject var pdf: PDFController
    @ObservedObject var notes: NotesStore
    @ObservedObject var library: LibraryStore
    @Binding var showingLibrary: Bool
    @Binding var showingRightPanel: Bool
    @Binding var showingOutline: Bool
    @Binding var collapseAll: Bool
    @Binding var rightTab: RightTab
    @Binding var showSearchPanel: Bool
    @Binding var showingSettings: Bool
    
    let onOpenFromLibrary: (LibraryItem) -> Void
    let onImportPDFs: () -> Void
    let onOpenPDF: () -> Void
    
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showingAbout = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main toolbar
            HStack(spacing: 12) {
                // App branding
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("DevReader")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer(minLength: 20)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search in PDF...", text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search within current PDF")
                        .accessibilityHint("Enter text to search within the current PDF document")
                        .onSubmit {
                            if !searchText.isEmpty {
                                if pdf.isLargePDF {
                                    pdf.performSearchOptimized(searchText)
                                } else {
                                    pdf.performSearch(searchText)
                                }
                            }
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; pdf.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clear the search text and results")
                    }
                    
                    // Search results count
                    if !pdf.searchResults.isEmpty {
                        Text("\(pdf.searchResults.count) matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(pdf.searchResults.count) search results found")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)
                .cornerRadius(8)
                .frame(maxWidth: 300)
                
                Spacer(minLength: 20)
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: onImportPDFs) {
                        Image(systemName: "plus.circle")
                        Text("Import")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: onOpenPDF) {
                        Image(systemName: "folder")
                        Text("Open")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Menu {
                        Button("Settings") { showingSettings = true }
                        Button("Show Onboarding") { 
                            NotificationCenter.default.post(name: .showOnboarding, object: nil)
                        }
                        Divider()
                        Button("About DevReader") {
                            showingAbout = true
                        }
                        .accessibilityLabel("About DevReader")
                        .accessibilityHint("Show information about the application")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            // Secondary toolbar
            HStack(spacing: 8) {
                // Panel toggles
                HStack(spacing: 4) {
                    Button(action: { showingLibrary.toggle() }) {
                        Image(systemName: "sidebar.left")
                        Text("Library")
                    }
                    .accessibilityLabel(showingLibrary ? "Hide Library Panel" : "Show Library Panel")
                    .accessibilityHint("Toggle the library sidebar")
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(showingLibrary ? .blue : .secondary)
                    
                    Button(action: { showingOutline.toggle() }) {
                        Image(systemName: "list.bullet")
                        Text("Outline")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(showingOutline ? .blue : .secondary)
                    
                    Button(action: { showingRightPanel.toggle() }) {
                        Image(systemName: "sidebar.right")
                        Text("Panel")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(showingRightPanel ? .blue : .secondary)
                }
                
                Spacer()
                
                // Right panel tabs
                if showingRightPanel {
                    Picker("Panel", selection: $rightTab) {
                        Label("Notes", systemImage: "note.text").tag(RightTab.notes)
                        Label("Code", systemImage: "terminal").tag(RightTab.code)
                        Label("Web", systemImage: "globe").tag(RightTab.web)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(maxWidth: 200)
                }
                
                // PDF info
                if let doc = pdf.document {
                    HStack(spacing: 4) {
                        Text("\(pdf.currentPageIndex + 1) of \(doc.pageCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if pdf.isLargePDF {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            
            Divider()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView(isPresented: $showingAbout)
        }
    }
}

// MARK: - Modern Layout Views
struct ModernFullLayoutView: View {
    @ObservedObject var pdf: PDFController
    @ObservedObject var notes: NotesStore
    @ObservedObject var library: LibraryStore
    @Binding var showingLibrary: Bool
    @Binding var showingRightPanel: Bool
    @Binding var showingOutline: Bool
    @Binding var collapseAll: Bool
    @Binding var rightTab: RightTab
    @Binding var showSearchPanel: Bool
    @Binding var showingSettings: Bool
    
    let onOpenFromLibrary: (LibraryItem) -> Void
    let onImportPDFs: () -> Void
    let onOpenPDF: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header
            ModernHeaderView(
                pdf: pdf,
                notes: notes,
                library: library,
                showingLibrary: $showingLibrary,
                showingRightPanel: $showingRightPanel,
                showingOutline: $showingOutline,
                collapseAll: $collapseAll,
                rightTab: $rightTab,
                showSearchPanel: $showSearchPanel,
                showingSettings: $showingSettings,
                onOpenFromLibrary: onOpenFromLibrary,
                onImportPDFs: onImportPDFs,
                onOpenPDF: onOpenPDF
            )
            
            // Main content area
            HSplitView {
                if showingLibrary && !collapseAll {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Library")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: { showingLibrary = false }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        
                        LibraryPane(library: library, pdf: pdf) { item in onOpenFromLibrary(item) }
                    }
                    .frame(minWidth: 200, idealWidth: 280)
                    .background(.regularMaterial)
                }
                
                if showingOutline && !collapseAll {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Outline")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: { showingOutline = false }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        
                        OutlinePane(pdf: pdf)
                    }
                    .frame(minWidth: 200, idealWidth: 300)
                    .background(.regularMaterial)
                }
                
                // Main PDF view
                PDFPane(pdf: pdf, notes: notes)
                    .frame(minWidth: 400)
                
                if showingRightPanel && !collapseAll {
                    VStack(spacing: 0) {
                        HStack {
                            Text(rightTab == .notes ? "Notes" : rightTab == .code ? "Code" : "Web")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: { showingRightPanel = false }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        
                        switch rightTab {
                        case .notes: NotesPane(pdf: pdf, notes: notes)
                        case .code:  CodePane()
                        case .web:   WebPane()
                        }
                    }
                    .frame(minWidth: 300, idealWidth: 400)
                    .background(.regularMaterial)
                }
            }
        }
    }
}

struct ModernCompactLayoutView: View {
    @ObservedObject var pdf: PDFController
    @ObservedObject var notes: NotesStore
    @ObservedObject var library: LibraryStore
    @Binding var showingLibrary: Bool
    @Binding var showingRightPanel: Bool
    @Binding var showingOutline: Bool
    @Binding var collapseAll: Bool
    @Binding var rightTab: RightTab
    @Binding var showSearchPanel: Bool
    @Binding var showingSettings: Bool
    
    let onOpenFromLibrary: (LibraryItem) -> Void
    let onImportPDFs: () -> Void
    let onOpenPDF: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header
            ModernHeaderView(
                pdf: pdf,
                notes: notes,
                library: library,
                showingLibrary: $showingLibrary,
                showingRightPanel: $showingRightPanel,
                showingOutline: $showingOutline,
                collapseAll: $collapseAll,
                rightTab: $rightTab,
                showSearchPanel: $showSearchPanel,
                showingSettings: $showingSettings,
                onOpenFromLibrary: onOpenFromLibrary,
                onImportPDFs: onImportPDFs,
                onOpenPDF: onOpenPDF
            )
            
            // Compact content with tabs
            TabView(selection: $rightTab) {
                // PDF View
                PDFPane(pdf: pdf, notes: notes)
                    .tabItem {
                        Label("PDF", systemImage: "doc.text")
                    }
                    .tag("pdf")
                
                // Notes
                NotesPane(pdf: pdf, notes: notes)
                    .tabItem {
                        Label("Notes", systemImage: "note.text")
                    }
                    .tag(RightTab.notes)
                
                // Code
                CodePane()
                    .tabItem {
                        Label("Code", systemImage: "terminal")
                    }
                    .tag(RightTab.code)
                
                // Web
                WebPane()
                    .tabItem {
                        Label("Web", systemImage: "globe")
                    }
                    .tag(RightTab.web)
            }
        }
    }
}
