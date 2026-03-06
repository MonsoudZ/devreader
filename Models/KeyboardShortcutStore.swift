import SwiftUI
import Combine

/// Identifiers for all customizable keyboard shortcuts.
nonisolated enum ShortcutAction: String, CaseIterable, Sendable {
	case openPDF = "openPDF"
	case importPDFs = "importPDFs"
	case newSketch = "newSketch"
	case highlightSelection = "highlightSelection"
	case underlineSelection = "underlineSelection"
	case strikethroughSelection = "strikethroughSelection"
	case captureHighlight = "captureHighlight"
	case addStickyNote = "addStickyNote"
	case toggleBookmark = "toggleBookmark"
	case toggleSearch = "toggleSearch"
	case toggleLibrary = "toggleLibrary"
	case toggleNotes = "toggleNotes"
	case closePDF = "closePDF"

	var displayName: String {
		switch self {
		case .openPDF: "Open PDF"
		case .importPDFs: "Import PDFs"
		case .newSketch: "New Sketch Page"
		case .highlightSelection: "Highlight Selection"
		case .underlineSelection: "Underline Selection"
		case .strikethroughSelection: "Strikethrough Selection"
		case .captureHighlight: "Highlight → Note"
		case .addStickyNote: "Add Sticky Note"
		case .toggleBookmark: "Toggle Bookmark"
		case .toggleSearch: "Toggle Search"
		case .toggleLibrary: "Toggle Library"
		case .toggleNotes: "Toggle Notes"
		case .closePDF: "Close PDF"
		}
	}

	var category: String {
		switch self {
		case .openPDF, .importPDFs, .newSketch, .closePDF: "File"
		case .highlightSelection, .underlineSelection, .strikethroughSelection,
			 .captureHighlight, .addStickyNote, .toggleBookmark: "Edit"
		case .toggleSearch, .toggleLibrary, .toggleNotes: "View"
		}
	}
}

/// Persistent binding for a single shortcut: key character + modifier flags.
nonisolated struct ShortcutBinding: Codable, Equatable, Sendable {
	var key: String          // Single character, e.g. "o", "j", "?"
	var command: Bool
	var shift: Bool
	var option: Bool
	var control: Bool

	var modifiers: EventModifiers {
		var m: EventModifiers = []
		if command { m.insert(.command) }
		if shift { m.insert(.shift) }
		if option { m.insert(.option) }
		if control { m.insert(.control) }
		return m
	}

	var keyEquivalent: KeyEquivalent {
		KeyEquivalent(Character(key))
	}

	/// Human-readable display string.
	var displayString: String {
		var parts: [String] = []
		if control { parts.append("⌃") }
		if option { parts.append("⌥") }
		if shift { parts.append("⇧") }
		if command { parts.append("⌘") }
		parts.append(key.uppercased())
		return parts.joined()
	}
}

/// Observable store for all keyboard shortcut bindings. Persists to UserDefaults.
@MainActor
final class KeyboardShortcutStore: ObservableObject {
	static let shared = KeyboardShortcutStore()

	@Published var bindings: [ShortcutAction: ShortcutBinding] {
		didSet { save() }
	}

	private let storageKey = "DevReader.KeyboardShortcuts.v1"

	init() {
		if let data = UserDefaults.standard.data(forKey: storageKey),
		   let decoded = try? JSONDecoder().decode([String: ShortcutBinding].self, from: data) {
			var loaded: [ShortcutAction: ShortcutBinding] = [:]
			for (rawKey, binding) in decoded {
				if let action = ShortcutAction(rawValue: rawKey) {
					loaded[action] = binding
				}
			}
			// Fill in any missing defaults
			let defaults = Self.defaults
			for action in ShortcutAction.allCases where loaded[action] == nil {
				loaded[action] = defaults[action]
			}
			self.bindings = loaded
		} else {
			self.bindings = Self.defaults
		}
	}

	func binding(for action: ShortcutAction) -> ShortcutBinding {
		bindings[action] ?? Self.defaults[action]!
	}

	func update(_ action: ShortcutAction, to binding: ShortcutBinding) {
		bindings[action] = binding
	}

	/// Returns actions (excluding `excluded`) that already use the same key combo.
	func conflictingActions(for binding: ShortcutBinding, excluding: ShortcutAction) -> [ShortcutAction] {
		bindings.compactMap { (action, existing) in
			action != excluding && existing == binding ? action : nil
		}
	}

	func resetToDefaults() {
		bindings = Self.defaults
	}

	func resetAction(_ action: ShortcutAction) {
		bindings[action] = Self.defaults[action]
	}

	private func save() {
		let raw = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
		if let data = try? JSONEncoder().encode(raw) {
			UserDefaults.standard.set(data, forKey: storageKey)
		}
	}

	// MARK: - Default Bindings

	static let defaults: [ShortcutAction: ShortcutBinding] = [
		.openPDF:                ShortcutBinding(key: "o", command: true, shift: false, option: false, control: false),
		.importPDFs:             ShortcutBinding(key: "i", command: true, shift: false, option: false, control: false),
		.newSketch:              ShortcutBinding(key: "n", command: true, shift: true, option: false, control: false),
		.highlightSelection:     ShortcutBinding(key: "j", command: true, shift: true, option: false, control: false),
		.underlineSelection:     ShortcutBinding(key: "u", command: true, shift: true, option: false, control: false),
		.strikethroughSelection: ShortcutBinding(key: "x", command: true, shift: true, option: false, control: false),
		.captureHighlight:       ShortcutBinding(key: "h", command: true, shift: true, option: false, control: false),
		.addStickyNote:          ShortcutBinding(key: "s", command: true, shift: true, option: false, control: false),
		.toggleBookmark:         ShortcutBinding(key: "d", command: true, shift: false, option: false, control: false),
		.toggleSearch:           ShortcutBinding(key: "f", command: true, shift: false, option: false, control: false),
		.toggleLibrary:          ShortcutBinding(key: "l", command: true, shift: false, option: false, control: false),
		.toggleNotes:            ShortcutBinding(key: "t", command: true, shift: false, option: false, control: false),
		.closePDF:               ShortcutBinding(key: "w", command: true, shift: false, option: false, control: false),
	]
}
