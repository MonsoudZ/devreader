import Foundation

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
        persistenceService.deleteKey(codeSnippetsKey)
    }
}
