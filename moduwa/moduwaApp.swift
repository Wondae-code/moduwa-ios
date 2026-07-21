import KakaoMapsSDK
import SwiftUI

@main
struct moduwaApp: App {
    init() {
        // 카카오맵 SDK — 키가 있을 때만 초기화 (미설정 시 지도 섹션은 플레이스홀더 표시)
        if let key = Secrets.kakaoNativeAppKey {
            SDKInitializer.InitSDK(appKey: key)
        }
    }

    /// 홈 헤더 뱃지와 알림 화면이 공유하는 알림 상태
    @State private var notificationStore = NotificationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                // 라이브 API(moduwa-backend). MODUWA_API_KEY 미설정/네트워크 실패 시 번들 데이터로 자동 폴백.
                .environment(\.feedService, APIFeedService())
                .environment(\.placeSearchService, APISearchService())
                .environment(notificationStore)
        }
    }
}
