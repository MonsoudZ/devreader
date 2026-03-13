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
                            .foregroundStyle(DS.Colors.secondary)
                            .frame(width: DS.Layout.minTapTarget, height: DS.Layout.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DSToolbarButtonStyle())
                    .help("New Tab")
                    .accessibilityLabel("New tab")
                    .accessibilityIdentifier("newTabButton")
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .frame(height: DS.Layout.tabBarHeight)
        .background(DS.Colors.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .animation(DS.Animation.standard, value: tabManager.tabs.count)
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
            HStack(spacing: DS.Spacing.xs) {
                Text(tab.title)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .leading)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.Colors.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0.5)
                .help("Close Tab")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xxs)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(isActive
                      ? DS.Colors.selectedSurface
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(isActive
                              ? DS.Colors.accent.opacity(0.3)
                              : Color.clear,
                              lineWidth: 1)
        )
        .accessibilityIdentifier("tab_\(tab.id.uuidString)")
    }
}
