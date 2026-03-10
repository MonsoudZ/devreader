import SwiftUI

private struct OutlineEntry: Identifiable {
    let id = UUID()
    let page: Int
    let title: String
}

struct OutlinePane: View {
    @ObservedObject var pdf: PDFController
    @ObservedObject var outlineManager: PDFOutlineManager
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []

    private var entries: [OutlineEntry] {
        let allEntries = outlineManager.outlineMap.keys.sorted().map { OutlineEntry(page: $0, title: outlineManager.outlineMap[$0] ?? "") }

        // For large PDFs, limit visible entries and add search
        if pdf.isLargePDF {
            let filtered = searchText.isEmpty ? allEntries : allEntries.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
            return Array(filtered.prefix(100))
        }

        return allEntries
    }

    private var groupedEntries: [(section: String, entries: [OutlineEntry])] {
        if !pdf.isLargePDF {
            return [("", entries)]
        }

        // Group by first part of title for large PDFs
        let grouped = Dictionary(grouping: entries) { entry in
            let components = entry.title.components(separatedBy: " › ")
            return components.first ?? "Other"
        }

        return grouped.map { (section: $0.key, entries: $0.value) }
            .sorted { $0.section < $1.section }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline").font(.headline)
                if pdf.isLargePDF {
                    Text("(\(outlineManager.outlineMap.count) items)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(outlineManager.outlineMap.count) outline items")
                }
                Spacer()
            }
            .padding(8)
            
            // Search for large PDFs
            if pdf.isLargePDF {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search outline...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("outlineSearchField")
                        .accessibilityLabel("Search outline")
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            
            Divider()

            if entries.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.indent",
                    title: "No Outline Available",
                    subtitle: "This PDF does not contain a table of contents."
                )
            } else if pdf.isLargePDF {
                // Grouped view for large PDFs
                List {
                    ForEach(groupedEntries, id: \.section) { group in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedSections.contains(group.section) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedSections.insert(group.section)
                                    } else {
                                        expandedSections.remove(group.section)
                                    }
                                }
                            )
                        ) {
                            ForEach(group.entries) { entry in
                                OutlineRow(entry: entry, pdf: pdf)
                            }
                        } label: {
                            HStack {
                                Text(group.section)
                                    .font(.headline)
                                Spacer()
                                Text("\(group.entries.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                // Simple list for smaller PDFs
                List {
                    ForEach(entries) { entry in
                        OutlineRow(entry: entry, pdf: pdf)
                    }
                }
            }
        }
    }
}

private struct OutlineRow: View {
    let entry: OutlineEntry
    @ObservedObject var pdf: PDFController

    var body: some View {
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


