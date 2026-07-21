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

    var body: some Scene {
        WindowGroup {
            RootView()
                // 라이브 API(moduwa-backend). MODUWA_API_KEY 미설정/네트워크 실패 시 번들 데이터로 자동 폴백.
                .environment(\.feedService, APIFeedService())
        }
    }
}
