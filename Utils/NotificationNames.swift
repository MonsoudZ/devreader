import Foundation

// MARK: - Notification Names (single source of truth for the entire app)
// Most inter-component communication now uses Combine publishers.
// These remaining names are used for system-level events.
extension Notification.Name {
	// System
	static let memoryPressure   = Notification.Name("DevReader.memoryPressure")
	static let dataRecovery     = Notification.Name("DevReader.dataRecovery")

	// Menu Commands
	static let commandOpenPDF       = Notification.Name("DevReader.commandOpenPDF")
	static let commandImportPDFs    = Notification.Name("DevReader.commandImportPDFs")
	static let commandToggleLibrary = Notification.Name("DevReader.commandToggleLibrary")
	static let commandToggleNotes   = Notification.Name("DevReader.commandToggleNotes")
	static let commandToggleSearch  = Notification.Name("DevReader.commandToggleSearch")

	// Dock Menu
	static let openRecentFromDock  = Notification.Name("DevReader.openRecentFromDock")
	static let clearRecentsFromDock = Notification.Name("DevReader.clearRecentsFromDock")
}
