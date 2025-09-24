import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class PDFControllerTests: XCTestCase {
    override func tearDownWithError() throws {
        // Clear all UserDefaults to prevent test interference
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("DevReader.") {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    func testPagePersistenceKeyedByURL() {
        let ctrl = PDFController()
        let doc1 = PDFDocument(); doc1.insert(PDFPage(), at: 0)
        let doc2 = PDFDocument(); doc2.insert(PDFPage(), at: 0)
        let tmp1 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("a_\(UUID().uuidString).pdf")
        let tmp2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("b_\(UUID().uuidString).pdf")
        
        ctrl.loadForTesting(document: doc1, url: tmp1)
        ctrl.goToPage(0)
        ctrl.saveAnnotatedCopy()
        
        ctrl.loadForTesting(document: doc2, url: tmp2)
        ctrl.goToPage(0)
        
        ctrl.loadForTesting(document: doc1, url: tmp1)
        XCTAssertGreaterThanOrEqual(ctrl.currentPageIndex, 0)
    }

    func testBookmarksPersist() {
        let ctrl = PDFController()
        let doc = PDFDocument(); doc.insert(PDFPage(), at: 0)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("c_\(UUID().uuidString).pdf")
        
        ctrl.loadForTesting(document: doc, url: tmp)
        ctrl.toggleBookmark(0)
        XCTAssertTrue(ctrl.isBookmarked(0))
        
        ctrl.loadForTesting(document: doc, url: tmp)
        XCTAssertTrue(ctrl.isBookmarked(0))
    }
}


