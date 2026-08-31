import UIKit
import UserNotifications

/// APNs 는 SwiftUI 로 올라오지 않는다 — 기기 토큰과 알림 탭은 `UIApplicationDelegate` 와
/// `UNUserNotificationCenterDelegate` 콜백으로만 온다. 그 두 통로를 앱 상태에 잇는 자리다.
///
/// 여기에는 판단을 두지 않는다. 토큰은 `PushRegistrar` 가, 갈 곳은 `PushRouter` 가 안다.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // 권한이 이미 있으면 APNs 등록을 다시 걸어 둔다 — 토큰은 재설치·기기 복원에 바뀌고,
        //  바뀐 사실은 이 등록의 콜백으로만 알 수 있다.
        Task { await PushRegistrar.shared.refresh() }
        return true
    }

    // MARK: - 기기 토큰

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // 서버는 hex 문자열을 받는다(정규식으로 막아 두었다).
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushRegistrar.log.notice("APNs 토큰 수신 (\(hex.count, privacy: .public)자)")
        Task { @MainActor in PushRegistrar.shared.adopt(token: hex) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // 사용자가 할 수 있는 일이 없어 화면에 띄우지 않는다. 흔한 원인은 두 가지다:
        //  ① App ID 에 Push Notifications 권한이 없다(프로파일에 aps-environment 가 없다)
        //  ② 시뮬레이터·비행기 모드
        PushRegistrar.log.error("APNs 등록 실패: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - 알림 표시 · 탭

    /// 앱을 보고 있는 동안 온 알림도 배너로 보여 준다. 기본값은 "보여 주지 않음" 인데,
    /// 그러면 내 글에 달린 댓글이 다른 탭을 보고 있는 사이에 조용히 사라진다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// 알림을 눌렀다. 갈 곳만 담고 끝낸다 — 화면을 미는 일은 탭이 한다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { PushRouter.shared.route(userInfo) }
    }
}
