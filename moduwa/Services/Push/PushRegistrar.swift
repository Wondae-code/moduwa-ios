import OSLog
import Observation
import UIKit
import UserNotifications

/// 푸시 알림의 앱 쪽 상태 한 벌 — 권한, 기기 토큰, 서버 등록.
///
/// **스위치 하나가 두 가지를 뜻한다.** iOS 의 시스템 권한(끄면 앱이 다시 켤 수 없다)과 앱의
/// 선호(설정 화면의 토글)는 별개고, 알림이 실제로 오려면 **둘 다** 켜져 있어야 한다.
/// 그래서 화면이 보는 값은 `isOn`(둘의 AND)이고, 토글이 쓰는 값은 `isAllowed` 다.
///
/// 서버에 사용자 설정 컬럼을 두지 않았다 — 앱이 **토큰을 등록/해제하는 것으로** 스위치를
/// 표현한다(요청서에 그렇게 적었다). 끈 기기에는 보낼 토큰 자체가 없다.
///
/// 싱글턴인 이유: `AppDelegate`(APNs 콜백)와 설정 화면과 세션이 같은 상태를 봐야 한다.
@MainActor
@Observable
final class PushRegistrar {
    static let shared = PushRegistrar()

    /// 설정 화면이 쓰던 키를 그대로 쓴다 — 이미 켜 둔 사람의 값을 잃지 않는다.
    static let preferenceKey = "pushNotificationsAllowed"

    private let service: any DeviceTokenService
    private let center = UNUserNotificationCenter.current()
    /// `print` 이 아니라 `Logger` 다 — 푸시가 안 오는 일은 대개 **기기에 설치한 빌드**에서
    /// 벌어지는데(권한·프로파일·환경), 거기서는 print 를 볼 방법이 없다. Console.app 과
    /// `log stream` 으로 볼 수 있어야 진단이 가능하다.
    static let log = Logger(subsystem: "com.waasegye.moduwa", category: "push")

    /// 시스템 권한. 앱이 바꿀 수 없고 물어보기만 한다.
    private(set) var systemStatus: UNAuthorizationStatus = .notDetermined
    /// APNs 가 준 기기 토큰(hex). 권한이 있어야 온다.
    private(set) var token: String?
    /// 사용자가 iOS 설정에서 알림을 껐다 — 앱에서는 되돌릴 수 없어 그리로 보내야 한다.
    var needsSystemSettings = false

    /// 마지막으로 서버에 알린 (기기 토큰, 세션 토큰) 짝.
    ///
    /// 앱을 한 번 켜면 등록 요청이 두 곳에서 온다 — APNs 콜백(`adopt`)과 세션 복구
    /// (`registerAfterSignIn`). 둘 다 필요한 호출이라 어느 쪽도 뺄 수 없어서, **같은 짝이면
    /// 보내지 않는다.** 세션 토큰까지 함께 보는 이유: 계정이 바뀌면 서버가 소유자를 갱신해야
    /// 하므로 그때는 반드시 다시 보내야 한다(같은 기기, 다른 사람).
    private var lastSent: (device: String, session: String)?

    /// 앱 쪽 선호(설정 화면 토글). 기본값은 켜짐 — 권한을 받은 사람에게 다시 묻지 않는다.
    var isAllowed: Bool {
        didSet {
            guard isAllowed != oldValue else { return }
            UserDefaults.standard.set(isAllowed, forKey: Self.preferenceKey)
        }
    }

    /// 실제로 알림이 오는 상태인지. 화면의 토글이 보는 값이다.
    var isOn: Bool {
        isAllowed && (systemStatus == .authorized || systemStatus == .provisional)
    }

    init(service: any DeviceTokenService = APIDeviceTokenService()) {
        self.service = service
        let defaults = UserDefaults.standard
        // 키가 없으면 켜짐이다(설정 화면의 `@AppStorage` 기본값과 같다).
        isAllowed = defaults.object(forKey: Self.preferenceKey) as? Bool ?? true
    }

    // MARK: - 상태

