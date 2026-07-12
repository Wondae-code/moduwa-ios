import SwiftUI

/// 실제 이미지가 붙기 전까지 쓰는 사진 자리 표시 (Figma의 "장소 사진" 영역)
struct PhotoPlaceholder: View {
    var label: String = "장소 사진"

    var body: some View {
        ZStack {
            Rectangle().fill(Color.photoPlaceholder)
            Text(label)
                .font(.caption12)
                .foregroundStyle(.textSecondary)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PhotoPlaceholder()
        .frame(width: 160, height: 110)
}
