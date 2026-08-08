import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationStack {
            // 플랜 서비스가 아직 없다 — 목 데이터로 화면부터 맞춘다.
            PlanListView(plans: MockData.plans)
        }
    }
}

#Preview {
    PlanView()
}
