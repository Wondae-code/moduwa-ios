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

    /// Moduwa Dark Green 2 — 주요 글자색. 흰 배경 15:1 로 이미 충분해 고대비에서도 그대로.
    static let textPrimary = Color(hex: 0x0B2A1C)

    // 아래 다섯은 **고대비를 켜면 짙은 값으로 바뀐다.** 흰 배경에서 회색 계열이 대비비를
    //  못 넘기던 문제(비활성 아이콘 2.1:1, 카드 보더 1.3:1)를 끌어올린다. `static var` 로 둔 건
    //  `AccessibilitySettings.highContrast` 를 body 에서 읽게 하기 위함이다 — 그러면 이 색을
    //  쓰는 화면이 토글과 함께 다시 그려진다(호출부는 `.iconGray` 그대로, 손대지 않는다).

    /// Gray 70% — 보조 텍스트 (고대비 8.5:1 → 12.6:1)
    static var textSecondary: Color {
        AccessibilitySettings.shared.highContrast ? Color(hex: 0x333333) : Color(hex: 0x4D4D4D)
    }
    /// Gray 30% — 비활성 아이콘 (고대비 2.1:1 → 7.0:1)
    static var iconGray: Color {
        AccessibilitySettings.shared.highContrast ? Color(hex: 0x595959) : Color(hex: 0xB3B3B3)
    }
    /// Gray 10% — 카드 보더 (고대비 1.3:1 → 3.4:1)
    static var cardStroke: Color {
        AccessibilitySettings.shared.highContrast ? Color(hex: 0x8C8C8C) : Color(hex: 0xE6E6E6)
    }
    /// Gray 5% — 사진 플레이스홀더 배경 (고대비에서 살짝 짙게 해 자리를 분리)
    static var photoPlaceholder: Color {
        AccessibilitySettings.shared.highContrast ? Color(hex: 0xE4E4E4) : Color(hex: 0xF2F2F2)
    }

    /// 입력 오류 — 온보딩·로그인 시안(2026-08-24)에서 처음 등장한 색.
    ///
    /// 이 앱의 강조색은 초록이라 오류에도 딥그린을 쓰고 있었는데, 새 시안은 **틀린 입력 칸의
    /// 보더와 그 아래 한 줄을 빨강으로** 그린다 — 초록으로는 "이 칸이 틀렸다"를 전할 수 없다.
    /// 고대비에서 더 짙게(6.3:1 → 8.0:1). 색약자는 빨강↔초록을 못 가르니 **늘 아이콘·문구와 함께.**
    static var errorRed: Color {
        AccessibilitySettings.shared.highContrast ? Color(hex: 0xA30D0D) : Color(hex: 0xBF1414)
    }
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
