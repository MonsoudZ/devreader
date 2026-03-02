import Foundation

// MARK: - Notification Names (single source of truth for the entire app)
extension Notification.Name {
	// File operations
	static let openPDF          = Notification.Name("DevReader.openPDF")
	static let importPDFs       = Notification.Name("DevReader.importPDFs")
	static let closePDF         = Notification.Name("DevReader.closePDF")

	// PDF events
	static let pdfLoadError     = Notification.Name("DevReader.pdfLoadError")
	static let currentPDFURLDidChange = Notification.Name("DevReader.currentPDFURLDidChange")

	// Editing
	static let captureHighlight = Notification.Name("DevReader.captureHighlight")
	static let addStickyNote    = Notification.Name("DevReader.addStickyNote")
	static let addNote          = Notification.Name("DevReader.addNote")
	static let newSketchPage    = Notification.Name("DevReader.newSketchPage")

	// UI toggles
	static let toggleSearch     = Notification.Name("DevReader.toggleSearch")
	static let toggleLibrary    = Notification.Name("DevReader.toggleLibrary")
	static let toggleNotes      = Notification.Name("DevReader.toggleNotes")

	// Overlays / sheets
	static let showHelp         = Notification.Name("DevReader.showHelp")
	static let showOnboarding   = Notification.Name("DevReader.showOnboarding")
	static let showAbout        = Notification.Name("DevReader.showAbout")
	static let showToast        = Notification.Name("DevReader.showToast")

	// System
	static let memoryPressure   = Notification.Name("DevReader.memoryPressure")
	static let sessionCorrupted = Notification.Name("DevReader.sessionCorrupted")
	static let dataRecovery     = Notification.Name("DevReader.dataRecovery")
}
