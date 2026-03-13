import SwiftUI

struct AnnotationListView: View {
	@ObservedObject var pdf: PDFController
	@State private var pageAnnotations: [(index: Int, record: PDFAnnotationData)] = []

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Annotations").font(DS.Typography.heading)
				Spacer()
				Text("Page \(pdf.currentPageIndex + 1)")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.secondary)
			}
			.padding(DS.Spacing.sm)

			Divider()

			if pageAnnotations.isEmpty {
				VStack {
					Spacer()
					Text("No annotations on this page")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
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
				.buttonStyle(DSDestructiveButtonStyle())
				.controlSize(.small)
				.disabled(pageAnnotations.isEmpty)
				.accessibilityLabel("Remove all annotations on current page")
				Spacer()
			}
			.padding(DS.Spacing.sm)
		}
		.onAppear { refreshAnnotations() }
		.onChange(of: pdf.currentPageIndex) { _, _ in refreshAnnotations() }
	}

	private func annotationRow(item: (index: Int, record: PDFAnnotationData)) -> some View {
		HStack {
			Circle()
				.fill(colorForAnnotation(item.record.colorName))
				.frame(width: 10, height: 10)

			Button {
				pdf.goToPage(item.record.pageIndex)
			} label: {
				VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
					HStack(spacing: DS.Spacing.xs) {
						Text(item.record.type.rawValue.capitalized)
							.font(DS.Typography.caption.bold())
						Text("p.\(item.record.pageIndex + 1)")
							.font(DS.Typography.caption2)
							.foregroundStyle(DS.Colors.tertiary)
					}
					if let text = item.record.text, !text.isEmpty {
						Text(text)
							.font(DS.Typography.caption2)
							.foregroundStyle(DS.Colors.secondary)
							.lineLimit(2)
					}
				}
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Go to annotation on page \(item.record.pageIndex + 1)")

			Spacer()

			Button {
				pdf.annotationManager.removeAnnotation(at: item.index)
				refreshAnnotations()
			} label: {
				Image(systemName: "trash")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.error)
			}
			.buttonStyle(DSToolbarButtonStyle())
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
