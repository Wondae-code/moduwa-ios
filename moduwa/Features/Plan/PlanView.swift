import SwiftUI

struct PlanView: View {
    var body: some View {
        ContentUnavailableView(
            "플랜",
            systemImage: "safari",
            description: Text("여행 코스 만들기가 준비 중이에요")
        )
    }
}

#Preview {
    PlanView()
}
