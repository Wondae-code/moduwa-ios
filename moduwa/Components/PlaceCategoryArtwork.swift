import SwiftUI

/// 사진이 **없는** 장소의 사진 자리.
///
/// 관광공사가 사진을 올리지 않은 곳이 5곳 중 1곳이라(2026-08-16 측정, `APIFeedService` 주석)
/// 드물게 나는 예외가 아니라 늘 보이는 상태다. 그래서 개발용 자리 표시(`PhotoPlaceholder`,
/// "장소 사진" 이라 적힌 상자)를 쓰지 않는다 — 그건 화면에 남으면 "빠진 자리" 로 읽힌다.
/// 카테고리 아이콘을 놓으면 같은 자리가 "사진이 없다" 가 아니라 "이런 종류의 장소" 를 전한다.
///
/// **한 규칙을 세 카드가 함께 쓴다** — 홈 추천(`PlaceCard`), 저장 목록(`SavedPlaceCard`),
/// 함께 가볼만한 곳(`RelatedPlaceCard`). 예전에는 셋이 서로 다르게 그렸다(라임 그라데이션 +
/// 딥그린 / 회색 + 옅은 딥그린 / "장소 사진" 상자). 같은 상황에 세 가지 답이 있으면 어느
/// 하나를 고쳐도 나머지가 남는다.
///
/// ⚠️ **아이콘은 흰색이고, 배경(`#E6E6E6`)과의 대비는 1.25:1 이다** — 옅게 비치는 "유령"
/// 표현이고 의도된 것이다(2026-09-07 요청). WCAG 1.4.11(비텍스트 3:1)에 걸리지 않는 이유는
/// 이것이 **장식**이기 때문이다: 스크린리더에서 감추고(`accessibilityHidden`), 카테고리는
/// 카드 본문에도 글자로 있다. 정보를 지고 있다면 이 대비로 둘 수 없다.
///
/// 배경은 `cardPhotoEmpty`(Gray 10%) 다 — **받는 중을 뜻하는 `photoPlaceholder`(Gray 5%)보다
/// 한 단 짙다.** 흰 아이콘이 보이려면 그래야 하고, 덤으로 두 상태가 색으로도 갈린다.
/// 고대비에서는 더 짙어져(#B3B3B3) 1.91:1 까지 올라간다.
struct PlaceCategoryArtwork: View {
    /// **모르면 `nil`** — 그때는 배경만 그린다. `RelatedPlace` 에는 카테고리 필드가 없어서
    /// (`RelatedPlace.place` 가 `.attraction` 으로 고정해 두고 있다) 아이콘을 그리면 호텔에
    /// 관광지 그림이 붙는다. **틀린 정보를 주는 것보다 아무것도 안 주는 편이 낫다.**
    let category: PlaceCategory?
    /// 카드 크기가 달라 자리마다 다르다 — 홈 추천은 34, 저장 목록은 30.
    var iconSize: CGFloat = 34

    var body: some View {
        Color.cardPhotoEmpty
            .overlay {
                if let category {
                    Image(category.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(.white)
                }
            }
            // 카테고리는 카드 본문에도 글자로 있다 — 여기서 또 읽어 주면 같은 말이 두 번 난다.
            .accessibilityHidden(true)
    }
}

#Preview("카테고리별") {
    HStack(spacing: 12) {
        ForEach(PlaceCategory.allCases, id: \.self) { category in
            PlaceCategoryArtwork(category: category)
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    AccessibilityBadge(feature: .wheelchairAccessible, style: .inverted)
                        .padding(8)
                }
        }
    }
    .padding()
}
