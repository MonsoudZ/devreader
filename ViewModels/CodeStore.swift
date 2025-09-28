import Foundation
import Combine

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
            print("Failed to save code snippets: \(error)")
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

// MARK: - Code Snippet Model

struct CodeSnippet: Identifiable, Codable {
    let id = UUID()
    var title: String
    var content: String
    var language: String
    let createdDate: Date
    var lastModified: Date
    
    init(title: String, content: String, language: String, createdDate: Date, lastModified: Date) {
        self.title = title
        self.content = content
        self.language = language
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
}

// MARK: - Code Persistence Protocol

protocol CodePersistenceProtocol {
    func saveCodeSnippets(_ snippets: [CodeSnippet]) throws
    func loadCodeSnippets() -> [CodeSnippet]
    func clearAllData()
}

class CodePersistenceService: CodePersistenceProtocol {
    private let persistenceService = EnhancedPersistenceService.shared
    private let codeSnippetsKey = "DevReader.CodeSnippets.v1"
    
    func saveCodeSnippets(_ snippets: [CodeSnippet]) throws {
        try persistenceService.saveCodable(snippets, forKey: codeSnippetsKey)
    }
    
    func loadCodeSnippets() -> [CodeSnippet] {
        return persistenceService.loadCodable([CodeSnippet].self, forKey: codeSnippetsKey) ?? []
    }
    
    func clearAllData() {
        persistenceService.clearAllData()
    }
}
