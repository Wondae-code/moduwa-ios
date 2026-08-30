import SwiftUI

/// 앱이 스스로 켜는 접근성 설정 — 글자 크기와 고대비.
///
/// 시스템 손쉬운 사용과 **별개로** 앱 안에서 직접 조절한다. 접근성이 주제인 앱이 정작 자기
/// 화면은 못 키운다면 앞뒤가 안 맞으므로, 온보딩에서 고르는 "필요한 무장애"와 나란히
/// 화면 자체의 읽기 편의를 둔다. 값은 로그인과 무관하게 이 기기에 남는다.
///
/// `@MainActor` 를 붙이지 않는다 — 색 토큰(`Color.iconGray` 등)이 이 값을 읽어 고대비를
/// 반영하는데, 그 getter 들은 액터에 묶이지 않은 자리에서도 불린다. 읽고 쓰는 실제 시점은
/// 모두 뷰(메인 액터)라 경합은 없다(`AccountDrawerPresenter` 와 같은 판단).
@Observable
final class AccessibilitySettings {
    static let shared = AccessibilitySettings()

    private static let textScaleKey = "a11yTextScale"
    private static let highContrastKey = "a11yHighContrast"

    /// 앱 글자 크기. `RootView` 가 이 값으로 화면 전체의 Dynamic Type 을 정한다.
    var textScale: TextScale {
        didSet { UserDefaults.standard.set(textScale.rawValue, forKey: Self.textScaleKey) }
    }

    /// 고대비. 켜면 `Colors.swift` 의 회색·오류 토큰이 짙은 값으로 바뀐다.
    /// 색 토큰이 이 값을 body 에서 읽으므로, 바뀌면 그 색을 쓰는 화면이 함께 다시 그려진다.
    var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: Self.highContrastKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        textScale = TextScale(rawValue: defaults.integer(forKey: Self.textScaleKey)) ?? .system
        highContrast = defaults.bool(forKey: Self.highContrastKey)
    }
}

/// 앱이 직접 정하는 글자 크기 단계.
///
/// `.system` 은 시스템 손쉬운 사용 값을 그대로 따른다 — 이미 크게 키워 둔 사람의 설정을
/// 앱이 되돌리지 않기 위해서다. 나머지는 그보다 확실히 큰 세 단계다.
enum TextScale: Int, CaseIterable, Identifiable {
    case system = 0, large, larger, largest

    var id: Int { rawValue }

    /// 적용할 Dynamic Type 크기. `.system` 은 `nil` — 아무것도 덮어쓰지 않고 시스템 값이 흐른다.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: nil
        case .large: .xLarge
        case .larger: .xxLarge
        case .largest: .xxxLarge
        }
    }

    var label: String {
        switch self {
        case .system: "시스템"
        case .large: "크게"
        case .larger: "더 크게"
        case .largest: "아주 크게"
        }
    }
}

extension View {
    /// 글자 크기 단계를 적용한다. `.system` 이면 시스템 값이 흐르도록 아무것도 붙이지 않는다.
    /// (SwiftUI 기본 `textScale(_:)` 과 헷갈리지 않게 이름을 따로 둔다.)
    @ViewBuilder
    func applyTextScale(_ scale: TextScale) -> some View {
        if let size = scale.dynamicTypeSize {
            dynamicTypeSize(size)
        } else {
            self
        }
    }
}
