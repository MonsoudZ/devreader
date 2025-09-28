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
    @State private var searchPanelHeight: CGFloat = 220
    
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
                    Picker("Right panel mode", selection: $rightTab) {
                        Text("Notes").tag(RightTab.notes)
                        Text("Code").tag(RightTab.code)
                        Text("Web").tag(RightTab.web)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Right panel mode")
                    .accessibilityValue("Currently showing \(rightTab == .notes ? "Notes" : rightTab == .code ? "Code" : "Web")")
                    .padding(8)
                    if !pdf.searchResults.isEmpty {
                        ResizableSearchPanel(
                            isExpanded: $showSearchPanel,
                            panelHeight: $searchPanelHeight,
                            searchResults: pdf.searchResults,
                            onJumpToResult: { idx in pdf.jumpToSearchResult(idx) }
                        )
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
