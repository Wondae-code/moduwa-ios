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

    /// 탭바 라벨(홈/플랜/일정/저장)도 브랜드 폰트(Noto Sans)로 — UITabBarItem은 기본이 시스템 폰트라 별도 지정이 필요하다.
    /// 시안은 Bold 12에 미선택 #B3B3B3 / 선택 딥그린이지만 Medium 10으로 간다 —
    /// 기기에서 Bold 12는 iOS 기본 탭바 라벨보다 너무 무겁게 읽힌다.
    /// 배경은 시스템 기본값을 유지하고 라벨 폰트와 색만 덮어쓴다.
    ///
    /// 아래 미선택색 지정은 iOS 26 유리 탭바에서 무시된다 — 시스템이 소재 대비용 색으로 덮어쓴다.
    /// iOS 18 이하와 유리를 끈 경우를 위해 남겨두지만, 현재 기기에서 보이는 회색은 시스템 값이다.
    private static func applyBrandTabBarFont() {
        guard let font = UIFont(name: NotoSans.medium.rawValue, size: 10) else { return }
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = UIColor(Color.iconGray)
            layout.normal.titleTextAttributes = [.font: font, .foregroundColor: UIColor(Color.iconGray)]
            layout.selected.iconColor = UIColor(Color.deepGreen)
            layout.selected.titleTextAttributes = [.font: font, .foregroundColor: UIColor(Color.deepGreen)]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// 홈 헤더 뱃지와 알림 화면이 공유하는 알림 상태
    @State private var notificationStore = NotificationStore()
    /// 장소 상세의 저장 버튼과 저장 탭이 공유하는 상태. 한쪽에서 누른 결과가 다른 쪽에
    /// 곧바로 보여야 해서 화면마다 따로 받지 않는다.
    @State private var savedPlacesStore = SavedPlacesStore(service: APIFeedService())

    var body: some Scene {
        WindowGroup {
            RootView()
                // 라이브 API(moduwa-backend). MODUWA_API_KEY 미설정/네트워크 실패 시 번들 데이터로 자동 폴백.
                .environment(\.feedService, APIFeedService())
                .environment(savedPlacesStore)
                .environment(\.placeSearchService, APISearchService())
                // 플랜은 번들 폴백이 없다 — 내가 만든 데이터라 대체할 원본이 없다.
                .environment(\.planService, APIPlanService())
                // 게시글도 번들 폴백이 없다 — 사용자가 쓴 글이라 대체할 원본이 없다.
                .environment(\.postService, APIPostService())
                .environment(notificationStore)
        }
    }
}
