import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("피드", image: "home") }

            PlanView()
                .tabItem { Label("계획", image: "explore") }

            ScheduleView()
                .tabItem { Label("일정", image: "calendar_month") }

            // 시안이 사람 아이콘 + "저장" 라벨 조합 — 시안 그대로 유지 (불일치는 디자이너 확인 대기)
            CollectionView()
                .tabItem { Label("저장", image: "person") }
        }
        .tint(.deepGreen)
    }
}

#Preview {
    RootView()
}
