import SwiftUI

/// 히어로 카드의 해시태그 칩 (#경사로 #휠체어 …)
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.chip14)
            .foregroundStyle(.deepGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                Capsule().stroke(Color.deepGreen.opacity(0.5), lineWidth: 1)
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
