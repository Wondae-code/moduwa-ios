import SwiftUI

struct RootView: View {
    private enum Tab: Hashable {
        case home, plan, schedule, saved
    }

    /// 피그마 시안이 탭바를 "Navigation Bar"(아웃라인)와 "Navigation Bar - 선택시"(채움) 두 상태로 나눠 정의한다.
    /// tabItem에 이미지를 하나만 넘기면 모양을 바꿀 수 없어서 선택 상태를 직접 들고 아이콘을 갈아끼운다.
    @State private var selection: Tab = .home

    @Environment(SessionStore.self) private var session
    @Environment(SavedPlacesStore.self) private var savedPlacesStore
    /// 초대 링크가 도착하면 코드를 여기 담고 플랜 탭으로 보낸다 — 수락은 `PlanView` 가 한다.
    @Environment(\.inviteCoordinator) private var inviteCoordinator
    /// 홈에서 "새 플랜"을 요청하면 플랜 탭으로 옮긴다 — 플로우는 그 탭이 연다.
    @Environment(\.planCreation) private var planCreation

    /// 첫 실행 온보딩. 한 번 마치면(건너뛰어도) 다시 띄우지 않는다.
    @State private var isOnboardingPresented = !OnboardingProfileStore.shared.didFinish

    var body: some View {
        // `@Environment` 는 바인딩을 내주지 않는다. 시트의 `item:` 이 쓸 수 있게 감싼다.
        @Bindable var session = session

        // 앱 전체 글자 크기(마이페이지 → 접근성). body 에서 읽어야 값이 바뀔 때 다시 그린다.
        //  여기 걸면 탭 안 화면은 물론 시트·전체화면까지 환경으로 물려받는다.
        let textScale = AccessibilitySettings.shared.textScale

        // 설정(마이페이지)은 서랍이 아니라 탭 안에서 밀어 올리는 전체 화면이다(시안 977:662) —
        //  네 탭 헤더의 `AccountMenuButton` 이 자기 스택에서 직접 민다. 그래서 여기서 오버레이로
        //  얹을 것이 없다.
        return tabs
        .applyTextScale(textScale)
        .tint(.deepGreen)
        // 저장해 둔 토큰이 아직 쓸 수 있는지 한 번 확인한다. 실패를 로그아웃으로 단정하지
        //  않는다 — 비행기에서 앱을 켰다고 로그아웃시키면 안 된다(`SessionStore.bootstrap`).
        //
        // **온보딩이 끝난 뒤에 확인한다.** 한 뷰가 시트와 전체화면을 동시에 띄울 수는 없어서,
        //  첫 실행에 저장된 토큰이 만료돼 있으면(`bootstrap` → `prompt = .sessionExpired`)
        //  로그인 시트가 먼저 자리를 잡고 **온보딩이 아예 뜨지 않는다**(실측). 온보딩 동안은
        //  계정을 알 필요도 없다 — 고른 값은 기기에 남는다.
        .task(id: isOnboardingPresented) {
            guard !isOnboardingPresented else { return }
            await session.bootstrap()
        }
        // 로그아웃하면 이 기기의 화면을 비운다. 세션이 화면을 직접 알면 의존이 거꾸로 흐르므로
        //  여기서 한 번 꽂아 둔다.
        .onAppear {
            session.onSignedOut = { savedPlacesStore.clear() }
        }
        // 유니버설 링크(https://moduwa.app/i/{코드})로 앱이 열리면 코드를 우편함에 담고 플랜
        //  탭으로 보낸다 — 실제 수락은 `PlanView` 가 로그인 여부까지 보고 처리한다. 유니버설
        //  링크는 커스텀 스킴(onOpenURL)이 아니라 NSUserActivity 로 도착한다.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL, let code = InviteCoordinator.code(from: url) else { return }
            inviteCoordinator.pendingCode = code
            selection = .plan
        }
        // 커스텀 스킴으로 앱이 열리는 두 경우를 한곳에서 가른다:
        //  ① 카카오 로그인 콜백 — SDK 가 처리한다(맞으면 true 를 돌려주고 여기서 끝낸다).
        //  ② 초대 폴백 `moduwa://i/{코드}` — 카톡 인앱 웹뷰의 대체 페이지 "앱에서 열기" 버튼이
        //     이 스킴으로 앱을 연다(유니버설 링크가 웹뷰에서 막힐 때). 유니버설 링크와 같은
        //     우편함으로 흘려보내 플랜 탭에서 수락까지 이어진다.
        // 홈 히어로 CTA가 새 플랜을 요청했다 — 플로우를 쥔 플랜 탭으로 옮긴다.
        //  플로우를 여는 것은 그 탭(`PlanListView`)이 하고, 요청도 거기서 내린다.
        .onChange(of: planCreation.isRequested) { _, requested in
            if requested { selection = .plan }
        }
        .onOpenURL { url in
            if KakaoSignInFlow.handle(url) { return }
            if let code = InviteCoordinator.code(from: url) {
                inviteCoordinator.pendingCode = code
                selection = .plan
            }
        }
        // 쓰기 진입점이 비로그인이면 이 시트가 뜬다(`SessionStore.requireSignIn`).
        //  세션이 만료돼 쫓겨난 경우도 같은 자리로 온다.
        //
        // `item:` 에는 **저장소의 바인딩을 그대로** 넘긴다. 온보딩 중 시트를 막으려고 여기서
        //  `Binding(get:set:)` 을 만들어 끼우고 싶어지지만, 그러면 시트 안 `NavigationStack` 의
        //  경로가 화면 갱신마다 흔들릴 위험을 감수하게 된다 — 막을 일은 위의 `task` 에서
        //  **부팅 확인을 미루는 것**으로 끝난다.
        .sheet(item: $session.prompt) { prompt in
            AuthFlowView(prompt: prompt)
        }
        // 온보딩은 로그인을 요구하지 않는다 — 고른 값은 기기에 있다가 가입할 때 계정으로 간다.
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView { outcome in
                isOnboardingPresented = false
                // 마지막 장에서 "여행계획 짜러가기"를 골랐다(시안 868:777). 온보딩이 물어 놓고
                //  홈에 떨어뜨리면 사용자가 플랜 탭을 다시 찾아야 한다.
                if outcome == .planTrip { selection = .plan }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { tabLabel("홈", icon: "tab_home", tab: .home) }
                .tag(Tab.home)

            PlanView()
                .tabItem { tabLabel("플랜", icon: "tab_plan", tab: .plan) }
                .tag(Tab.plan)

            ScheduleView()
                .tabItem { tabLabel("일정", icon: "tab_schedule", tab: .schedule) }
                .tag(Tab.schedule)

            CollectionView()
                .tabItem { tabLabel("저장", icon: "tab_saved", tab: .saved) }
                .tag(Tab.saved)
        }
    }

    private func tabLabel(_ title: String, icon: String, tab: Tab) -> some View {
        Label(title, image: selection == tab ? "\(icon)_fill" : icon)
    }
}

#Preview {
    RootView()
        .environment(SessionStore(service: MockAuthService()))
        .environment(SavedPlacesStore(service: MockFeedService()))
}
