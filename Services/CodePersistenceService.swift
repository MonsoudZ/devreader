import Foundation

protocol CodePersistenceProtocol: Sendable {
    func saveCodeSnippets(_ snippets: [CodeSnippet]) throws
    func loadCodeSnippets() -> [CodeSnippet]
    func clearAllData()
}

final class CodePersistenceService: CodePersistenceProtocol, @unchecked Sendable {
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
