import SwiftUI

/// 미완성 탭용 "준비 중" 안내.
/// SwiftUI `ContentUnavailableView`는 시스템 폰트로 렌더돼 브랜드 폰트(Noto Sans)와 어긋나므로 대체한다.
struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))   // SF Symbol 글리프 — 시스템 크기 지정이 맞다
                .foregroundStyle(.iconGray)
                .padding(.bottom, 4)
            Text(title)
                .font(.notoSans(20, .bold))
                .foregroundStyle(.textPrimary)
            Text(message)
                .font(.notoSans(15))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ComingSoonView(title: "계획", systemImage: "safari", message: "여행 코스 만들기가 준비 중이에요")
}
