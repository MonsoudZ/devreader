import SwiftUI
import PDFKit

/// Floating toolbar that appears above selected text in the PDF,
/// offering quick annotation actions.
struct PDFSelectionToolbar: View {
    let onHighlight: () -> Void
    let onUnderline: () -> Void
    let onStrikethrough: () -> Void
    let onCopy: () -> Void
    let onNote: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            toolbarButton("highlighter", label: "Highlight", color: .yellow, action: onHighlight)
            toolbarButton("underline", label: "Underline", color: DS.Colors.accent, action: onUnderline)
            toolbarButton("strikethrough", label: "Strikethrough", color: DS.Colors.error, action: onStrikethrough)
            Divider()
                .frame(height: 18)
            toolbarButton("doc.on.clipboard", label: "Copy", color: DS.Colors.secondary, action: onCopy)
            toolbarButton("note.text.badge.plus", label: "Add Note", color: DS.Colors.info, action: onNote)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }

    private func toolbarButton(_ icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
