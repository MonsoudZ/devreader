import Foundation
import PDFKit
import Combine

@MainActor
final class PDFOutlineManager: ObservableObject {
    @Published var outlineMap: [Int: String] = [:]

    func rebuildOutlineMap(from document: PDFDocument?) {
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
                for i in 0..<node.numberOfChildren {
                    if let child = node.child(at: i) { walk(child, path: newPath) }
                }
            }
            for i in 0..<root.numberOfChildren {
                if let c = root.child(at: i) { walk(c, path: []) }
            }
        }
    }

    func rebuildOutlineMapAsync(from document: PDFDocument?, isLargePDF: Bool) async {
        guard let doc = document else { return }
        let maxDepth = isLargePDF ? 3 : Int.max

        func walkAsync(_ node: PDFOutline, path: [String], depth: Int) {
            guard depth < maxDepth else { return }
            let title = node.label ?? "Untitled"
            let newPath = path + [title]
            if let dest = node.destination, let page = dest.page {
                let idx = doc.index(for: page)
                outlineMap[idx] = newPath.joined(separator: " › ")
            }
            for i in 0..<node.numberOfChildren {
                if let child = node.child(at: i) {
                    walkAsync(child, path: newPath, depth: depth + 1)
                }
            }
        }

        if let root = doc.outlineRoot {
            for i in 0..<root.numberOfChildren {
                if let child = root.child(at: i) {
                    walkAsync(child, path: [], depth: 0)
                }
            }
        }
    }

    func clear() {
        outlineMap.removeAll()
    }
}
