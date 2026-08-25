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

// 모두와 브랜드 팔레트 — Figma "Brand Design Guide > Color System" (2026-07-18 확정판) 기준
extension Color {
    /// Moduwa Dark Green — 주요 버튼색
    static let deepGreen = Color(hex: 0x075B39)
    /// Moduwa Green — 주요 CTA 버튼색
    static let moduwaGreen = Color(hex: 0xA7E100)
    /// 메인화면 배경 그라디언트 시작색 (아래로 흰색 페이드)
    static let gradientLime = Color(hex: 0xCAF354)
    /// 메인 배경색
    static let appBackground = Color(hex: 0xFFFFFF)

    /// Moduwa Dark Green 2 — 주요 글자색
    static let textPrimary = Color(hex: 0x0B2A1C)
    /// Gray 70% — 보조 텍스트
    static let textSecondary = Color(hex: 0x4D4D4D)
    /// Gray 30% — 비활성 아이콘
    static let iconGray = Color(hex: 0xB3B3B3)
    /// Gray 10% — 카드 보더
    static let cardStroke = Color(hex: 0xE6E6E6)
    /// Gray 5% — 사진 플레이스홀더 배경
    static let photoPlaceholder = Color(hex: 0xF2F2F2)

    /// 입력 오류 — 온보딩·로그인 시안(2026-08-24)에서 처음 등장한 색.
    ///
    /// 이 앱의 강조색은 초록이라 오류에도 딥그린을 쓰고 있었는데, 새 시안은 **틀린 입력 칸의
    /// 보더와 그 아래 한 줄을 빨강으로** 그린다 — 초록으로는 "이 칸이 틀렸다"를 전할 수 없다.
    static let errorRed = Color(hex: 0xBF1414)
}

// .foregroundStyle(.deepGreen) 같은 축약 문법을 쓰기 위한 포워딩
extension ShapeStyle where Self == Color {
    static var deepGreen: Color { .deepGreen }
    static var moduwaGreen: Color { .moduwaGreen }
    static var gradientLime: Color { .gradientLime }
    static var appBackground: Color { .appBackground }
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var iconGray: Color { .iconGray }
    static var cardStroke: Color { .cardStroke }
    static var photoPlaceholder: Color { .photoPlaceholder }
    static var errorRed: Color { .errorRed }
}
