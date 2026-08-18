import SwiftUI

/// 저장 탭의 2열 그리드 카드 — 시안 "04. 저장 - 모아보기"(642:837).
///
/// 사진(좌상단 접근성 원형 뱃지) → 이름 → 위치 → 평점 → 접근성 한 줄.
/// 홈 피드의 `PlaceCard` 와 비슷하지만 담는 정보가 다르다 — 여기는 **평점과 접근성 문장**이
/// 함께 들어가고, 사진 위 뱃지도 원형이다.
struct SavedPlaceCard: View {
    let place: Place

    private static let imageHeight: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.notoSans(15, .bold, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                label(icon: "location_on", text: place.region)

                // 평점은 후기에서 집계한 값이라 후기가 없으면 없다 — 그 줄만 빠진다.
                if let rating = place.rating {
                    label(icon: "star", text: rating.formatted(.number.precision(.fractionLength(1))))
                }

                // 접근성 문장을 못 고른 장소도 저장될 수 있다 — 그때는 줄을 그리지 않는다.
                if !place.accessibilityNote.isEmpty {
                    Text(place.accessibilityNote)
                        .font(.notoSans(12, .regular, relativeTo: .caption))
                        .tracking(-0.4)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card).stroke(Color.cardStroke, lineWidth: 1)
        }
        .shadow(color: Color.deepGreen.opacity(0.05), radius: 10, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var photo: some View {
        Color.photoPlaceholder
            .frame(height: Self.imageHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                if let imageURL = place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                } else {
                    // 사진 없는 장소가 5곳 중 1곳이다 — 회색 상자 대신 카테고리를 알린다
                    // (`PlaceCard.categoryArtwork` 와 같은 규칙).
                    Image(place.category.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Color.deepGreen.opacity(0.5))
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                AccessibilityBadge(feature: place.feature, style: .inverted)
                    .padding(8)
            }
            .accessibilityHidden(true)
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(Color.textSecondary)
            Text(text)
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }

    private var accessibilitySummary: String {
        var parts = [place.name, place.region]
        if let rating = place.rating {
            parts.append("평점 \(rating.formatted(.number.precision(.fractionLength(1))))점")
        }
        parts.append(place.feature.label)
        if !place.accessibilityNote.isEmpty { parts.append(place.accessibilityNote) }
        return parts.joined(separator: ", ")
    }
}

#Preview("저장 카드") {
    HStack(alignment: .top, spacing: 14) {
        SavedPlaceCard(place: MockData.recommendedPlaces[0])
        SavedPlaceCard(place: MockData.recommendedPlaces[1])
    }
    .padding(24)
    .background(Color.photoPlaceholder)
}
