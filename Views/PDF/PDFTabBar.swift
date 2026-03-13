import SwiftUI

/// Horizontal tab bar displayed above the PDF viewer when 2+ tabs are open.
struct PDFTabBar: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    PDFTabButton(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTabID,
                        onSelect: { tabManager.switchTo(tab.id) },
                        onClose: { tabManager.closeTab(tab.id) }
                    )
                }

                // "+" button to add a new tab
                if tabManager.tabs.count < TabManager.maxTabs {
                    Button {
                        _ = tabManager.addTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Tab")
                    .accessibilityLabel("New tab")
                    .accessibilityIdentifier("newTabButton")
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 32)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .animation(.easeInOut, value: tabManager.tabs.count)
    }
}

// MARK: - Individual Tab Button

private struct PDFTabButton: View {
    let tab: PDFTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: @MainActor () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .leading)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0.5)
                .help("Close Tab")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                      ? Color(NSColor.controlAccentColor).opacity(0.15)
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive
                              ? Color(NSColor.controlAccentColor).opacity(0.3)
                              : Color.clear,
                              lineWidth: 1)
        )
        .accessibilityIdentifier("tab_\(tab.id.uuidString)")
    }
}
