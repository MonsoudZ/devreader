import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var recentsSubscription: AnyCancellable?

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = NSMenu()

		Task { @MainActor in
			// This runs synchronously enough for the menu since we're already on main
		}

		// Build menu synchronously on main thread using the shared bookmark manager
		// We access the bookmark manager via the app environment stored in the first window's root view
		let recentURLs = loadRecentURLs()

		if recentURLs.isEmpty {
			let item = NSMenuItem(title: "No Recent Files", action: nil, keyEquivalent: "")
			item.isEnabled = false
			menu.addItem(item)
		} else {
			for url in recentURLs.prefix(10) {
				let item = NSMenuItem(
					title: url.lastPathComponent,
					action: #selector(openRecentFile(_:)),
					keyEquivalent: ""
				)
				item.target = self
				item.representedObject = url
				item.toolTip = url.path
				menu.addItem(item)
			}

			menu.addItem(NSMenuItem.separator())

			let clearItem = NSMenuItem(
				title: "Clear Recent Files",
				action: #selector(clearRecentFiles),
				keyEquivalent: ""
			)
			clearItem.target = self
			menu.addItem(clearItem)
		}

		return menu
	}

	@objc private func openRecentFile(_ sender: NSMenuItem) {
		guard let url = sender.representedObject as? URL else { return }
		NotificationCenter.default.post(
			name: .openRecentFromDock,
			object: url
		)
	}

	@objc private func clearRecentFiles() {
		NotificationCenter.default.post(
			name: .clearRecentsFromDock,
			object: nil
		)
	}

	private func loadRecentURLs() -> [URL] {
		// Load directly from persistence to avoid threading issues
		let recentsKey = "DevReader.Recents.v1"
		let pinnedKey = "DevReader.Pinned.v1"
		let pinned: [URL] = PersistenceService.loadCodable([URL].self, forKey: pinnedKey) ?? []
		let recents: [URL] = PersistenceService.loadCodable([URL].self, forKey: recentsKey) ?? []
		return pinned + recents
	}
}
