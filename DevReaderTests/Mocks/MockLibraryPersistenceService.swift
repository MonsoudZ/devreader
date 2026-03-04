import Foundation
@testable import DevReader

@MainActor
final class MockLibraryPersistenceService: LibraryPersistenceService {
    var shouldFail = false
    var saveCallCount = 0
    var importCallCount = 0
    var removeDuplicatesCallCount = 0
    var lastSavedItems: [LibraryItem] = []

    @discardableResult
    override func saveLibraryItems(_ items: [LibraryItem]) async -> Bool {
        saveCallCount += 1
        lastSavedItems = items
        if shouldFail {
            lastError = NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
            return false
        }
        return true
    }

    override func importPDFs(_ urls: [URL]) async -> [LibraryItem] {
        importCallCount += 1
        if shouldFail { return [] }
        return urls.map { url in
            LibraryItem(
                url: url,
                title: url.lastPathComponent,
                fileSize: 0,
                addedDate: Date(),
                lastOpened: nil
            )
        }
    }

    override func removeDuplicates(from items: [LibraryItem]) async -> [LibraryItem] {
        removeDuplicatesCallCount += 1
        return items
    }
}
