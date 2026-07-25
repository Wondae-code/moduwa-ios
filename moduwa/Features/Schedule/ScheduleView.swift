import SwiftUI

struct ScheduleView: View {
    var body: some View {
        ComingSoonView(
            title: "일정",
            systemImage: "calendar",
            message: "여행 일정 관리가 준비 중이에요"
        )
    }
}

#Preview {
    ScheduleView()
}
