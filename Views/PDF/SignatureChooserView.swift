import SwiftUI
import AppKit

/// Lets the user pick an existing saved signature or create a new one.
/// On selection/creation, calls the apply callback with the signature NSImage.
struct SignatureChooserView: View {
	@ObservedObject var signatureStore: SignatureStore
	var onApply: (NSImage) -> Void
	var onCancel: () -> Void

	@State private var isShowingPad = false

	var body: some View {
		Group {
			if signatureStore.signatures.isEmpty && !isShowingPad {
				// No saved signatures — go directly to pad
				SignaturePadView(
					onApply: { image, save in
						handleNewSignature(image: image, save: save, type: .drawn)
					},
					onCancel: onCancel
				)
			} else if isShowingPad {
				SignaturePadView(
					onApply: { image, save in
						handleNewSignature(image: image, save: save, type: .drawn)
					},
					onCancel: { isShowingPad = false }
				)
			} else {
				chooserContent
			}
		}
		.frame(minWidth: 460, minHeight: 340)
	}

	// MARK: - Chooser Grid

	private var chooserContent: some View {
		VStack(spacing: 0) {
			Text("Choose Signature")
				.font(.headline)
				.padding(.top, 12)

			ScrollView {
				LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
					ForEach(signatureStore.signatures) { sig in
						signatureCard(sig)
					}
				}
				.padding(16)
			}

			Divider()

			HStack {
				Button("Cancel") { onCancel() }
					.keyboardShortcut(.cancelAction)
				Spacer()
				Button("Create New") { isShowingPad = true }
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 12)
		}
	}

	private func signatureCard(_ signature: SignatureItem) -> some View {
		ZStack(alignment: .topTrailing) {
			Button {
				applyExistingSignature(signature)
			} label: {
				VStack(spacing: 6) {
					if let nsImage = NSImage(data: signature.imageData) {
						Image(nsImage: nsImage)
							.resizable()
							.scaledToFit()
							.frame(height: 60)
					} else {
						Image(systemName: "signature")
							.font(.largeTitle)
							.foregroundColor(.secondary)
							.frame(height: 60)
					}
					Text(signature.name)
						.font(.caption)
						.lineLimit(1)
				}
				.frame(maxWidth: .infinity)
				.padding(10)
				.background(
					RoundedRectangle(cornerRadius: 8)
						.fill(Color(nsColor: .controlBackgroundColor))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.stroke(Color.gray.opacity(0.3), lineWidth: 1)
				)
			}
			.buttonStyle(.plain)

			Button {
				signatureStore.delete(signature)
			} label: {
				Image(systemName: "xmark.circle.fill")
					.foregroundColor(.secondary)
					.font(.system(size: 16))
			}
			.buttonStyle(.plain)
			.padding(4)
			.help("Delete signature")
		}
	}

	// MARK: - Actions

	private func applyExistingSignature(_ signature: SignatureItem) {
		guard let image = NSImage(data: signature.imageData) else { return }
		onApply(image)
	}

	private func handleNewSignature(image: NSImage, save: Bool, type: SignatureItem.SignatureType) {
		if save {
			guard let tiffData = image.tiffRepresentation,
				  let bitmap = NSBitmapImageRep(data: tiffData),
				  let pngData = bitmap.representation(using: .png, properties: [:]) else {
				onApply(image)
				return
			}
			let item = SignatureItem(
				name: "Signature \(signatureStore.signatures.count + 1)",
				type: type,
				imageData: pngData
			)
			signatureStore.add(item)
		}
		onApply(image)
	}
}
