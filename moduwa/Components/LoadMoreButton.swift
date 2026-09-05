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
                // 시안 249:762 "more" — 16 Bold, 캡슐 높이 42(글줄 ~23 + 위아래 10).
                //  후기·댓글·검색의 더보기 바도 시안에서 같은 값을 쓴다.
                Text(title)
                    .font(.notoSans(16, .bold))
                    .tracking(-0.4)
                Image(systemName: pointsUp ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.deepGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            // 글자가 커져도 시안 높이 아래로는 내려가지 않게(작아지지도 않게) 바닥을 준다.
            .frame(minHeight: 42)
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
