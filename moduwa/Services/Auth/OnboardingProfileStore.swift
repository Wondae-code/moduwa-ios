import SwiftUI

/// 온보딩에서 받은 "나에게 필요한 접근성"을 **가입 전까지 기기에** 들고 있는 곳.
///
/// 왜 서버에 바로 넣지 않는가: 익명 사용이 없어져 로그인하지 않은 사람에게는 서버에 자리가
/// 없다. 가입 전에 아무것도 만들지 않으므로 "가입했더니 내 것이 사라졌다"는 상황도 생기지
/// 않는다 — 가져올 익명 데이터가 애초에 없다(백엔드 `docs/ACCOUNTS.md`).
///
/// 가입 요청에 실려 계정에 저장되면(`accessFeatures`) 그 뒤로는 계정이 정본이다.
@MainActor
@Observable
final class OnboardingProfileStore {
    static let shared = OnboardingProfileStore()

    private let featuresKey = "onboardingAccessFeatures"
    private let finishedKey = "onboardingFinished"

    /// 고른 항목. 순서는 사용자가 고른 순서가 아니라 화면의 표시 순서다(목록이 짧아 문제되지 않는다).
    private(set) var features: [AccessibilityFeature]
    /// 온보딩 화면을 끝까지 봤는지. **빈 `features` 와 다른 뜻이다** —
    /// "아무것도 고르지 않았다"와 "온보딩을 안 했다"를 구분해야 다시 띄울지 알 수 있다.
    private(set) var didFinish: Bool

    private init() {
        let defaults = UserDefaults.standard
        let raw = defaults.stringArray(forKey: featuresKey) ?? []
        features = raw.compactMap(AccessibilityFeature.init(rawValue:))
        didFinish = defaults.bool(forKey: finishedKey)
    }

    /// 가입 요청에 실을 값. 온보딩을 하지 않았으면 `nil` —
    /// 빈 배열을 보내면 서버가 "온보딩을 마쳤고 아무것도 고르지 않았다"로 기록한다.
    var selectionForSignUp: [AccessibilityFeature]? {
        didFinish ? features : nil
    }

    /// 온보딩 완료. 고른 것이 없어도 부른다 — "건너뛰기"도 완료다.
    func finish(_ selection: [AccessibilityFeature]) {
        features = selection
        didFinish = true
        let defaults = UserDefaults.standard
        defaults.set(selection.map(\.rawValue), forKey: featuresKey)
        defaults.set(true, forKey: finishedKey)
    }

    /// 가입 성공 — 이제 계정이 이 값을 갖고 있다.
    ///
    /// `didFinish` 는 남긴다(온보딩을 다시 띄우지 않는다). 고른 항목만 지우는 이유:
    /// 로그아웃 후 **다른 계정으로 가입**할 때 남의 온보딩 값이 따라붙으면 안 된다.
    func markHandedToAccount() {
        features = []
        UserDefaults.standard.removeObject(forKey: featuresKey)
    }
}
