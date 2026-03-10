import SwiftUI
@preconcurrency import PDFKit

struct PDFFormView: View {
	@ObservedObject var pdf: PDFController
	@State private var formFields: [FormFieldInfo] = []

	struct FormFieldInfo: Identifiable {
		let id = UUID()
		let pageIndex: Int
		let fieldName: String
		let fieldType: String
		let annotation: PDFAnnotation
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Form Fields").font(.headline)
				Spacer()
				Text("\(formFields.count) fields")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.padding(8)

			Divider()

			if formFields.isEmpty {
				VStack {
					Spacer()
					if pdf.document != nil {
						Image(systemName: "doc.text.magnifyingglass")
							.font(.largeTitle)
							.foregroundStyle(.secondary)
						Text("No form fields found")
							.font(.caption)
							.foregroundStyle(.secondary)
						Text("This PDF does not contain fillable form fields.")
							.font(.caption2)
							.foregroundStyle(.tertiary)
							.padding(.top, 2)
					} else {
						Text("No PDF open")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}
			} else {
				List {
					ForEach(formFields) { field in
						Button {
							navigateToField(field)
						} label: {
							HStack {
								Image(systemName: iconForFieldType(field.fieldType))
									.foregroundStyle(.secondary)
									.frame(width: 20)
								VStack(alignment: .leading, spacing: 2) {
									Text(field.fieldName.isEmpty ? "Unnamed Field" : field.fieldName)
										.font(.caption)
									HStack {
										Text("Page \(field.pageIndex + 1)")
										Text(field.fieldType)
									}
									.font(.caption2)
									.foregroundStyle(.secondary)
								}
								Spacer()
								Image(systemName: "chevron.right")
									.font(.caption2)
									.foregroundStyle(.tertiary)
							}
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
		.onAppear { scanFormFields() }
		.onChange(of: pdf.document) { _, _ in scanFormFields() }
		.accessibilityLabel("Form fields panel")
	}

	private func scanFormFields() {
		guard let doc = pdf.document else {
			formFields = []
			return
		}
		var fields: [FormFieldInfo] = []
		for i in 0..<doc.pageCount {
			guard let page = doc.page(at: i) else { continue }
			for annotation in page.annotations {
				guard annotation.type == "Widget" else { continue }
				let fieldType = widgetType(for: annotation)
				let name = annotation.fieldName ?? ""
				fields.append(FormFieldInfo(
					pageIndex: i,
					fieldName: name,
					fieldType: fieldType,
					annotation: annotation
				))
			}
		}
		formFields = fields
	}

	private func navigateToField(_ field: FormFieldInfo) {
		pdf.goToPage(field.pageIndex)
		// Scroll to the annotation's bounds
		if let pdfView = pdf.selectionBridge.pdfView,
		   let doc = pdf.document,
		   let page = doc.page(at: field.pageIndex) {
			let bounds = field.annotation.bounds
			let dest = PDFDestination(page: page, at: CGPoint(
				x: bounds.midX,
				y: bounds.midY
			))
			pdfView.go(to: dest)
		}
	}

	private func widgetType(for annotation: PDFAnnotation) -> String {
		let ft = annotation.widgetFieldType
		if ft == .text { return "Text Field" }
		if ft == .button { return "Button/Checkbox" }
		if ft == .choice { return "Dropdown/List" }
		if ft == .signature { return "Signature" }
		return "Widget"
	}

	private func iconForFieldType(_ type: String) -> String {
		switch type {
		case "Text Field": return "character.cursor.ibeam"
		case "Button/Checkbox": return "checkmark.square"
		case "Dropdown/List": return "list.bullet"
		case "Signature": return "signature"
		default: return "square"
		}
	}
}
