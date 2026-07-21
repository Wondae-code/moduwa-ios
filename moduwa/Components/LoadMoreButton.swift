import SwiftUI

/// 섹션 하단의 "더보기" 알약 버튼 (맞춤 추천 · 여행자 리뷰 · 설명 펼침/접힘 공용)
struct LoadMoreButton: View {
    let title: String
    /// 펼쳐진 상태(접기)일 때 위 방향 화살표로 뒤집는다.
    var pointsUp: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.pretendard(15, .bold))
                Image(systemName: pointsUp ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.deepGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        LoadMoreButton(title: "맞춤 추천 더보기") {}
        LoadMoreButton(title: "리뷰 더보기") {}
        LoadMoreButton(title: "설명 접기", pointsUp: true) {}
    }
    .padding()
}
