import SwiftUI

struct OutlinePane: View {
    @ObservedObject var pdf: PDFController

    private var entries: [(page: Int, title: String)] {
        pdf.outlineMap.keys.sorted().map { ($0, pdf.outlineMap[$0] ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline").font(.headline)
                Spacer()
            }
            .padding(8)
            Divider()
            List {
                ForEach(entries, id: \.page) { entry in
                    Button(action: { pdf.goToPage(entry.page) }) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .lineLimit(2)
                                Text("Page \(entry.page + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entry.page == pdf.currentPageIndex {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


