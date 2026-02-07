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
        // 创建一个独立的视图，不依赖环境
        let view = ShareCardView(
            month: month,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            format: format
        )
        .environment(\.colorScheme, .dark) // 强制深色模式

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 // Retina
        renderer.proposedSize = .init(format.size)

        // 确保有有效输出
        guard let image = renderer.uiImage else {
            print("[ShareImageService] Failed to render image")
            return nil
        }

        // 验证图片尺寸有效
        guard image.size.width > 0 && image.size.height > 0 else {
            print("[ShareImageService] Invalid image size: \(image.size)")
            return nil
        }

        return image
    }

    @MainActor
    static func renderYearShareImage(
        year: Int,
        snapshots: [Date: DailySnapshot],
        baseCurrency: String
    ) -> UIImage? {
        let view = YearShareCardView(
            year: year,
            snapshots: snapshots,
            baseCurrency: baseCurrency
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderer.proposedSize = .init(CGSize(width: 480, height: 640))

        guard let image = renderer.uiImage else {
            print("[ShareImageService] Failed to render year image")
            return nil
        }

        guard image.size.width > 0 && image.size.height > 0 else {
            print("[ShareImageService] Invalid year image size: \(image.size)")
            return nil
        }

        return image
    }
    #endif

    enum ShareFormat {
        case square     // 适合朋友圈等正方形场景
        case story      // 适合 Instagram Story 等竖屏场景

        var size: CGSize {
            switch self {
            // 增大视图尺寸以容纳6行日历（某些月份跨越6周）
            case .square: return CGSize(width: 440, height: 660)
            case .story:  return CGSize(width: 440, height: 860)
            }
        }
    }
}
