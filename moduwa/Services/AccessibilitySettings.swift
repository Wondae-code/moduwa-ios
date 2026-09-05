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
    private static let speechRateKey = "a11ySpeechRate"

    /// 앱 글자 크기. `RootView` 가 이 값으로 화면 전체의 Dynamic Type 을 정한다.
    var textScale: TextScale {
        didSet { UserDefaults.standard.set(textScale.rawValue, forKey: Self.textScaleKey) }
    }

    /// 고대비. 켜면 `Colors.swift` 의 회색·오류 토큰이 짙은 값으로 바뀐다.
    /// 색 토큰이 이 값을 body 에서 읽으므로, 바뀌면 그 색을 쓰는 화면이 함께 다시 그려진다.
    var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: Self.highContrastKey) }
    }

    /// 읽어주기 속도(`SpeechReader`). 듣는 속도는 사람마다 크게 갈린다 —
    /// 처음 듣는 사람은 느리게, 늘 듣는 사람은 화면 읽는 것보다 빠르게 듣는다.
    var speechRate: SpeechRate {
        didSet { UserDefaults.standard.set(speechRate.rawValue, forKey: Self.speechRateKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        textScale = TextScale(rawValue: defaults.integer(forKey: Self.textScaleKey)) ?? .system
        highContrast = defaults.bool(forKey: Self.highContrastKey)
        // 저장된 적이 없으면 `integer(forKey:)` 가 0 을 준다 — 그 자리에 '보통'이 오도록
        //  rawValue 를 1 부터 시작하지 않고, 없을 때만 기본값으로 돌린다.
        speechRate = SpeechRate(rawValue: defaults.object(forKey: Self.speechRateKey) as? Int ?? -1)
            ?? .normal
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

/// 읽어주기 속도 단계.
///
/// 값은 `AVSpeechUtterance` 의 rate 다(기본값 0.5). 0…1 을 다 열어 두지 않는 이유:
/// 양 끝은 한국어에서 알아들을 수 없는 소리가 된다 — 쓸 수 있는 구간만 네 단계로 나눈다.
enum SpeechRate: Int, CaseIterable, Identifiable {
    case slow = 0, normal, fast, fastest

    var id: Int { rawValue }

    var value: Float {
        switch self {
        case .slow: 0.42
        case .normal: 0.50   // AVSpeechUtteranceDefaultSpeechRate
        case .fast: 0.58
        case .fastest: 0.66
        }
    }

    var label: String {
        switch self {
        case .slow: "느리게"
        case .normal: "보통"
        case .fast: "빠르게"
        case .fastest: "아주 빠르게"
        }
    }
}
