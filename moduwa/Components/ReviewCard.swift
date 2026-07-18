import SwiftUI

/// 여행자 리뷰 카드 — 사진 2장이 카드 상단에 꽉 차게 붙는다 (Figma 리뷰 카드)
struct ReviewCard: View {
    let review: TravelReview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                PhotoPlaceholder(label: "여행 사진")
                PhotoPlaceholder(label: "여행 사진")
            }
            .frame(height: 180)
            .clipped()
            .overlay(alignment: .topLeading) {
                if review.isAccessibilityVerified {
                    AccessibilityBadge(feature: .wheelchairAccessible, style: .inverted)
                        .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color.deepGreen)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(review.author.prefix(1)))
                                .font(.pretendard(14, .bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(review.author)
                            .font(.pretendard(14, .bold))
                            .foregroundStyle(.textPrimary)
                        Text(review.location)
                            .font(.caption12)
                            .foregroundStyle(.textSecondary)
                    }
                }

                Text(review.body)
                    .font(.pretendard(16))
                    .foregroundStyle(.textSecondary)
                    .lineSpacing(6)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image("favorite")
                            .renderingMode(.template)
                            .foregroundStyle(.moduwaGreen)
                        Text("\(review.likeCount)")
                    }
                    HStack(spacing: 4) {
                        Image("chat_bubble")
                            .renderingMode(.template)
                            .foregroundStyle(.moduwaGreen)
                        Text("\(review.commentCount)")
                    }
                }
                .font(.meta13)
                .foregroundStyle(.textSecondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("좋아요 \(review.likeCount)개, 댓글 \(review.commentCount)개")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
    }
}

#Preview {
    ReviewCard(review: MockData.reviews[1])
        .padding()
        .background(Color.photoPlaceholder)
}
