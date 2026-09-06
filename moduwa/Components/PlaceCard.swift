import SwiftUI

/// 추천 장소 카드 (2열 그리드용)
struct PlaceCard: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) {
                    // **사진이 있든 없든 흰 원 + 딥그린 아이콘**(2026-09-07 요청 — 카드마다
                    //  뱃지 색이 달라 같은 목록 안에서 두 가지로 보였다). 사진 없는 자리는
                    //  거의 흰 배경이라 원의 테두리는 흐려지지만, 딥그린 글리프가 8.1:1 로
                    //  또렷하고 뱃지에 옅은 그림자가 있어 자리가 뜬다.
                    AccessibilityBadge(feature: place.feature, style: .inverted)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.cardTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image("location_on")
                        .renderingMode(.template)
                    Text(place.region)
                        .font(.caption12)
                }
                .foregroundStyle(.textSecondary)

                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image("star")
                            .renderingMode(.template)
                            .foregroundStyle(.deepGreen)
                        Text(rating, format: .number.precision(.fractionLength(1)))
                            .font(.meta13)
                            .foregroundStyle(.textPrimary)
                    }
                }

                Text(place.accessibilityNote)
                    .font(.caption12)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    /// 이미지가 레이아웃 크기를 결정하지 못하도록 투명 뷰 위에 오버레이한다.
    /// (scaledToFill 이미지의 원본 폭이 그리드 셀을 밀어내 카드 폭이 어긋나는 문제 방지)
    private var photo: some View {
        Color.clear
            .overlay {
                if let imageURL = place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        // 받는 중 — 곧 사진이 들어올 자리다.
                        Color.photoPlaceholder
                    }
                } else {
                    // 세 카드가 같은 규칙을 쓴다(`PlaceCategoryArtwork` 주석).
                    PlaceCategoryArtwork(category: place.category)
                }
            }
    }

    private var accessibilitySummary: String {
        var parts = [place.name, place.region]
        if let rating = place.rating {
            parts.append("평점 \(rating.formatted(.number.precision(.fractionLength(1))))점")
        }
        parts.append(place.feature.label)
        parts.append(place.accessibilityNote)
        return parts.joined(separator: ", ")
    }
}

#Preview {
    HStack(spacing: 14) {
        PlaceCard(place: MockData.recommendedPlaces[0])
        PlaceCard(place: MockData.recommendedPlaces[2])
    }
    .padding()
    .background(Color.photoPlaceholder)
}
