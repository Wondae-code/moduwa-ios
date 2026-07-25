import SwiftUI

struct CollectionView: View {
    var body: some View {
        ComingSoonView(
            title: "저장",
            systemImage: "bookmark",
            message: "여행 컬렉션이 준비 중이에요"
        )
    }
}

#Preview {
    CollectionView()
}
