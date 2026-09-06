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
    /// 추가정보 bullet 문장 전체 — **그룹을 합치면서 같은 문장은 한 번만 남긴다.**
    ///
    /// ⚠️ 그냥 `flatMap` 하면 **같은 줄이 두 번 나온다.** 고령자는 관광공사 원본에 전용
    /// 속성이 없어서 휠체어 대여·승강기·주차 원문을 **지체장애 그룹과 함께 쓴다**
    /// (`APIFeedService` 의 그룹 표 주석). 한 장소가 두 유형에 다 해당하는 것은 맞지만,
    /// 문장을 늘어놓는 자리에서까지 두 번 말할 이유는 없다 — 실측(라마다 구미):
    /// "엘리베이터 있음"과 "장애인 주차장 있음(4면)"이 목록 끝에 그대로 다시 붙었다
    /// (2026-09-06 QA #1 "중복 데이터 삭제"). 낭독도 이 목록을 읽어서 같은 문장을 두 번 읽었다.
    ///
    /// 뱃지를 눌렀을 때 뜨는 안내 칩은 **그룹의 `notes` 를 그대로** 쓰므로 영향이 없다 —
    /// 고령자 뱃지를 누르면 승강기·주차 안내가 그대로 나온다. 합치는 이 자리에서만 걸러 낸다.
    var accessibilityNotes: [String] {
        var seen = Set<String>()
        return accessibilityGroups.flatMap(\.notes).filter { seen.insert($0).inserted }
    }

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

/// 장소를 남에게 보낼 때의 글.
///
/// **링크만 보내지 않는다.** 링크를 받은 사람이 앱을 깔지 않았다면 웹 안내 페이지로 가는데,
/// 카카오톡 대화창에서 눈으로 스치는 것은 이 글이다 — 무장애 항목이 여기 없으면 우리가
/// 보여 주려던 것이 한 번 더 눌러야 보이는 곳으로 밀려난다.
///
/// 상세를 아직 못 받았을 때는 목록 정보(`Place`)로도 만들 수 있어야 해서 모델 밖에 둔다 —
/// 화면은 이름조차 두 곳(`detail?.name ?? place.name`)에서 가져온다.
enum PlaceShareText {
    static func make(
        name: String, address: String, features: [AccessibilityFeature], url: URL?
    ) -> String {
        var lines = [name]
        if !address.isEmpty { lines.append(address) }
        if !features.isEmpty {
            lines.append("무장애: " + features.map(\.label).joined(separator: ", "))
        }
        if let url {
            lines.append("")
            lines.append(url.absoluteString)
        }
        lines.append("")
        // 출처 표기는 무장애 정보를 실었을 때만 붙인다 — 이름·주소만 보낼 때까지
        //  관광공사를 적으면 사실과 다르다(그 두 줄은 화면에 보이는 값이다).
        lines.append(features.isEmpty
            ? "모두와에서 공유했어요"
            : "모두와에서 공유했어요 · 무장애 정보 출처: 한국관광공사 TourAPI")
        return lines.joined(separator: "\n")
    }
}

extension Place {
    /// 공유 링크로 들어와 **목록 정보가 없을 때** 상세로 만드는 최소 요약.
    ///
    /// ⚠️ `category` 는 상세 응답에 없다(`contentTypeId` 를 안 준다). 장소 상세 화면은 이 값을
    /// 쓰지 않아서 기본값을 넣어 둔다 — 이 값을 읽는 화면이 생기면 서버에 필드를 요청해야 한다.
    init(linkedFrom detail: PlaceDetail) {
        self.init(
            id: detail.id,
            name: detail.name,
            region: detail.address,
            rating: detail.rating,
            accessibilityNote: detail.accessibilityNotes.first ?? "",
            feature: detail.accessibilityFeatures.first ?? .wheelchairAccessible,
            category: .attraction,
            imageURL: detail.imageURL,
            latitude: detail.latitude,
            longitude: detail.longitude
        )
    }
}
