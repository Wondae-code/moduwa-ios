import Foundation

extension PlanPlace {
    /// 검색 결과(`Place`)를 일정에 박제할 형태로 옮긴다.
    ///
    /// 일정은 원본 POI 를 매번 다시 조회하지 않고 값을 그대로 들고 있는다(`PlanPlace` 주석 참고) —
    /// 지난 여행은 원본이 사라져도 그대로 보여야 하기 때문이다. 그래서 여기서 옮기는 값이
    /// 그 장소에 대해 일정이 아는 전부가 된다.
    init(searchResult place: Place) {
        self.init(
            // contentID 가 있으면 원본을 다시 열 수 있고, 리뷰 버튼도 이 값으로 갈린다.
            contentID: place.id,
            name: place.name,
            // 시안 부제목의 앞 조각. 검색 응답의 관광 타입 라벨("관광지"·"쇼핑"…)이 그대로 맞는다.
            //  `PlaceCategory` 4종은 그보다 좁아서(쇼핑이 없다) 표시는 이 문자열을 쓴다.
            categoryLabel: place.categoryLabel ?? place.category.rawValue,
            region: place.region,
            category: place.category,
            imageURL: place.imageURL,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }
}

extension Place {
    /// 일정에 담긴 장소를 **원본 상세를 열기 위한** 형태로 되돌린다(2026-08-16).
    ///
    /// 나만의 장소는 관광공사 원본이 없어 열 자리가 없다 — `contentID`가 없으면 nil 이고,
    /// 호출부는 그 줄을 누를 수 없게 그린다.
    ///
    /// 일정이 들고 있지 않은 값(평점·접근성)은 **여기서 지어내지 않는다**. 장소 상세는 이
    /// id 로 본문·접근성·후기를 서버에서 다시 받고, 받기 전에는 이름·지역·사진만 그린다
    /// (`PlaceDetailView`) — 아래 두 자리는 그 화면이 읽지 않는 필드를 형식상 채운 값이다.
    init?(planPlace place: PlanPlace) {
        guard let contentID = place.contentID else { return nil }
        self.init(
            id: contentID,
            name: place.name,
            region: place.region ?? "",
            rating: nil,
            accessibilityNote: "",
            feature: .wheelchairAccessible,
            category: place.category ?? .attraction,
            categoryLabel: place.categoryLabel,
            imageURL: place.imageURL,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }
}
