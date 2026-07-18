import SwiftUI

/// 추천 장소 카드 (2열 그리드용)
struct PlaceCard: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .frame(height: 120)
                .clipped()
                .overlay(alignment: .topLeading) {
                    AccessibilityBadge(feature: place.feature)
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
    HStack(spacing: 14) {
        PlaceCard(place: MockData.recommendedPlaces[0])
        PlaceCard(place: MockData.recommendedPlaces[2])
    }
    .padding()
    .background(Color.photoPlaceholder)
}
