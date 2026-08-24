import Foundation

/// 로그인 세션 토큰 보관소. **앱 전체가 이 하나를 본다.**
///
/// 싱글턴인 이유: 토큰은 요청을 조립하는 모든 서비스(`APIFeedService`·`APIPlanService`·
/// `APIPostService`)가 **요청을 만드는 순간** 읽어야 하는 값인데, 그 서비스들은 앱 시작 때 한 번
/// 만들어지는 `Sendable` 구조체다. 값으로 넘겨 주면 로그인·로그아웃으로 토큰이 바뀌어도 그때
/// 붙잡은 옛 값을 계속 쓴다. 살아 있는 출처가 하나 있어야 한다
/// (`ReviewAuthorStore.deviceId` 를 static 으로 둔 것과 같은 판단이다).
///
/// 저장은 **키체인**이다. `UserDefaults` 는 앱 컨테이너의 plist 라 백업에 그대로 실린다 —
/// 이 값은 그것만으로 그 사람이 되는 자격증명이므로 거기 둘 수 없다.
final class SessionTokenStore: @unchecked Sendable {
    static let shared = SessionTokenStore()

    /// 서버가 `session_expired` 를 준 순간 방송한다. `SessionStore` 가 받아 화면을 로그아웃 상태로
    /// 되돌린다 — 토큰을 읽는 곳(nonisolated 구조체)과 화면 상태를 쥔 곳(MainActor)이 서로를
    /// 몰라도 되게 하려고 알림으로 잇는다.
    static let didExpireNotification = Notification.Name("moduwa.session.didExpire")

    private let service = "com.waasegye.moduwa.session"
    private let account = "sessionToken"

    private let lock = NSLock()
    /// 키체인 왕복을 요청마다 하지 않기 위한 캐시.
    /// 이중 옵셔널이다 — `nil`(아직 안 읽음)과 `.some(nil)`(읽었고 없음)을 구분해야
    /// 로그아웃 상태에서 매 요청 키체인을 다시 뒤지지 않는다.
    private var cached: String??

    private init() {}

    /// 지금 유효하다고 믿는 토큰. 없으면 비로그인이다.
    var token: String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let read = readKeychain()
        cached = .some(read)
        return read
    }

    var hasToken: Bool { token != nil }

    /// 로그인·가입 성공 시 저장한다. 토큰 원문은 **그 응답에서 한 번만** 나오므로
    /// 여기서 놓치면 다시 받을 방법이 없다.
    func save(_ token: String) {
        lock.lock()
        defer { lock.unlock() }
        cached = .some(token)
        writeKeychain(token)
    }

    /// 로그아웃. 서버 폐기 요청이 실패해도 기기에서는 지운다 —
    /// 남겨 두면 사용자는 로그아웃했는데 앱은 로그인 상태로 요청을 계속 보낸다.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cached = .some(nil)
        deleteKeychain()
    }

    /// 서버가 만료·폐기를 알려 왔다. 지우고 화면에 알린다.
    ///
    /// ⚠️ 여기서 **폴백하지 않는다.** 만료된 세션을 조용히 익명으로 떨어뜨리면 사용자에게는
    /// "내 플랜이 전부 사라졌다"로 보인다(서버 `middleware.ts` 의 같은 판단).
    func markExpired() {
        guard hasToken else { return } // 이미 없으면 알릴 것도 없다
        clear()
        NotificationCenter.default.post(name: Self.didExpireNotification, object: nil)
    }

    // MARK: - 키체인

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func readKeychain() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8), !token.isEmpty
        else { return nil }
        return token
    }

    private func writeKeychain(_ token: String) {
        let data = Data(token.utf8)
        // 있으면 갱신, 없으면 추가. add 만으로는 두 번째 로그인이 errSecDuplicateItem 으로 조용히 실패한다.
        let updated = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        guard updated != errSecSuccess else { return }

        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        // ⚠️ ThisDeviceOnly — 세션은 서버에서 **이 기기에 묶인다**(author_sessions.device_id).
        //    백업·다른 기기로 따라가면 안 되고, 따라가도 그 기기에서 유효하다고 볼 근거가 없다.
        //    AfterFirstUnlock 인 이유: 잠긴 화면에서 깨어나 갱신하는 요청도 읽을 수 있어야 한다.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func deleteKeychain() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
