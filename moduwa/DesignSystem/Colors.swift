import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// 모두와 브랜드 팔레트 — Figma "Brand Design Guide > Color System" 기준
extension Color {
    static let deepGreen = Color(hex: 0x075B39)
    static let brandGreen = Color(hex: 0x329A42)
    static let tealGreen = Color(hex: 0x1E9E6B)
    static let lime = Color(hex: 0xA9E302)
    static let appBackground = Color(hex: 0xFAFAFA)

    // 아래는 스크린샷 기반 근사값 — 피그마 변수 확정되면 교체
    static let textPrimary = Color(hex: 0x1A1C1A)
    static let textSecondary = Color(hex: 0x6E736E)
    static let cardStroke = Color(hex: 0xE9EAE6)
    static let photoPlaceholder = Color(hex: 0xF1F2EE)
}

// .foregroundStyle(.deepGreen) 같은 축약 문법을 쓰기 위한 포워딩
extension ShapeStyle where Self == Color {
    static var deepGreen: Color { .deepGreen }
    static var brandGreen: Color { .brandGreen }
    static var tealGreen: Color { .tealGreen }
    static var lime: Color { .lime }
    static var appBackground: Color { .appBackground }
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var cardStroke: Color { .cardStroke }
    static var photoPlaceholder: Color { .photoPlaceholder }
}
