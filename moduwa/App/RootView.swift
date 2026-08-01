import SwiftUI

struct RootView: View {
    private enum Tab: Hashable {
        case home, plan, schedule, saved
    }

    /// 피그마 시안이 탭바를 "Navigation Bar"(아웃라인)와 "Navigation Bar - 선택시"(채움) 두 상태로 나눠 정의한다.
    /// tabItem에 이미지를 하나만 넘기면 모양을 바꿀 수 없어서 선택 상태를 직접 들고 아이콘을 갈아끼운다.
    @State private var selection: Tab = .home

    var body: some View {
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
        .tint(.deepGreen)
    }

    private func tabLabel(_ title: String, icon: String, tab: Tab) -> some View {
        Label(title, image: selection == tab ? "\(icon)_fill" : icon)
    }
}

#Preview {
    RootView()
}
