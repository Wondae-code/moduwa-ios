import KakaoMapsSDK
import SwiftUI

@main
struct moduwaApp: App {
    init() {
        Self.applyBrandTabBarFont()

        // 카카오맵 SDK — 키가 있을 때만 초기화 (미설정 시 지도 섹션은 플레이스홀더 표시)
        if let key = Secrets.kakaoNativeAppKey {
            SDKInitializer.InitSDK(appKey: key)
        }
    }

    /// 탭바 라벨(피드/계획/일정/저장)도 브랜드 폰트(Noto Sans)로 — UITabBarItem은 기본이 시스템 폰트라 별도 지정이 필요하다.
    /// 배경은 시스템 기본값을 유지하고 라벨 폰트만 덮어쓴다.
    private static func applyBrandTabBarFont() {
        guard let font = UIFont(name: NotoSans.medium.rawValue, size: 10) else { return }
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.normal.titleTextAttributes = [.font: font]
            layout.selected.titleTextAttributes = [.font: font]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
