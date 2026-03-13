import SwiftUI

struct PDFPropertiesView: View {
	let properties: [(String, String)]
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Document Properties").font(DS.Typography.heading)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
			}
			.padding(.horizontal, DS.Spacing.xl)
			.padding(.vertical, DS.Spacing.md)

			Divider()

			if properties.isEmpty {
				VStack {
					Spacer()
					Text("No PDF open")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
					Spacer()
				}
			} else {
				List {
					ForEach(properties, id: \.0) { key, value in
						HStack(alignment: .top) {
							Text(key)
								.font(DS.Typography.caption.bold())
								.frame(width: 120, alignment: .trailing)
								.foregroundStyle(DS.Colors.secondary)
							Text(value)
								.font(DS.Typography.caption)
								.textSelection(.enabled)
						}
					}
				}
			}
		}
		.frame(minWidth: 400, minHeight: 300)
	}
}
