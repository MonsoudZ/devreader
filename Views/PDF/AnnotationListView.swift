import SwiftUI

struct AnnotationListView: View {
	@ObservedObject var pdf: PDFController
	@State private var pageAnnotations: [(index: Int, record: PDFAnnotationData)] = []

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Annotations").font(.headline)
				Spacer()
				Text("Page \(pdf.currentPageIndex + 1)")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.padding(8)

			Divider()

			if pageAnnotations.isEmpty {
				VStack {
					Spacer()
					Text("No annotations on this page")
						.font(.caption)
						.foregroundStyle(.secondary)
					Spacer()
				}
			} else {
				List {
					ForEach(pageAnnotations, id: \.index) { item in
						annotationRow(item: item)
					}
					.onDelete { offsets in
						deleteAnnotations(at: offsets)
					}
				}
			}

			HStack {
				Button("Remove All on Page") {
					pdf.annotationManager.removeAnnotationsOnCurrentPage()
					refreshAnnotations()
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.disabled(pageAnnotations.isEmpty)
				Spacer()
			}
			.padding(8)
		}
		.onAppear { refreshAnnotations() }
		.onChange(of: pdf.currentPageIndex) { _, _ in refreshAnnotations() }
	}

	private func annotationRow(item: (index: Int, record: PDFAnnotationData)) -> some View {
		HStack {
			Circle()
				.fill(colorForAnnotation(item.record.colorName))
				.frame(width: 10, height: 10)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.record.type.rawValue.capitalized)
					.font(.caption.bold())
				if let text = item.record.text, !text.isEmpty {
					Text(text)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}

			Spacer()

			Button {
				pdf.annotationManager.removeAnnotation(at: item.index)
				refreshAnnotations()
			} label: {
				Image(systemName: "trash")
					.font(.caption)
					.foregroundStyle(.red)
			}
			.buttonStyle(.borderless)
			.accessibilityLabel("Delete annotation")
		}
	}

	private func refreshAnnotations() {
		pageAnnotations = pdf.annotationManager.annotationsOnCurrentPage()
	}

	private func deleteAnnotations(at offsets: IndexSet) {
		// Delete in reverse order to preserve indices
		let indices = offsets.map { pageAnnotations[$0].index }.sorted(by: >)
		for idx in indices {
			pdf.annotationManager.removeAnnotation(at: idx)
		}
		refreshAnnotations()
	}

	private func colorForAnnotation(_ name: String) -> Color {
		switch name {
		case "green": .green
		case "blue": .blue
		case "pink": .pink
		default: .yellow
		}
	}
}
