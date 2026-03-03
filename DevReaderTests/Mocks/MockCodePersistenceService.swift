import Foundation
@testable import DevReader

final class MockCodePersistenceService: CodePersistenceProtocol, @unchecked Sendable {
    var snippets: [CodeSnippet] = []
    var saveCallCount = 0
    var shouldThrowError = false

    func saveCodeSnippets(_ snippets: [CodeSnippet]) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.snippets = snippets
        saveCallCount += 1
    }

    func loadCodeSnippets() -> [CodeSnippet] {
        return snippets
    }

    func clearAllData() {
        snippets.removeAll()
        saveCallCount = 0
    }
}
