import Foundation

/// AI 추천 코스 요청 (`POST /v1/plans/recommend`).
///
/// 새 플랜 플로우가 6단계에 걸쳐 모은 값이 그대로 들어간다. 지역은 **필수**다 —
/// 서버가 지역 없이는 후보를 고를 수 없다(2/6을 건너뛴 사용자에게는 코스를 제안하지 않는다).
struct CourseRequest: Sendable {
    /// 서버 `region_slugs` 의 슬러그(`gangneung`). `TravelRegion.courseSlug` 가 만든다.
    var regionSlug: String
    var startDate: Date
    var endDate: Date
    /// `kids`·`pet`·`elderly`·`couple`·`friends`·`solo`. `TravelParty.courseCodes` 가 만든다.
    var party: [String]
    /// `GET /v1/plan-options` 의 테마 코드. 목록 밖 값은 서버가 400 으로 거절한다.
    var themes: [String]
    /// `low`·`medium`·`high`. nil 은 "고르지 않음"이고 저예산과 다르다.
    var budget: String?
    /// true 면 숙소를 고르지 않는다.
    var dayTripOnly: Bool
}

/// 서버가 제안한 코스. **아직 저장된 플랜이 아니다** — 사용자가 받아들이면 앱이 기존
/// 저장 경로(`PUT /v1/plans/:id`)로 올린다.
struct RecommendedCourse: Sendable {
    /// 서버가 해석한 지역 이름("강릉"). 앱이 보낸 슬러그의 사람용 표기다.
    var regionLabel: String
    /// 숙소. 당일치기면 nil 이다.
    var stay: PlanPlace?
    /// 그대로 `Plan.days` 에 넣을 수 있는 하루들.
    var days: [PlanDay]
    /// 결과가 어떻게 조정됐는지. 사용자에게 알려야 하는 것만 남긴다.
    var notes: [CourseNote]

    /// 안내할 것이 있으면 한 문장으로. 여러 개면 줄바꿈으로 잇는다.
    var noticeMessage: String? {
        let messages = notes.compactMap(\.message)
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}

/// 서버가 결과를 조정한 이유(`notes`).
///
/// 조용히 넘기지 않는 이유: 예산을 골랐는데 다른 가격대 숙소가 오거나 칸이 비어 있으면
/// 사용자는 앱이 자기 선택을 무시했다고 읽는다. 무엇이 왜 달라졌는지 말해 주는 편이 낫다.
enum CourseNote: String, Sendable {
    /// 고른 가격대에 숙소가 없어 인접 가격대로 넓혔다.
    case budgetFallback = "budget_fallback"
    /// 그래도 없어 가격대를 무시하고 골랐다.
    case budgetIgnored = "budget_ignored"
    /// 여행일이 혼잡도 예측 범위 밖이다.
    case noCongestionData = "no_congestion_data"
    /// 후보가 적어 일부 칸이 비었다.
    case thinPool = "thin_pool"
    /// 무장애 조사를 받지 않은 식당·카페가 섞였다(소도시에서 식사·카페 자리를 채우려고).
    /// **`false`는 "접근성이 나쁘다"가 아니라 "모른다"** — 문구도 그렇게 쓴다.
    case includesUnsurveyed = "includes_unsurveyed"

    /// 사용자에게 보여 줄 문구. `nil` 이면 알릴 필요가 없는 것이다.
    var message: String? {
        switch self {
        case .budgetFallback: "고르신 가격대에 맞는 숙소가 적어 비슷한 가격대까지 넓혀 골랐어요."
        case .budgetIgnored: "고르신 가격대에 맞는 숙소를 찾지 못해 가격대 없이 골랐어요."
        // 혼잡도는 화면에 드러나지 않는 값이라(v1) 없다고 알릴 것도 없다.
        case .noCongestionData: nil
        case .thinPool: "이 지역은 아직 등록된 장소가 적어 일부 시간대를 비워 뒀어요. 상세에서 직접 채울 수 있어요."
        case .includesUnsurveyed: "일부 식당·카페는 아직 무장애 조사를 받지 않았어요. 접근성 정보가 없는 곳이 섞여 있어요."
        }
    }
}
