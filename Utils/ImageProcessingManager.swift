import Foundation
import PDFKit
import os.log
import CoreGraphics
import ImageIO

/// Advanced image processing for problematic PDF images
@MainActor
class ImageProcessingManager: ObservableObject {
    static let shared = ImageProcessingManager()
    
    @Published var processingErrors: [String] = []
    @Published var isProcessing = false
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "ImageProcessing")
    private var processedImages: [String: CGImage] = [:]
    
    private init() {}
    
    // MARK: - Image Processing
    
    func processPDFImage(_ image: CGImage, identifier: String) -> CGImage? {
        // Check if we've already processed this image
        if let cached = processedImages[identifier] {
            return cached
        }
        
        // Try to process the image
        if let processed = tryProcessImage(image, identifier: identifier) {
            processedImages[identifier] = processed
            return processed
        }
        
        return image
    }
    
    private func tryProcessImage(_ image: CGImage, identifier: String) -> CGImage? {
        do {
            // Create a new image with better format
            let width = image.width
            let height = image.height
            let bitsPerComponent = 8
            let bytesPerPixel = 4
            let bytesPerRow = width * bytesPerPixel
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                os_log("Failed to create context for image processing", log: logger, type: .error)
                return nil
            }
            
            // Draw the image with better quality
            context.interpolationQuality = .high
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let processedImage = context.makeImage() else {
                os_log("Failed to create processed image", log: logger, type: .error)
                return nil
            }
            
            os_log("Successfully processed image %@", log: logger, type: .debug, identifier)
            return processedImage
            
        } catch {
            os_log("Error processing image %@: %@", log: logger, type: .error, identifier, error.localizedDescription)
            processingErrors.append("Failed to process \(identifier): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - JPEG2000 Handling
    
    func handleJPEG2000Error(_ error: String) {
        os_log("JPEG2000 error handled: %@", log: logger, type: .debug, error)
        
        // These errors are usually harmless, so we just log them
        if !processingErrors.contains(error) {
            processingErrors.append(error)
        }
        
        // Keep only the last 10 errors to prevent memory buildup
        if processingErrors.count > 10 {
            processingErrors.removeFirst(processingErrors.count - 10)
        }
    }
    
    // MARK: - Memory Management
    
    func clearProcessedImages() {
        processedImages.removeAll()
        os_log("Cleared processed images cache", log: logger, type: .debug)
    }
    
    func clearErrors() {
        processingErrors.removeAll()
    }
    
    // MARK: - Statistics
    
    func getProcessingStatistics() -> (processed: Int, errors: Int) {
        return (
            processed: processedImages.count,
            errors: processingErrors.count
        )
    }
}