    /// 시스템 권한을 다시 읽는다. 앱 실행·포그라운드 복귀에서 부른다 —
    /// 사용자가 iOS 설정에서 껐다 켰을 수 있고, 그건 앱에 통보되지 않는다.
    func refresh() async {
        systemStatus = await center.notificationSettings().authorizationStatus
        if systemStatus == .authorized || systemStatus == .provisional {
            needsSystemSettings = false
            if isAllowed { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    // MARK: - 스위치

    /// 토글을 켰다. 권한이 없으면 여기서 묻는다 — **켜는 순간이 물어볼 유일하게 자연스러운
    /// 자리다**(앱을 처음 열 때 묻는 것은 무엇에 쓰는 권한인지 모른 채 거절하게 만든다).
    func turnOn() async {
        switch systemStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            systemStatus = await center.notificationSettings().authorizationStatus
            guard granted else {
                // 거절은 앱이 되돌릴 수 없다. 토글을 켜 둔 채로 두면 "켰는데 안 온다"가 된다.
                isAllowed = false
                needsSystemSettings = true
                return
            }
            isAllowed = true
            UIApplication.shared.registerForRemoteNotifications()
        case .denied:
            // 한 번 거절하면 `requestAuthorization` 은 창을 띄우지 않고 곧바로 false 다.
            isAllowed = false
            needsSystemSettings = true
        default:
            isAllowed = true
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 토글을 껐다. 서버에서 토큰을 지운다 — 보낼 곳이 없으면 알림도 없다.
    func turnOff() async {
        isAllowed = false
        await deleteTokenOnServer()
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    // MARK: - APNs 콜백

    /// `AppDelegate` 가 기기 토큰을 받았다.
    ///
    /// 토큰이 그대로여도 **다시 등록한다** — 서버가 upsert 로 `author_id` 를 갱신하는데,
    /// 계정이 바뀌었는지는 앱이 확실히 알 수 없다(같은 기기, 다른 사람).
    func adopt(token: String) {
        self.token = token
        Task { await sendTokenToServer(token) }
    }

    // MARK: - 세션

    /// **로그인할 때마다** 부른다(서버 요청). 같은 기기를 다른 계정으로 쓰면 소유자가 바뀌어야 한다.
    func registerAfterSignIn() {
        guard isAllowed else { return }
        if let token {
            Task { await sendTokenToServer(token) }
        } else {
            // 아직 토큰이 없다 — 권한이 있으면 APNs 가 곧 준다(그때 `adopt` 로 온다).
            Task { await refresh() }
        }
    }

    /// 로그아웃 **직전**에 부른다. 세션 토큰이 지워진 뒤에는 401 이라 지울 수 없고,
    /// 남겨 두면 로그아웃한 사람의 기기로 알림이 계속 간다.
    func unregisterBeforeSignOut() async {
        await deleteTokenOnServer()
    }

    // MARK: - 서버

    private func sendTokenToServer(_ token: String) async {
        // 비로그인 기기는 보낼 곳이 없다 — 서버가 알림을 계정에 붙인다(401 이 온다).
        guard isAllowed, let session = SessionTokenStore.shared.token else { return }
        guard lastSent?.device != token || lastSent?.session != session else { return }
        // ⚠️ **보내기 전에** 표시한다. 앱을 켤 때 두 곳(APNs 콜백·세션 복구)에서 거의 동시에
        //  오는데, 응답을 받은 뒤에 표시하면 둘 다 "아직 안 보냄"을 보고 두 번 보낸다(실측).
        lastSent = (device: token, session: session)
        do {
            try await service.register(token: token, environment: PushEnvironment.current)
            // 푸시는 실패해도 화면이 조용하다 — 로그가 유일한 단서라 성공도 남긴다.
            //  토큰은 앞 12자만 남긴다(전체는 그 기기로 알림을 보낼 수 있는 값이다).
            Self.log.notice("기기 토큰 등록: \(PushEnvironment.current.rawValue, privacy: .public) \(token.prefix(12), privacy: .public)…")
        } catch {
            // 사용자에게는 조용히 넘긴다 — 다음 실행·다음 로그인에 다시 시도되고,
            //  사용자가 할 수 있는 일이 없다. 로그에는 남긴다.
            //  실패했으면 표시를 되돌린다 — 다음 기회에 다시 보내야 한다.
            lastSent = nil
            Self.log.error("기기 토큰 등록 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteTokenOnServer() async {
        guard let token, SessionTokenStore.shared.token != nil else { return }
        do {
            try await service.unregister(token: token)
            // 지웠으니 다음 등록은 다시 보내야 한다.
            lastSent = nil
            Self.log.notice("기기 토큰 해제: \(token.prefix(12), privacy: .public)…")
        } catch {
            Self.log.error("기기 토큰 해제 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
