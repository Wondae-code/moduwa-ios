import SwiftUI

/// 홈 상단의 맞춤 접근성 추천 카드
struct HeroCard: View {
    let recommendation: HeroRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ISAWheelchairIcon(size: 14)
                Text("맞춤 접근성 추천")
                    .font(.pretendard(13, .semiBold))
            }
            .foregroundStyle(.deepGreen)

            Text("\(recommendation.userName) 님,\n\(recommendation.headline)")
                .font(.heroTitle)
                .foregroundStyle(.textPrimary)
                .lineSpacing(5)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                ForEach(recommendation.tags, id: \.self) { TagChip(text: $0) }
            }

            Text(recommendation.caption)
                .font(.meta13)
                .foregroundStyle(.textSecondary)

            Button {
                // TODO: 코스 추천 화면 연결
            } label: {
                HStack(spacing: 6) {
                    Text("추천 여행 코스 보러가기")
                        .font(.pretendard(16, .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: 0xC3EE33), .lime],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.sheet))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

#Preview {
    HeroCard(recommendation: MockData.heroRecommendation)
        .padding()
        .background(Color.lime.opacity(0.4))
}
