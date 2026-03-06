import SwiftUI
import Carbon.HIToolbox

struct ShortcutEditorView: View {
	@ObservedObject var store: KeyboardShortcutStore

	private var groupedActions: [(category: String, actions: [ShortcutAction])] {
		let groups = Dictionary(grouping: ShortcutAction.allCases) { $0.category }
		return ["File", "Edit", "View"].compactMap { cat in
			guard let actions = groups[cat] else { return nil }
			return (category: cat, actions: actions)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(groupedActions, id: \.category) { group in
				Text(group.category)
					.font(.caption.bold())
					.foregroundStyle(.secondary)
					.padding(.top, 4)
				ForEach(group.actions, id: \.rawValue) { action in
					ShortcutRow(action: action, store: store)
				}
			}
			HStack {
				Spacer()
				Button("Reset All to Defaults") {
					store.resetToDefaults()
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("resetShortcuts")
				.accessibilityLabel("Reset all shortcuts to defaults")
			}
			.padding(.top, 4)
		}
	}
}

private struct ShortcutRow: View {
	let action: ShortcutAction
	@ObservedObject var store: KeyboardShortcutStore
	@State private var isRecording = false
	@State private var recordedBinding: ShortcutBinding?

	private var binding: ShortcutBinding {
		store.binding(for: action)
	}

	private var isDefault: Bool {
		binding == KeyboardShortcutStore.defaults[action]
	}

	var body: some View {
		HStack {
			Text(action.displayName)
				.font(.caption)
				.frame(width: 160, alignment: .leading)

			if isRecording {
				ShortcutRecorder { newBinding in
					if let b = newBinding {
						store.update(action, to: b)
					}
					isRecording = false
				}
				.frame(width: 120, height: 22)
			} else {
				Button {
					isRecording = true
				} label: {
					Text(binding.displayString)
						.font(.system(.caption, design: .monospaced))
						.frame(width: 100)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color(NSColor.controlBackgroundColor))
						.cornerRadius(4)
						.overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.quaternary))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Shortcut for \(action.displayName): \(binding.displayString)")
				.accessibilityHint("Click to record a new shortcut")
			}

			if !isDefault {
				Button {
					store.resetAction(action)
				} label: {
					Image(systemName: "arrow.counterclockwise")
						.font(.caption)
				}
				.buttonStyle(.borderless)
				.accessibilityLabel("Reset to default")
			}
		}
	}
}

/// An NSView-backed key recorder that captures the next key combo.
struct ShortcutRecorder: NSViewRepresentable {
	var onRecord: (ShortcutBinding?) -> Void

	func makeNSView(context: Context) -> ShortcutRecorderNSView {
		let view = ShortcutRecorderNSView()
		view.onRecord = onRecord
		return view
	}

	func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {}

	final class ShortcutRecorderNSView: NSView {
		var onRecord: ((ShortcutBinding?) -> Void)?
		private let label = NSTextField(labelWithString: "Press shortcut…")

		override init(frame frameRect: NSRect) {
			super.init(frame: frameRect)
			label.font = .systemFont(ofSize: 11)
			label.textColor = .secondaryLabelColor
			label.alignment = .center
			addSubview(label)
			wantsLayer = true
			layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
			layer?.cornerRadius = 4
		}

		required init?(coder: NSCoder) { nil }

		override func layout() {
			super.layout()
			label.frame = bounds
		}

		override var acceptsFirstResponder: Bool { true }

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			window?.makeFirstResponder(self)
		}

		override func keyDown(with event: NSEvent) {
			guard let chars = event.charactersIgnoringModifiers?.lowercased(),
				  !chars.isEmpty,
				  let char = chars.first else {
				onRecord?(nil)
				return
			}

			// Ignore bare modifier keys
			let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
			guard flags.contains(.command) || flags.contains(.control) else {
				// Require at least Cmd or Ctrl
				return
			}

			// Escape cancels
			if event.keyCode == UInt16(kVK_Escape) {
				onRecord?(nil)
				return
			}

			let binding = ShortcutBinding(
				key: String(char),
				command: flags.contains(.command),
				shift: flags.contains(.shift),
				option: flags.contains(.option),
				control: flags.contains(.control)
			)
			onRecord?(binding)
		}

		override func resignFirstResponder() -> Bool {
			onRecord?(nil)
			return super.resignFirstResponder()
		}
	}
}
