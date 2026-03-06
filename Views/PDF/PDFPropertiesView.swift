import SwiftUI

struct PDFPropertiesView: View {
	let properties: [(String, String)]
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Document Properties").font(.headline)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 12)

			Divider()

			if properties.isEmpty {
				VStack {
					Spacer()
					Text("No PDF open")
						.font(.caption)
						.foregroundStyle(.secondary)
					Spacer()
				}
			} else {
				List {
					ForEach(properties, id: \.0) { key, value in
						HStack(alignment: .top) {
							Text(key)
								.font(.caption.bold())
								.frame(width: 120, alignment: .trailing)
								.foregroundStyle(.secondary)
							Text(value)
								.font(.caption)
								.textSelection(.enabled)
						}
					}
				}
			}
		}
		.frame(minWidth: 400, minHeight: 300)
	}
}
