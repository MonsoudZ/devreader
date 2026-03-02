import SwiftUI
import Foundation
import AppKit

/// Accessibility enhancement utilities for DevReader (macOS)
/// Provides VoiceOver announcements, keyboard navigation hints, and accessibility helpers
@MainActor
class AccessibilityEnhancer: ObservableObject {
    static let shared = AccessibilityEnhancer()

    @Published var isVoiceOverEnabled: Bool = false
    @Published var isHighContrastEnabled: Bool = false
    @Published var isReduceMotionEnabled: Bool = false

    private init() {
        updateAccessibilitySettings()
    }

    // MARK: - Accessibility Settings Monitoring

    func updateAccessibilitySettings() {
        isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
        isHighContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: - Accessibility Labels and Hints

    static func createAccessibilityLabel(_ element: String, context: String? = nil, action: String? = nil) -> String {
        var label = element
        if let context = context { label += ", \(context)" }
        if let action = action { label += ", \(action)" }
        return label
    }

    static func createAccessibilityHint(_ interaction: String, result: String? = nil) -> String {
        var hint = interaction
        if let result = result { hint += ". \(result)" }
        return hint
    }

    // MARK: - VoiceOver Support (macOS)

    /// Announces important changes to VoiceOver users via NSAccessibility
    static func announceToVoiceOver(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    static func announcePageChange(currentPage: Int, totalPages: Int) {
        announceToVoiceOver("Page \(currentPage) of \(totalPages)")
    }

    static func announceSearchResults(count: Int, query: String) {
        announceToVoiceOver("Found \(count) results for '\(query)'")
    }

    static func announceNoteCreation(noteText: String) {
        announceToVoiceOver("Note created: \(noteText)")
    }

    // MARK: - Keyboard Navigation Support

    static func createKeyboardHint(_ shortcut: String, action: String) -> String {
        return "Press \(shortcut) to \(action)"
    }

    static let keyboardShortcuts: [String: String] = [
        "⌘F": "Search in PDF",
        "⌘O": "Open PDF",
        "⌘W": "Close PDF",
        "⌘+": "Zoom in",
        "⌘-": "Zoom out",
        "⌘0": "Reset zoom",
        "⌘H": "Capture highlight",
        "⌘N": "Add sticky note",
        "⌘S": "New sketch page",
        "⌘1": "Toggle library",
        "⌘2": "Toggle outline",
        "⌘3": "Show notes",
        "⌘4": "Show code",
        "⌘5": "Show web",
        "⌘?": "Show help",
        "⌘,": "Show settings"
    ]

    // MARK: - Screen Reader Support

    static func createScreenReaderDescription(_ element: String, state: String? = nil, value: String? = nil) -> String {
        var description = element
        if let state = state { description += ", \(state)" }
        if let value = value { description += ", \(value)" }
        return description
    }

    // MARK: - High Contrast Support (macOS)

    static func adaptiveColor(_ normalColor: Color, highContrastColor: Color? = nil) -> Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return highContrastColor ?? normalColor
        }
        return normalColor
    }

    // MARK: - Focus Management (macOS)

    static func announceFocusChange(to element: String) {
        announceToVoiceOver("Focused on \(element)")
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibilityEnhancementModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits ?? [])
    }
}

extension View {
    func accessibilityEnhancement(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits? = nil
    ) -> some View {
        self.modifier(AccessibilityEnhancementModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }
}
