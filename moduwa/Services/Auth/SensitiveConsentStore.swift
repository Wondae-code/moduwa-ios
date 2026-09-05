import Foundation

/// 민감정보(무장애 정보) 동의를 **받았다는 사실**을 기억하는 곳.
///
/// 왜 기기에 두는가: 동의 시각을 계정에 기록할 자리가 서버에 아직 없다(요청해 둔 항목이다).
/// 그래서 기기가 기억한다 — 기기를 바꾸면 다시 묻는다. **다시 묻는 것은 안전한 쪽의 실수다**
/// (묻지 않고 보내는 것보다 낫다).
///
/// ⚠️ 로그아웃·탈퇴 때 지운다. 동의는 계정에 준 것이고, 다음 사람의 동의가 아니다.
@MainActor
@Observable
final class SensitiveConsentStore {
    static let shared = SensitiveConsentStore()

    private let key = "sensitiveConsentGrantedAt"

    /// 동의한 시각. nil 이면 아직 받지 않았다.
    private(set) var grantedAt: Date?

    var isGranted: Bool { grantedAt != nil }

    private init() {
        let stored = UserDefaults.standard.double(forKey: key)
        grantedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// 동의를 받았다. `at` 은 화면이 동의를 확인한 시각이다.
    func grant(at date: Date = Date()) {
        grantedAt = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    func clear() {
        grantedAt = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}
