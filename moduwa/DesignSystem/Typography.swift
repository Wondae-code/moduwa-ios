import SwiftUI

enum Pretendard: String {
    case regular = "Pretendard-Regular"
    case medium = "Pretendard-Medium"
    case semiBold = "Pretendard-SemiBold"
    case bold = "Pretendard-Bold"
}

extension Font {
    /// relativeTo를 지정해 Dynamic Type 스케일링을 유지한다.
    static func pretendard(_ size: CGFloat, _ weight: Pretendard = .regular, relativeTo style: TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    // 시맨틱 스타일 — Figma 메인화면 실측 기준
    static let heroTitle = pretendard(24, .bold, relativeTo: .title2)
    static let sectionTitle = pretendard(20, .bold, relativeTo: .title3)
    static let cardTitle = pretendard(16, .semiBold, relativeTo: .headline)
    static let body15 = pretendard(15, .regular, relativeTo: .body)
    static let chip14 = pretendard(14, .medium, relativeTo: .subheadline)
    static let meta13 = pretendard(13, .regular, relativeTo: .footnote)
    static let caption12 = pretendard(12, .regular, relativeTo: .caption)
}
