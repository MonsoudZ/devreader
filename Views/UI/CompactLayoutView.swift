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
    @Binding var rightTabRaw: String
    @Binding var showSearchPanel: Bool
    
    let onOpenFromLibrary: (LibraryItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Library") { showingLibrary = !showingLibrary }.buttonStyle(.bordered)
                Button("Outline") { showingOutline = !showingOutline }.buttonStyle(.bordered)
                Button(collapseAll ? "Expand All" : "Collapse All") { 
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
                }.buttonStyle(.bordered)
                Spacer()
                Picker("", selection: $rightTab) {
                    Text("Notes").tag(RightTab.notes)
                    Text("Code").tag(RightTab.code)
                    Text("Web").tag(RightTab.web)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .onChange(of: rightTab) { _, newValue in
                    switch newValue {
                    case .notes: rightTabRaw = "notes"
                    case .code: rightTabRaw = "code"
                    case .web: rightTabRaw = "web"
                    }
                }
                Button(showingRightPanel ? "Hide Panel" : "Show Panel") { showingRightPanel.toggle() }.buttonStyle(.bordered)
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
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(pdf.searchResults.enumerated()), id: \.offset) { idx, sel in
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
                                        }
                                    }
                                    .padding(6)
                                }
                                .frame(maxHeight: 180)
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
