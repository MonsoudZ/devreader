import Foundation
@preconcurrency import PDFKit
import Combine

@MainActor
final class PDFOutlineManager: ObservableObject {
    @Published var outlineMap: [Int: String] = [:]

    func rebuildOutlineMap(from document: PDFDocument?) {
        outlineMap.removeAll()
        guard let doc = document, let root = doc.outlineRoot else { return }
        var map: [Int: String] = [:]
        func walk(_ node: PDFOutline, path: String) {
            let title = node.label ?? "Untitled"
            let newPath = path.isEmpty ? title : path + " \u{203A} " + title
            if let dest = node.destination, let page = dest.page {
                let idx = doc.index(for: page)
                map[idx] = newPath
            }
            for i in 0..<node.numberOfChildren {
                if let child = node.child(at: i) { walk(child, path: newPath) }
            }
        }
        for i in 0..<root.numberOfChildren {
            if let c = root.child(at: i) { walk(c, path: "") }
        }
        outlineMap = map
    }

    /// Lightweight node extracted from PDFOutline on main thread for safe background processing
    private struct OutlineNode: Sendable {
        let title: String
        let pageIndex: Int?
        let children: [OutlineNode]
    }

    func rebuildOutlineMapAsync(from document: PDFDocument?, isLargePDF: Bool) async {
        guard let doc = document, let root = doc.outlineRoot else { return }
        let maxDepth = isLargePDF ? 3 : Int.max

        // Step 1: Extract outline data on main thread (PDFKit is not thread-safe)
        func extract(_ node: PDFOutline, depth: Int) -> OutlineNode {
            let title = node.label ?? "Untitled"
            let pageIndex: Int? = node.destination?.page.map { doc.index(for: $0) }
            var children: [OutlineNode] = []
            if depth < maxDepth {
                for i in 0..<node.numberOfChildren {
                    if let child = node.child(at: i) {
                        children.append(extract(child, depth: depth + 1))
                    }
                }
            }
            return OutlineNode(title: title, pageIndex: pageIndex, children: children)
        }
        var rootNodes: [OutlineNode] = []
        for i in 0..<root.numberOfChildren {
            if let child = root.child(at: i) {
                rootNodes.append(extract(child, depth: 0))
            }
        }

        // Step 2: Build path strings off main thread (pure computation, no PDFKit)
        let map: [Int: String] = await Task.detached(priority: .userInitiated) {
            var result: [Int: String] = [:]
            func walk(_ node: OutlineNode, path: String) {
                let newPath = path.isEmpty ? node.title : path + " \u{203A} " + node.title
                if let idx = node.pageIndex {
                    result[idx] = newPath
                }
                for child in node.children {
                    walk(child, path: newPath)
                }
            }
            for node in rootNodes {
                walk(node, path: "")
            }
            return result
        }.value

        outlineMap = map
    }

    func clear() {
        outlineMap.removeAll()
    }
}
