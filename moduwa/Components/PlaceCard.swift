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
                    // 사진 위에서는 흰 원 + 딥그린 아이콘, 플레이스홀더 위에서는 딥그린 원 + 흰 아이콘
                    AccessibilityBadge(
                        feature: place.feature,
                        style: place.imageURL != nil ? .inverted : .filled
                    )
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
                    categoryArtwork
                }
            }
    }

    /// 사진이 **없는** 장소의 자리. 관광공사가 사진을 올리지 않은 곳이 5곳 중 1곳이라
    /// 드물게 나는 예외가 아니라 늘 보이는 상태다(2026-08-16 측정, `APIFeedService` 주석 참고).
    ///
    /// `PhotoPlaceholder`("장소 사진" 이라 적힌 회색 상자)를 쓰지 않는다 — 그건 주석이 밝히듯
    /// **개발용 자리 표시**라 화면에 남으면 "빠진 자리" 로 읽힌다. 카테고리 아이콘을 놓으면
    /// 같은 자리가 "사진이 없다" 가 아니라 "이런 종류의 장소" 라는 정보를 전한다.
    private var categoryArtwork: some View {
        LinearGradient(
            colors: [Color.gradientLime.opacity(0.35), Color.photoPlaceholder],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(place.category.iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .foregroundStyle(Color.deepGreen.opacity(0.55))
        }
        // 카테고리는 카드 본문에도 글자로 있다 — 여기서 또 읽어 주면 같은 말이 두 번 난다.
        .accessibilityHidden(true)
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
