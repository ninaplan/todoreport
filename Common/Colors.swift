import SwiftUI
import UIKit

extension Color {
    static let nockOrange = Color(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    // MARK: - 대비 헬퍼 (카테고리 색)

    /// 채움 위 글자용 휘도 임계값 — 아주 밝은 색에서만 검정, 그 외 흰색. 실기기에서 미세조정
    private static let lightLuminanceThreshold: Double = 0.78
    /// 라이트모드 색글자 목표 luminance 상한 — 실기기에서 조정
    private static let lightModeMaxLuminance: Double = 0.55
    /// 다크모드 색글자 목표 luminance 하한 — 실기기에서 조정
    private static let darkModeMinLuminance: Double = 0.6

    private var rgbComponents: (r: Double, g: Double, b: Double)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (Double(r), Double(g), Double(b))
    }

    private var perceivedLuminance: Double {
        guard let c = rgbComponents else { return 0.5 }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    var isLight: Bool {
        perceivedLuminance > Self.lightLuminanceThreshold
    }

    /// 단색 채움 위 글자·아이콘용 (검정/흰 자동).
    var readableForeground: Color {
        isLight ? .black : .white
    }

    /// 배경 위 색글자용 — 라이트/다크에 맞게 밝기만 보정해 색상 유지.
    func readableText(on scheme: ColorScheme) -> Color {
        guard let c = rgbComponents else { return self }
        let luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

        switch scheme {
        case .light:
            let maxL = Self.lightModeMaxLuminance
            guard luminance > maxL, luminance > 0 else { return self }
            let scale = maxL / luminance
            return Color(red: c.r * scale, green: c.g * scale, blue: c.b * scale)
        case .dark:
            let minL = Self.darkModeMinLuminance
            guard luminance < minL, luminance < 1 else { return self }
            let blend = (minL - luminance) / (1 - luminance)
            return Color(
                red: c.r + blend * (1 - c.r),
                green: c.g + blend * (1 - c.g),
                blue: c.b + blend * (1 - c.b)
            )
        @unknown default:
            return self
        }
    }
}
