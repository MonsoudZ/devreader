import SwiftUI
import PDFKit

/// Resizable search results panel with drag handle
struct ResizableSearchPanel: View {
    @Binding var isExpanded: Bool
    @Binding var panelHeight: CGFloat
    let searchResults: [PDFSelection]
    let onJumpToResult: (Int) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 400
    private let defaultHeight: CGFloat = 220
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .cornerRadius(2)
                Spacer()
            }
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let newHeight = panelHeight - value.translation.height
                        panelHeight = max(minHeight, min(maxHeight, newHeight))
                        dragOffset = 0
                        isDragging = false
                    }
            )
            
            if isExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(searchResults.indices, id: \.self) { idx in
                            let sel = searchResults[idx]
                            let text = (sel.string ?? "Match \(idx+1)").trimmingCharacters(in: .whitespacesAndNewlines)
                            let pageIdx = idx + 1
                            
                            Button(action: { onJumpToResult(idx) }) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("p.\(pageIdx)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                .frame(height: panelHeight)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .onAppear {
            if panelHeight == 0 {
                panelHeight = defaultHeight
            }
        }
    }
}

// MARK: - Preview

struct ResizableSearchPanel_Previews: PreviewProvider {
    static var previews: some View {
        ResizableSearchPanel(
            isExpanded: .constant(true),
            panelHeight: .constant(220),
            searchResults: [],
            onJumpToResult: { _ in }
        )
        .frame(width: 300, height: 300)
    }
}
