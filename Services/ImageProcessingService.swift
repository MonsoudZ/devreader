import Foundation
import CoreImage
import ImageIO
import PDFKit
import AppKit

// MARK: - Image Processing (robust fallbacks)
enum ImageProcessingService {
    /// Attempts to decode JPEG2000 (JP2) data using CoreImage as a fallback path
    static func decodeJPEG2000(_ data: Data) -> CGImage? {
        let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let ciImage = CIImage(data: data) else { return nil }
        let extent = ciImage.extent.integral
        return ciContext.createCGImage(ciImage, from: extent)
    }

    /// Creates a best-effort CGImage from arbitrary data using ImageIO first, then CoreImage (for JP2)
    static func decodeImageData(_ data: Data, utiHint: CFString? = nil) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        if let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) {
            if let cg = CGImageSourceCreateImageAtIndex(src, 0, options as CFDictionary) {
                return cg
            }
            if let cg = decodeJPEG2000(data) { return cg }
        }
        return nil
    }

    /// Rasterizes a PDF page via CoreGraphics into an NSImage (handles many embedded image quirks)
    static func rasterize(page: PDFPage, into targetSize: CGSize, scale: CGFloat = 2.0) -> NSImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = max(1, Int(targetSize.width * scale))
        let height = max(1, Int(targetSize.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.saveGState()
        let drawRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.translateBy(x: 0, y: drawRect.height)
        context.scaleBy(x: drawRect.width / bounds.width, y: -drawRect.height / bounds.height)
        if let cgPage = page.pageRef {
            context.drawPDFPage(cgPage)
        } else {
            let thumb = page.thumbnail(of: bounds.size, for: .mediaBox)
            if let cg = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cg, in: bounds)
            }
        }
        context.restoreGState()
        guard let cgOut = context.makeImage() else { return nil }
        return NSImage(cgImage: cgOut, size: NSSize(width: targetSize.width, height: targetSize.height))
    }

    /// Safe thumbnail that falls back to rasterization when PDFKit thumbnailing fails
    static func safeThumbnail(for page: PDFPage, size: CGSize) -> NSImage? {
        let thumb = page.thumbnail(of: size, for: .mediaBox)
        if thumb.size.width > 0 && thumb.size.height > 0 { return thumb }
        return rasterize(page: page, into: size)
    }
}
