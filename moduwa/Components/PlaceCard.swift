import SwiftUI

/// 추천 장소 카드 (2열 그리드용)
struct PlaceCard: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .frame(height: 108)
                .clipped()
                .overlay(alignment: .topLeading) {
                    AccessibilityBadge(feature: place.feature)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.cardTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image("location_on")
                        .renderingMode(.template)
                    Text(place.region)
                        .font(.meta13)
                }
                .foregroundStyle(.textSecondary)

                if let rating = place.rating {
                    HStack(spacing: 3) {
                        Image("star")
                            .renderingMode(.template)
                            .foregroundStyle(.deepGreen)
                        Text(rating, format: .number.precision(.fractionLength(1)))
                            .font(.meta13)
                            .fontWeight(.semibold)
                            .foregroundStyle(.textPrimary)
                    }
                }

                Text(place.accessibilityNote)
                    .font(.caption12)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    private var photo: some View {
        Group {
            if let imageURL = place.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    PhotoPlaceholder()
                }
            } else {
                PhotoPlaceholder()
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
    HStack {
        PlaceCard(place: MockData.recommendedPlaces[0])
        PlaceCard(place: MockData.recommendedPlaces[2])
    }
    .padding()
    .background(Color.appBackground)
}
