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

    /// 첫 실행 온보딩. 한 번 마치면(건너뛰어도) 다시 띄우지 않는다.
    @State private var isOnboardingPresented = !OnboardingProfileStore.shared.didFinish

    /// 마이페이지 서랍. **여기서 그린다** — 서랍은 탭바까지 덮으므로(시안 821:103) 탭 안쪽에서
    /// 띄울 수 없고, 시트로 띄우면 아래에서 올라온다. 여는 버튼은 네 탭 헤더의
    /// `AccountMenuButton` 이고, 그 사이는 환경값 하나로 잇는다.
    @State private var accountDrawer = AccountDrawerPresenter()

    var body: some View {
        // `@Environment` 는 바인딩을 내주지 않는다. 시트의 `item:` 이 쓸 수 있게 감싼다.
        @Bindable var session = session

        // 앱 전체 글자 크기(마이페이지 → 접근성). body 에서 읽어야 값이 바뀔 때 다시 그린다.
        //  ZStack 에 걸면 탭·서랍은 물론 여기서 띄우는 시트·전체화면까지 환경으로 물려받는다.
        let textScale = AccessibilitySettings.shared.textScale

        return ZStack {
            tabs
                // 서랍이 열려 있으면 뒤쪽은 VoiceOver 에서 숨긴다 — 시트는 시스템이 알아서
                //  해 주지만 오버레이는 계층에 그대로 남아 손가락이 뒤 화면을 계속 짚는다.
                .accessibilityHidden(accountDrawer.isPresented)

            // 서랍은 **늘 계층에 둔다** — 조건부로 넣고 빼면 오프셋 애니메이션이 걸릴
            //  순간이 없다. 닫혀 있으면 화면 밖에 있고 손가락도 VoiceOver 도 받지 않는다.
            AccountDrawerView()
                .allowsHitTesting(accountDrawer.isPresented)
                .accessibilityHidden(!accountDrawer.isPresented)
        }
        .environment(\.accountDrawer, accountDrawer)
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
