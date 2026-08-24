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

    var body: some View {
        // `@Environment` 는 바인딩을 내주지 않는다. 시트의 `item:` 이 쓸 수 있게 감싼다.
        @Bindable var session = session

        return TabView(selection: $selection) {
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
        .tint(.deepGreen)
        // 저장해 둔 토큰이 아직 쓸 수 있는지 한 번 확인한다. 실패를 로그아웃으로 단정하지
        //  않는다 — 비행기에서 앱을 켰다고 로그아웃시키면 안 된다(`SessionStore.bootstrap`).
        .task { await session.bootstrap() }
        // 로그아웃하면 이 기기의 화면을 비운다. 세션이 화면을 직접 알면 의존이 거꾸로 흐르므로
        //  여기서 한 번 꽂아 둔다.
        .onAppear {
            session.onSignedOut = { savedPlacesStore.clear() }
        }
        // 쓰기 진입점이 비로그인이면 이 시트가 뜬다(`SessionStore.requireSignIn`).
        //  세션이 만료돼 쫓겨난 경우도 같은 자리로 온다.
        .sheet(item: $session.prompt) { prompt in
            AuthFlowView(prompt: prompt)
        }
        // 온보딩은 로그인을 요구하지 않는다 — 고른 값은 기기에 있다가 가입할 때 계정으로 간다.
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView { isOnboardingPresented = false }
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
