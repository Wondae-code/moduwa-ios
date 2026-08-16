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
