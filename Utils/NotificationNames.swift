import Foundation

// MARK: - Notification Names (single source of truth for the entire app)
// Most inter-component communication now uses Combine publishers.
// These remaining names are used for system-level events.
extension Notification.Name {
	// System
	static let memoryPressure   = Notification.Name("DevReader.memoryPressure")
	static let dataRecovery     = Notification.Name("DevReader.dataRecovery")

	// Dock Menu
	static let openRecentFromDock  = Notification.Name("DevReader.openRecentFromDock")
	static let clearRecentsFromDock = Notification.Name("DevReader.clearRecentsFromDock")
}
