import SwiftUI

/// 여행자 리뷰 카드 — 사진 2장이 카드 상단에 꽉 차게 붙는다 (Figma 리뷰 카드)
struct ReviewCard: View {
    let review: TravelReview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoArea
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

    /// 사진 개수별 콜라주 레이아웃:
    /// 1장=전체, 2장=좌우 분할, 3장=좌 1 + 우 상하 2, 4장 이상=좌 1 + 우상 1 + 우하 2(+N 오버레이)
    @ViewBuilder
    private var photoArea: some View {
        let count = review.imageURLs.count
        HStack(spacing: 1) {
            photoSlot(0)
            switch count {
            case 0, 2:
                // 사진이 없으면 기존처럼 2분할 플레이스홀더를 유지한다
                photoSlot(1)
            case 1:
                EmptyView()
            case 3:
                VStack(spacing: 1) {
                    photoSlot(1)
                    photoSlot(2)
                }
            default:
                VStack(spacing: 1) {
                    photoSlot(1)
                    HStack(spacing: 1) {
                        photoSlot(2)
                        photoSlot(3, overflow: count - 4)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count > 0 ? "리뷰 사진 \(count)장" : "리뷰 사진 없음")
    }

    /// 사진 슬롯 — 이미지가 레이아웃 크기를 결정하지 못하도록 투명 뷰 위에 오버레이한다.
    /// `overflow`가 1 이상이면 "+N" 스크림을 얹어 더 많은 사진이 있음을 표시한다.
    private func photoSlot(_ index: Int, overflow: Int = 0) -> some View {
        Color.clear
            .overlay {
                if index < review.imageURLs.count {
                    AsyncImage(url: review.imageURLs[index]) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        PhotoPlaceholder(label: "여행 사진")
                    }
                } else {
                    PhotoPlaceholder(label: "여행 사진")
                }
            }
            .overlay {
                if overflow > 0 {
                    ZStack {
                        Color.black.opacity(0.4)
                        Text("+\(overflow)")
                            .font(.pretendard(18, .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipped()
    }
}

#Preview {
    ReviewCard(review: MockData.reviews[1])
        .padding()
        .background(Color.photoPlaceholder)
}
