import Foundation

/// 장소 상세 (Figma "추천장소 B") — 무장애 28속성 상세 + 기본정보
struct PlaceDetail: Sendable {
    struct InfoRow: Identifiable, Sendable {
        let label: String
        let value: String
        var isLink: Bool = false
        var id: String { label }
    }

    let id: String
    let name: String
    let address: String
    let imageURL: URL?
    /// 평점 데이터 소스가 아직 없다 — nil이면 별점 행 숨김
    let rating: Double?
    let reviewCount: Int?
    /// 장소 설명 — 소스 없으면 섹션 숨김
    let overview: String?
    /// 기본정보(운영시간·휴무일 등) — 비어 있으면 섹션 숨김
    let info: [InfoRow]
    /// 접근성 유형별 안내 그룹 — 뱃지(유형)와 안내 문장을 함께 담는다
    struct AccessibilityGroup: Sendable, Hashable {
        let feature: AccessibilityFeature
        let notes: [String]
    }

    /// 접근성 유형별 안내 (뱃지 탭 시 해당 유형의 안내 칩 표시)
    let accessibilityGroups: [AccessibilityGroup]
    /// 주의 태그 칩 (아이동반주의 등) — 소스 없으면 미표시
    let cautionTags: [String]
    /// 카카오맵 링크용 좌표 (mapy=위도, mapx=경도)
    let latitude: Double?
    let longitude: Double?
    /// 서버가 kakao_place 를 매칭해 준 **그 장소의** 카카오맵 상세 링크(`kakaoPlaceUrl`).
    /// 매칭 안 된 곳(약 17%)은 nil — 그때는 좌표 링크로 폴백한다.
    var kakaoPlaceURL: URL? = nil

    /// 원형 뱃지로 표시할 접근성 유형들
    var accessibilityFeatures: [AccessibilityFeature] { accessibilityGroups.map(\.feature) }
    /// 추가정보 bullet 문장 전체
    var accessibilityNotes: [String] { accessibilityGroups.flatMap(\.notes) }

    /// 지도 버튼이 여는 카카오맵 링크.
    ///
    /// **장소 상세 링크(`kakaoPlaceURL`)를 우선한다** — 그래야 핀만 찍히는 게 아니라 그 장소의
    /// 카카오맵 상세(리뷰·사진·길찾기)가 열린다(M6). 서버가 매칭 못 한 곳만 좌표 링크로 폴백하는데,
    /// 좌표 링크는 이름표가 붙은 마커까지만 보여 준다.
    var kakaoMapURL: URL? {
        if let kakaoPlaceURL { return kakaoPlaceURL }
        guard let latitude, let longitude,
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://map.kakao.com/link/map/\(encoded),\(latitude),\(longitude)")
    }
}
