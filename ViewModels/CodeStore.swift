import Foundation
import Combine
import os.log

/// Manages code snippets and persistence
@MainActor
class CodeStore: ObservableObject {
    @Published var codeSnippets: [CodeSnippet] = []
    @Published var currentSnippet: CodeSnippet?
    
    private let persistenceService: CodePersistenceProtocol
    private var persistWorkItem: DispatchWorkItem?

    init(persistenceService: CodePersistenceProtocol? = nil) {
        self.persistenceService = persistenceService ?? CodePersistenceService()
        loadCodeSnippets()
    }
    
    // MARK: - Code Management
    
    func createSnippet(title: String, content: String, language: String = "swift") {
        let snippet = CodeSnippet(
            title: title,
            content: content,
            language: language,
            createdDate: Date(),
            lastModified: Date()
        )
        
        codeSnippets.append(snippet)
        currentSnippet = snippet
        saveCodeSnippets()
    }
    
    func updateCurrentSnippet(_ content: String) {
        guard var snippet = currentSnippet else { return }

        snippet.content = content
        snippet.lastModified = Date()

        if let index = codeSnippets.firstIndex(where: { $0.id == snippet.id }) {
            codeSnippets[index] = snippet
            currentSnippet = snippet
            schedulePersist()
        }
    }
    
    func deleteSnippet(_ snippet: CodeSnippet) {
        codeSnippets.removeAll { $0.id == snippet.id }
        if currentSnippet?.id == snippet.id {
            currentSnippet = nil
        }
        saveCodeSnippets()
    }
    
    private func sanitizedFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.unicodeScalars.filter { !invalidChars.contains($0) }
        let result = String(String.UnicodeScalarView(sanitized))
        return result.isEmpty ? "untitled" : result
    }

    func exportSnippet(_ snippet: CodeSnippet) -> URL? {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFilename(snippet.title)).\(snippet.language)")

        do {
            try snippet.content.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            logError(AppLog.app, "Failed to export snippet: \(error)")
            return nil
        }
    }
    
    // MARK: - Persistence

    private func schedulePersist() {
        persistWorkItem?.cancel()
        let workItem = DispatchWorkItem { @Sendable [weak self] in
            Task { @MainActor in
                self?.saveCodeSnippets()
            }
        }
        persistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func flushPendingPersistence() {
        if let workItem = persistWorkItem {
            workItem.cancel()
            persistWorkItem = nil
            saveCodeSnippets()
        }
    }

    private func saveCodeSnippets() {
        do {
            try persistenceService.saveCodeSnippets(codeSnippets)
        } catch {
            logError(AppLog.app, "Failed to save code snippets: \(error)")
        }
    }
    
    private func loadCodeSnippets() {
        codeSnippets = persistenceService.loadCodeSnippets()
    }
    
    func clearAllData() {
        codeSnippets.removeAll()
        currentSnippet = nil
        persistenceService.clearAllData()
    }
}

