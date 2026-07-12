import SwiftUI

@main
struct moduwaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // moduwa-backend DB에서 조합한 번들 데이터. API 서버가 생기면 APIFeedService로 교체.
                .environment(\.feedService, BundledFeedService())
        }
    }
}
