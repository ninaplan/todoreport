import CoreImage
import UIKit

/// SF Symbol → 실루엣 흰 스티커 테두리 PNG (투명 배경).
enum StickerSymbolRenderer {
    private static let ciContext = CIContext(options: nil)
    private static let cache = NSCache<NSString, UIImage>()

    /// - Parameters:
    ///   - systemName: SF Symbol 이름
    ///   - pointSize: 심볼 크기 (pt)
    ///   - borderWidth: 테두리 두께 (pt)
    ///   - renderScale: 렌더 해상도 배율
    static func image(
        systemName: String,
        pointSize: CGFloat = 56,
        borderWidth: CGFloat = 5,
        renderScale: CGFloat = 3
    ) -> UIImage? {
        let cacheKey = "\(systemName)|\(pointSize)|\(borderWidth)|\(renderScale)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .large)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(UIColor(white: 0.12, alpha: 1), renderingMode: .alwaysOriginal)
        else {
            return nil
        }

        let padding = borderWidth * 2 + 14
        let canvasSize = CGSize(
            width: symbol.size.width + padding * 2,
            height: symbol.size.height + padding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false

        let base = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            symbol.draw(at: CGPoint(x: padding, y: padding))
        }

        guard let sticker = applyStickerBorder(to: base, borderWidthPoints: borderWidth) else {
            return base
        }

        cache.setObject(sticker, forKey: cacheKey)
        return sticker
    }

    private static func applyStickerBorder(to image: UIImage, borderWidthPoints: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let borderPixels = borderWidthPoints * image.scale
        let sourceExtent = ciImage.extent
        let renderExtent = sourceExtent.insetBy(dx: -borderPixels - 6, dy: -borderPixels - 6)

        guard let dilateFilter = CIFilter(name: "CIMorphologyMaximum") else { return nil }
        dilateFilter.setValue(ciImage, forKey: kCIInputImageKey)
        dilateFilter.setValue(borderPixels, forKey: kCIInputRadiusKey)

        guard let dilatedCI = dilateFilter.outputImage?.cropped(to: renderExtent),
              let dilatedCG = ciContext.createCGImage(dilatedCI, from: renderExtent),
              let originalCG = image.cgImage
        else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let outputSize = CGSize(width: renderExtent.width / image.scale, height: renderExtent.height / image.scale)

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: outputSize)

            cgContext.saveGState()
            cgContext.clip(to: bounds, mask: dilatedCG)
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(bounds)
            cgContext.restoreGState()

            let drawRect = CGRect(
                x: (sourceExtent.origin.x - renderExtent.origin.x) / image.scale,
                y: (sourceExtent.origin.y - renderExtent.origin.y) / image.scale,
                width: sourceExtent.width / image.scale,
                height: sourceExtent.height / image.scale
            )
            cgContext.draw(originalCG, in: drawRect)
        }
    }
}
