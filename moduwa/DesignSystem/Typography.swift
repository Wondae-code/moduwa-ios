import SwiftUI

/// 브랜드 가이드 폰트 — Noto Sans KR로 통일 (구 Pretendard/Inter 폐기, 2026-07-25)
enum NotoSans: String {
    case regular = "NotoSansKR-Regular"
    case medium = "NotoSansKR-Medium"
    case semiBold = "NotoSansKR-SemiBold"
    case bold = "NotoSansKR-Bold"
}

extension Font {
    /// relativeTo를 지정해 Dynamic Type 스케일링을 유지한다.
    static func notoSans(_ size: CGFloat, _ weight: NotoSans = .regular, relativeTo style: TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    // 시맨틱 스타일 — Figma Brand Design Guide 타입 스케일
    static let heroTitle = notoSans(24, .bold, relativeTo: .title2)
    static let sectionTitle = notoSans(20, .bold, relativeTo: .title3)
    static let cardTitle = notoSans(16, .bold, relativeTo: .headline)
    static let body15 = notoSans(15, .regular, relativeTo: .body)
    static let chip14 = notoSans(14, .medium, relativeTo: .subheadline)
    static let meta13 = notoSans(13, .regular, relativeTo: .footnote)
    static let caption12 = notoSans(12, .regular, relativeTo: .caption)
}
