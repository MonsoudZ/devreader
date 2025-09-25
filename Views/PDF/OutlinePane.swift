import SwiftUI

struct OutlinePane: View {
    @ObservedObject var pdf: PDFController
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []

    private var entries: [(page: Int, title: String)] {
        let allEntries = pdf.outlineMap.keys.sorted().map { ($0, pdf.outlineMap[$0] ?? "") }
        
        // For large PDFs, limit visible entries and add search
        if pdf.isLargePDF {
            let filtered = searchText.isEmpty ? allEntries : allEntries.filter { 
                $0.1.localizedCaseInsensitiveContains(searchText) 
            }
            return Array(filtered.prefix(100)) // Limit to 100 entries for performance
        }
        
        return allEntries
    }
    
    private var groupedEntries: [(section: String, entries: [(page: Int, title: String)])] {
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
                    Text("(\(pdf.outlineMap.count) items)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            
            Divider()
            
            if pdf.isLargePDF {
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
                            ForEach(group.entries, id: \.page) { entry in
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
                    ForEach(entries, id: \.page) { entry in
                        OutlineRow(entry: entry, pdf: pdf)
                    }
                }
            }
        }
    }
}

struct OutlineRow: View {
    let entry: (page: Int, title: String)
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


