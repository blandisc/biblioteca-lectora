import Foundation
import ImageIO
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Portadas: todo se guarda como `cover.jpg` (lo que espera Calibre) y se lee con caché.
enum CoverImaging {
    /// Cualquier imagen (JPEG, PNG, HEIC…) a JPEG, con el lado mayor limitado.
    static func jpeg(from data: Data, maxPixel: Int = 1600) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return jpeg(from: image)
    }

    static func jpeg(from image: CGImage, quality: Double = 0.88) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    #if os(iOS)
    static func jpeg(from image: UIImage) -> Data? { image.jpegData(compressionQuality: 0.88) }
    #else
    static func jpeg(from image: NSImage) -> Data? {
        image.cgImage(forProposedRect: nil, context: nil, hints: nil).flatMap { jpeg(from: $0) }
    }
    #endif

    private static let cache = NSCache<NSURL, CGImage>()

    /// Imagen lista para mostrar; se reduce a 600 px para no cargar portadas enormes.
    static func image(at url: URL) -> CGImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    static func forget(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
