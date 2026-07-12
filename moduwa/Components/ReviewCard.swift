import SwiftUI

/// 여행자 리뷰 카드
struct ReviewCard: View {
    let review: TravelReview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                PhotoPlaceholder(label: "여행 사진")
                PhotoPlaceholder(label: "여행 사진")
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(alignment: .topLeading) {
                if review.isAccessibilityVerified {
                    ISAWheelchairIcon(size: 15)
                        .foregroundStyle(.deepGreen)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .padding(10)
                        .accessibilityLabel("접근성 검증 리뷰")
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.deepGreen)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String(review.author.prefix(1)))
                            .font(.pretendard(14, .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.author)
                        .font(.pretendard(14, .semiBold))
                        .foregroundStyle(.textPrimary)
                    Text(review.location)
                        .font(.caption12)
                        .foregroundStyle(.textSecondary)
                }
            }

            Text(review.body)
                .font(.body15)
                .foregroundStyle(.textPrimary)
                .lineSpacing(3)

            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image("favorite")
                        .renderingMode(.template)
                        .foregroundStyle(.lime)
                    Text("\(review.likeCount)")
                }
                HStack(spacing: 5) {
                    Image("chat_bubble")
                        .renderingMode(.template)
                        .foregroundStyle(.lime)
                    Text("\(review.commentCount)")
                }
            }
            .font(.meta13)
            .foregroundStyle(.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("좋아요 \(review.likeCount)개, 댓글 \(review.commentCount)개")
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

#Preview {
    ReviewCard(review: MockData.reviews[1])
        .padding()
        .background(Color.appBackground)
}
