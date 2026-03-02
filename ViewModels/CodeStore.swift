import Foundation
import Combine
import os.log

/// Manages code snippets and persistence
@MainActor
class CodeStore: ObservableObject {
    @Published var codeSnippets: [CodeSnippet] = []
    @Published var currentSnippet: CodeSnippet?
    
    private let persistenceService: CodePersistenceProtocol
    
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
            saveCodeSnippets()
        }
    }
    
    func deleteSnippet(_ snippet: CodeSnippet) {
        codeSnippets.removeAll { $0.id == snippet.id }
        if currentSnippet?.id == snippet.id {
            currentSnippet = nil
        }
        saveCodeSnippets()
    }
    
    func exportSnippet(_ snippet: CodeSnippet) -> URL? {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(snippet.title).\(snippet.language)")
        
        try? snippet.content.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }
    
    // MARK: - Persistence
    
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

