import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
#endif

struct ShareImageService {
    #if os(iOS)
    static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    @MainActor
    static func renderShareImage(
        month: Date,
        snapshots: [DailySnapshot],
        baseCurrency: String,
        format: ShareFormat = .square
    ) -> UIImage? {
        let view = ShareCardView(
            month: month,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            format: format
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 // Retina
        return renderer.uiImage
    }
    #endif

    enum ShareFormat {
        case square     // 1080×1080
        case story      // 1080×1920

        var size: CGSize {
            switch self {
            case .square: return CGSize(width: 360, height: 360)
            case .story:  return CGSize(width: 360, height: 640)
            }
        }
    }
}
