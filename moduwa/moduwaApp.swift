import SwiftUI

@main
struct moduwaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // 라이브 API(moduwa-backend). MODUWA_API_KEY 미설정/네트워크 실패 시 번들 데이터로 자동 폴백.
                .environment(\.feedService, APIFeedService())
        }
    }
}
