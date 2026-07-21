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
    /// 사진·추가정보의 원형 뱃지 (접근성 유형)
    let accessibilityFeatures: [AccessibilityFeature]
    /// 추가정보 bullet 문장들 (백엔드 무장애 속성 원문 정리)
    let accessibilityNotes: [String]
    /// 주의 태그 칩 (아이동반주의 등) — 소스 없으면 미표시
    let cautionTags: [String]
    /// 카카오맵 링크용 좌표 (mapy=위도, mapx=경도)
    let latitude: Double?
    let longitude: Double?

    var kakaoMapURL: URL? {
        guard let latitude, let longitude,
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://map.kakao.com/link/map/\(encoded),\(latitude),\(longitude)")
    }
}
