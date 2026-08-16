import SwiftUI

/// 여행자 리뷰 카드 — 사진 2장이 카드 상단에 꽉 차게 붙는다 (Figma 리뷰 카드)
struct ReviewCard: View {
    let review: TravelReview

    var body: some View {
        // ⚠️ 폭을 여기서 못 박는다. 예전에는 사진 칸의 `Color.clear` 가 가로로 늘어나며
        //  카드 폭을 만들어 줬는데, 사진 없는 후기에서 그 칸이 빠지면서 카드가 **글자 길이만큼만**
        //  좁아졌다 — 목록에서 한 장만 폭이 다른 카드가 됐다. 폭은 내용이 아니라 카드가 정해야 한다.
        VStack(alignment: .leading, spacing: 0) {
            // 사진이 한 장도 없으면 사진 칸을 아예 두지 않는다. 예전에는 회색 자리 표시를 두 칸
            //  깔았는데, 없는 사진을 180pt나 차지하며 "여행 사진"이라고 알리는 꼴이었다.
            //  후기 사진은 선택이라 글로만 쓴 후기는 정상적인 경우다 — 결함처럼 보이면 안 된다.
            if !review.imageURLs.isEmpty {
                photoArea
                    .frame(height: 180)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if review.isAccessibilityVerified {
                            AccessibilityBadge(feature: .wheelchairAccessible, style: .inverted)
                                .padding(12)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color.deepGreen)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(review.author.prefix(1)))
                                .font(.notoSans(14, .bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(review.author)
                            .font(.notoSans(14, .bold))
                            .foregroundStyle(.textPrimary)
                        Text(review.location)
                            .font(.caption12)
                            .foregroundStyle(.textSecondary)
                    }
                }

                // 사진이 있을 때 뱃지는 사진 위에 얹힌다. 사진이 없으면 얹을 곳이 사라지므로
                // 본문 위로 옮긴다 — 밝은 배경이라 `.filled` 를 쓴다(`PlaceCard` 와 같은 규칙).
                if review.imageURLs.isEmpty, review.isAccessibilityVerified {
                    AccessibilityBadge(feature: .wheelchairAccessible, style: .filled)
                }

                Text(review.body)
                    .font(.notoSans(16))
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
            case 2:
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
                            .font(.notoSans(18, .bold))
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
