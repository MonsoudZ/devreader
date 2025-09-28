import SwiftUI
import PDFKit

struct CompactLayoutView: View {
    @ObservedObject var pdf: PDFController
    @ObservedObject var notes: NotesStore
    @ObservedObject var library: LibraryStore
    @Binding var showingLibrary: Bool
    @Binding var showingRightPanel: Bool
    @Binding var showingOutline: Bool
    @Binding var collapseAll: Bool
    @Binding var rightTab: RightTab
    @Binding var showSearchPanel: Bool
    
    let onOpenFromLibrary: (LibraryItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showingLibrary = !showingLibrary }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.left")
                        Text("Library")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Toggle Library Panel")
                .accessibilityHint("Show or hide the library sidebar")
                
                Button(action: { showingOutline = !showingOutline }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text("Outline")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Toggle Outline Panel")
                .accessibilityHint("Show or hide the document outline")
                Button(action: { 
                    collapseAll.toggle()
                    if collapseAll {
                        showingLibrary = false
                        showingRightPanel = false
                        showingOutline = false
                    } else {
                        showingLibrary = true
                        showingRightPanel = true
                        showingOutline = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: collapseAll ? "sidebar.left.and.right" : "sidebar.left")
                        Text(collapseAll ? "Expand All" : "Collapse All")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(collapseAll ? "Expand All Panels" : "Collapse All Panels")
                .accessibilityHint("Show or hide all sidebar panels")
                Spacer()
                Picker("Right panel mode", selection: $rightTab) {
                    Text("Notes").tag(RightTab.notes)
                    Text("Code").tag(RightTab.code)
                    Text("Web").tag(RightTab.web)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .accessibilityLabel("Right panel mode")
                .accessibilityValue("Currently showing \(rightTab == .notes ? "Notes" : rightTab == .code ? "Code" : "Web")")
                Button(showingRightPanel ? "Hide Panel" : "Show Panel") { showingRightPanel.toggle() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(showingRightPanel ? "Hide Right Panel" : "Show Right Panel")
                    .accessibilityHint("Toggle the right sidebar panel")
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            HStack(spacing: 0) {
                if showingLibrary && !collapseAll {
                    LibraryPane(library: library, pdf: pdf) { item in onOpenFromLibrary(item) }
                        .frame(width: 260)
                }
                PDFPane(pdf: pdf, notes: notes)
                if showingRightPanel && !collapseAll {
                    Divider()
                    VStack(spacing: 0) {
                        switch rightTab {
                        case .notes: NotesPane(pdf: pdf, notes: notes)
                        case .code:  CodePane()
                        case .web:   WebPane()
                        }
                        if !pdf.searchResults.isEmpty {
                            Divider()
                            DisclosureGroup(isExpanded: $showSearchPanel) {
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(pdf.searchResults.indices, id: \.self) { idx in
                                            let sel = pdf.searchResults[idx]
                                            let text = (sel.string ?? "Match \(idx+1)").trimmingCharacters(in: .whitespacesAndNewlines)
                                            let pageIdx: Int = {
                                                if let p = sel.pages.first, let d = pdf.document { return d.index(for: p) + 1 } else { return idx + 1 }
                                            }()
                                            Button(action: { pdf.jumpToSearchResult(idx) }) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("p.\(pageIdx)").font(.caption).foregroundColor(.secondary)
                                                    Text(text.count > 80 ? String(text.prefix(80)) + "…" : text)
                                                        .font(.caption)
                                                        .lineLimit(2)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Search result \(idx+1), page \(pageIdx)")
                                            .accessibilityValue(text)
                                        }
                                    }
                                    .padding(6)
                                }
                                .frame(maxHeight: 300)
                            } label: {
                                Text("Search Results (\(pdf.searchResults.count))").font(.subheadline)
                            }
                            .padding(6)
                        }
                    }
                    .frame(minWidth: 300, idealWidth: 400)
                }
            }
        }
    }
}
