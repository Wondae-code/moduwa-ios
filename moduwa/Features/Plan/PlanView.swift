import SwiftUI

struct PlanView: View {
    var body: some View {
        ComingSoonView(
            title: "계획",
            systemImage: "safari",
            message: "여행 코스 만들기가 준비 중이에요"
        )
    }
}

#Preview {
    PlanView()
}
