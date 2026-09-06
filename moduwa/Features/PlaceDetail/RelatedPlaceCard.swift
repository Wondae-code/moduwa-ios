import SwiftUI

/// "함께 가볼만한 곳" 가로 캐러셀 카드 (Figma 369:68, 170×194).
///
/// 홈 피드 `PlaceCard`를 재사용하지 않는 이유: 규격이 다르다. 접근성 뱃지·안내 문구가 없고,
/// 2열 그리드가 아니라 가로 스크롤이라 폭을 스스로 정해야 한다.
struct RelatedPlaceCard: View {
    let place: RelatedPlace

    /// 시안 폭 170. 글자만 커지고 폭이 고정이면 이름·지역이 두세 줄로 접히다 잘리므로 폭도 함께 키운다.
    /// 상한 300 — 다음 카드가 살짝 보여야 "옆으로 더 있다"는 게 전달된다.
    @ScaledMetric(relativeTo: .headline) private var scaledWidth: CGFloat = 170

    private var width: CGFloat { min(scaledWidth, 300) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.cardTitle)
                    .foregroundStyle(.textPrimary)
                    // 이름은 두 줄까지 허용 — 큰 글자에서 한 줄로 자르면 장소를 구분할 수 없다
                    .lineLimit(2)

                HStack(alignment: .top, spacing: 3) {
                    Image("location_on")
                        .renderingMode(.template)
                    Text(place.region)
                        .font(.caption12)
                        .lineLimit(2)
                }
                .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width)
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

    /// 이미지가 레이아웃 크기를 결정하지 못하도록 투명 뷰 위에 오버레이한다 (PlaceCard와 같은 이유).
    private var photo: some View {
        Color.clear
            .overlay {
                if let imageURL = place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        // 받는 중 — 곧 사진이 들어올 자리다. 여기서 카테고리 아이콘을 띄우면
                        //  사진이 오면서 깜빡인다.
                        Color.photoPlaceholder
                    }
                } else {
                    // 개발용 "장소 사진" 상자(`PhotoPlaceholder`)를 쓰고 있었다 — 사용자가
                    //  보는 화면에 그 글자가 그대로 보였다.
                    //
                    // ⚠️ **카테고리는 `nil` 로 넘긴다** — `RelatedPlace` 에 카테고리 필드가
                    //  없다(서버 응답에 없어서 `RelatedPlace.place` 가 `.attraction` 으로
                    //  고정해 둔다). 그 값으로 아이콘을 그리면 호텔에 관광지 그림이 붙는다.
                    //  서버가 카테고리를 실어 주면 그때 아이콘이 붙는다.
                    PlaceCategoryArtwork(category: nil)
                }
            }
    }

    /// 카드에 뱃지가 없어도 어떤 접근성 지원이 있는지는 스크린리더로 전달한다.
    private var accessibilitySummary: String {
        var parts = [place.name, place.region]
        if !place.features.isEmpty {
            parts.append(place.features.map(\.label).joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
            RelatedPlaceCard(place: RelatedPlace(
                id: "1", name: "동궁과 월지", region: "경북 경주시 인왕동",
                imageURL: nil, features: [.wheelchairAccessible]
            ))
            RelatedPlaceCard(place: RelatedPlace(
                id: "2", name: "장흥 126타워(정남진 전망대)", region: "전남 장흥군",
                imageURL: nil, features: [.wheelchairAccessible, .visuallyImpairedFriendly]
            ))
        }
        .padding(24)
    }
}

#Preview("큰 글자 (AX3)") {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
            RelatedPlaceCard(place: RelatedPlace(
                id: "1", name: "동궁과 월지", region: "경북 경주시 인왕동",
                imageURL: nil, features: [.wheelchairAccessible]
            ))
            RelatedPlaceCard(place: RelatedPlace(
                id: "2", name: "장흥 126타워(정남진 전망대)", region: "전남 장흥군",
                imageURL: nil, features: [.wheelchairAccessible]
            ))
        }
        .padding(24)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
