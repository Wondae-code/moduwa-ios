import SwiftUI

/// 홈 상단의 맞춤 접근성 추천 카드
struct HeroCard: View {
    let recommendation: HeroRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 5) {
                Image("access_wheelchair")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                Text("맞춤 접근성 추천")
                    .font(.pretendard(15, .bold))
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

            Button {
                // TODO: 코스 추천 화면 연결
            } label: {
                HStack(spacing: 4) {
                    Text("추천 여행 코스 보러가기")
                        .font(.pretendard(16, .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(Color.moduwaGreen))
                .shadow(color: Color(hex: 0x9ACA10).opacity(0.3), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.sheet))
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
    }
}

#Preview {
    HeroCard(recommendation: MockData.heroRecommendation)
        .padding()
        .background(Color.gradientLime.opacity(0.6))
}
