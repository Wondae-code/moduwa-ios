import SwiftUI

/// 섹션 하단의 "더보기" 알약 버튼 (맞춤 추천 · 여행자 리뷰 공용)
struct LoadMoreButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.pretendard(15, .bold))
                Image(systemName: "chevron.down")
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
    }
    .padding()
}
