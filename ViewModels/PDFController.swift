import Foundation
import PDFKit
import Combine

@MainActor
final class PDFController: ObservableObject {
	@Published var document: PDFDocument?
	@Published var currentPageIndex: Int = 0 { didSet { persist() } }
	@Published var outlineMap: [Int: String] = [:]
	@Published var bookmarks: Set<Int> = []
	
	private let sessionKey = "DevReader.Session.v1"
	private let bookmarksKey = "DevReader.Bookmarks.v1"
	private var currentPDFURL: URL?
	private let annotationFolderName = "Annotations"
	
	init() { restore() }
	
	func load(url: URL) {
		if let currentURL = currentPDFURL { savePageForPDF(currentURL) }
		let sourceURL: URL = {
			if let annotated = self.annotatedURL(for: url), FileManager.default.fileExists(atPath: annotated.path) {
				return annotated
			}
			return url
		}()
		if let doc = PDFDocument(url: sourceURL) {
			self.document = doc
			self.currentPDFURL = url
			rebuildOutlineMap()
			loadPageForPDF(url)
			loadBookmarks()
			onPDFChanged?(url)
		}
	}
	
	func clearSession() {
		if let currentURL = currentPDFURL { savePageForPDF(currentURL) }
		document = nil
		currentPDFURL = nil
		currentPageIndex = 0
		outlineMap.removeAll()
		bookmarks.removeAll()
		UserDefaults.standard.removeObject(forKey: sessionKey)
		onPDFChanged?(nil)
	}
	
	var onPDFChanged: ((URL?) -> Void)?
	
	func goToPage(_ pageIndex: Int) {
		guard let doc = document, pageIndex >= 0, pageIndex < doc.pageCount else { return }
		currentPageIndex = pageIndex
		if let url = currentPDFURL { savePageForPDF(url) }
	}
	
	func toggleBookmark(_ pageIndex: Int) {
		if bookmarks.contains(pageIndex) { bookmarks.remove(pageIndex) } else { bookmarks.insert(pageIndex) }
		saveBookmarks()
	}
	
	func isBookmarked(_ pageIndex: Int) -> Bool { bookmarks.contains(pageIndex) }
	
	private func saveBookmarks() {
		guard let url = currentPDFURL else { return }
		let key = "\(bookmarksKey).\(url.path.hashValue)"
		UserDefaults.standard.set(Array(bookmarks), forKey: key)
	}
	
	private func loadBookmarks() {
		guard let url = currentPDFURL else { return }
		let key = "\(bookmarksKey).\(url.path.hashValue)"
		if let arr = UserDefaults.standard.array(forKey: key) as? [Int] { bookmarks = Set(arr) }
	}
	
	func rebuildOutlineMap() {
		outlineMap.removeAll()
		guard let doc = document else { return }
		if let root = doc.outlineRoot {
			func walk(_ node: PDFOutline, path: [String]) {
				let title = node.label ?? "Untitled"
				let newPath = path + [title]
				if let dest = node.destination, let page = dest.page {
					let idx = doc.index(for: page)
					outlineMap[idx] = newPath.joined(separator: " › ")
				}
				for i in 0..<node.numberOfChildren { if let child = node.child(at: i) { walk(child, path: newPath) } }
			}
			for i in 0..<root.numberOfChildren { if let c = root.child(at: i) { walk(c, path: []) } }
		}
	}
	
	private func persist() { if let url = currentPDFURL { savePageForPDF(url) } }
	
	func savePageForPDF(_ url: URL) {
		let pageKey = "\(sessionKey).\(url.path.hashValue)"
		UserDefaults.standard.set(currentPageIndex, forKey: pageKey)
	}
	
	private func loadPageForPDF(_ url: URL) {
		let pageKey = "\(sessionKey).\(url.path.hashValue)"
		let savedPage = UserDefaults.standard.integer(forKey: pageKey)
		if savedPage > 0 {
			let lastIndex = max(0, (document?.pageCount ?? 1) - 1)
			currentPageIndex = min(savedPage, lastIndex)
		} else {
			currentPageIndex = 0
		}
	}
	
	private func restore() {
		guard let data = UserDefaults.standard.data(forKey: sessionKey),
				let session = try? JSONDecoder().decode(SessionData.self, from: data),
				let url = session.documentURL else { return }
		guard FileManager.default.fileExists(atPath: url.path) else {
			UserDefaults.standard.removeObject(forKey: sessionKey); return
		}
		let sourceURL: URL = {
			if let annotated = self.annotatedURL(for: url), FileManager.default.fileExists(atPath: annotated.path) {
				return annotated
			}
			return url
		}()
		if let doc = PDFDocument(url: sourceURL), doc.pageCount > 0 {
			self.document = doc; self.currentPDFURL = url; rebuildOutlineMap(); loadPageForPDF(url); loadBookmarks(); onPDFChanged?(url)
		} else {
			UserDefaults.standard.removeObject(forKey: sessionKey)
		}
	}
	
	private func appSupportDirectory() -> URL? {
		guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
		let dir = base.appendingPathComponent("DevReader", isDirectory: true).appendingPathComponent(annotationFolderName, isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}
	
	func annotatedURL(for original: URL) -> URL? {
		guard let dir = appSupportDirectory() else { return nil }
		let file = String(original.path.hashValue) + ".pdf"
		return dir.appendingPathComponent(file)
	}
	
	func saveAnnotatedCopy() {
		guard let doc = document, let original = currentPDFURL, let dst = annotatedURL(for: original) else { return }
		if let data = doc.dataRepresentation() { try? data.write(to: dst) }
	}
}
