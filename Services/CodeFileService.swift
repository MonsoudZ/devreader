import Foundation
import AppKit

/// File I/O operations for the code editor, with path traversal validation and recent file tracking.
enum CodeFileService {
	private static let recentFilesKey = "DevReader.Code.RecentFiles.v1"
	private static let maxRecentFiles = 20

	/// Allowed base directories for file operations. Files outside these are rejected.
	private static let allowedRoots: [URL] = {
		var roots: [URL] = []
		if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
			roots.append(home)
		}
		roots.append(FileManager.default.temporaryDirectory)
		return roots
	}()

	// MARK: - Path Validation

	/// Returns true if the URL resolves to a path within allowed directories.
	/// Prevents path traversal attacks (e.g. `../../etc/passwd`).
	static func isPathAllowed(_ url: URL) -> Bool {
		let resolved = url.standardizedFileURL.path
		return allowedRoots.contains { resolved.hasPrefix($0.standardizedFileURL.path) }
	}

	// MARK: - Recent Files

	static func loadRecentFiles() -> [URL] {
		guard let paths = UserDefaults.standard.stringArray(forKey: recentFilesKey) else {
			return []
		}
		return paths.compactMap { URL(fileURLWithPath: $0) }
			.filter { FileManager.default.fileExists(atPath: $0.path) }
	}

	static func addToRecentFiles(_ url: URL) {
		var paths = UserDefaults.standard.stringArray(forKey: recentFilesKey) ?? []
		paths.removeAll { $0 == url.path }
		paths.insert(url.path, at: 0)
		if paths.count > maxRecentFiles { paths = Array(paths.prefix(maxRecentFiles)) }
		UserDefaults.standard.set(paths, forKey: recentFilesKey)
	}

	// MARK: - File Operations

	/// Reads file content as UTF-8 text. Returns nil if path validation fails.
	static func loadFile(at url: URL) throws -> String {
		guard isPathAllowed(url) else {
			throw CodeFileError.pathTraversal(url.path)
		}
		return try String(contentsOf: url, encoding: .utf8)
	}

	/// Deletes a file after confirming with the user. Returns true if deleted.
	@discardableResult
	static func deleteFileWithConfirmation(_ url: URL) throws -> Bool {
		guard isPathAllowed(url) else {
			throw CodeFileError.pathTraversal(url.path)
		}
		guard FileManager.default.fileExists(atPath: url.path) else {
			throw CodeFileError.fileNotFound(url.path)
		}

		let alert = NSAlert()
		alert.messageText = "Delete File"
		alert.informativeText = "Are you sure you want to delete \"\(url.lastPathComponent)\"? This cannot be undone."
		alert.alertStyle = .warning
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		guard alert.runModal() == .alertFirstButtonReturn else {
			return false
		}

		try FileManager.default.removeItem(at: url)
		return true
	}

	/// Detects the CodeLang from a file extension.
	static func detectLanguage(for url: URL) -> CodeLang? {
		let ext = url.pathExtension.lowercased()
		return CodeLang.allCases.first { $0.fileExtension == ext }
	}
}

nonisolated enum CodeFileError: LocalizedError {
	case pathTraversal(String)
	case fileNotFound(String)

	var errorDescription: String? {
		switch self {
		case .pathTraversal(let path):
			return "Access denied: \(path) is outside allowed directories"
		case .fileNotFound(let path):
			return "File not found: \(path)"
		}
	}
}
