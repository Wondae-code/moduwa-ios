import SwiftUI

struct CollectionView: View {
    var body: some View {
        ContentUnavailableView(
            "저장",
            systemImage: "bookmark",
            description: Text("여행 컬렉션이 준비 중이에요")
        )
    }
}

#Preview {
    CollectionView()
}
