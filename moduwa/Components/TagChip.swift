import SwiftUI

/// 히어로 카드의 해시태그 칩 (#경사로 #휠체어 …)
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.pretendard(13, .bold))
            .foregroundStyle(.deepGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                Capsule().stroke(Color.deepGreen, lineWidth: 1)
            )
    }
}

#Preview {
    HStack {
        TagChip(text: "#경사로")
        TagChip(text: "#휠체어")
        TagChip(text: "#효도여행")
    }
    .padding()
}
