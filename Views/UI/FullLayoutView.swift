import SwiftUI
import PDFKit

struct FullLayoutView: View {
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
        HSplitView {
            if showingLibrary && !collapseAll {
                LibraryPane(library: library, pdf: pdf) { item in onOpenFromLibrary(item) }
                    .frame(minWidth: 180, idealWidth: 220)
            }
            if showingOutline && !collapseAll {
                OutlinePane(pdf: pdf)
                    .frame(minWidth: 180, idealWidth: 240)
            }
            PDFPane(pdf: pdf, notes: notes).frame(minWidth: 360)
            if showingRightPanel && !collapseAll {
                VStack(spacing: 0) {
                    Picker("", selection: $rightTab) {
                        Text("Notes").tag(RightTab.notes)
                        Text("Code").tag(RightTab.code)
                        Text("Web").tag(RightTab.web)
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    if !pdf.searchResults.isEmpty {
                        DisclosureGroup(isExpanded: $showSearchPanel) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(pdf.searchResults.enumerated()), id: \.offset) { idx, sel in
                                        let text = (sel.string ?? "Match \(idx+1)").trimmingCharacters(in: .whitespacesAndNewlines)
                                        let pageIdx: Int = {
                                            if let p = sel.pages.first, let d = pdf.document { return d.index(for: p) + 1 } else { return idx + 1 }
                                        }()
                                        Button(action: { pdf.jumpToSearchResult(idx) }) {
                                            HStack(alignment: .top, spacing: 8) {
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
                            .frame(maxHeight: 220)
                        } label: {
                            Text("Search Results (\(pdf.searchResults.count))").font(.subheadline)
                        }
                        .padding(.horizontal, 8)
                    }
                    Divider()
                    switch rightTab {
                    case .notes: NotesPane(pdf: pdf, notes: notes)
                    case .code:  CodePane()
                    case .web:   WebPane()
                    }
                }
                .frame(minWidth: 260, idealWidth: 360)
            }
        }
    }
}
