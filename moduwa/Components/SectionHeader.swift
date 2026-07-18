import SwiftUI

/// 섹션 제목 + 부제목 헤더
struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
            Text(subtitle)
                .font(.pretendard(14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SectionHeader(title: "내 일정에 어울리는 추천 맛집·장소", subtitle: "온보딩 정보를 바탕으로 골라봤어요")
        .padding()
}
