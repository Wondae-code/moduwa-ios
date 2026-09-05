import Foundation

/// 후기 태그 (`GET /v1/review-tags`).
///
/// 작성 화면의 다중 선택 칩, 장소 후기 화면의 집계 막대, 후기 한 줄의 뱃지가 모두 이 타입을 쓴다.
/// 세 자리의 문구 길이가 달라 서버가 `label`/`shortLabel`을 함께 준다 —
/// 앱에서 잘라 쓰지 말고 자리에 맞는 필드를 고른다.
struct ReviewTag: Identifiable, Hashable, Sendable {
    /// 서버 저장 키. `POST /v1/reviews`의 `tags`에 이 값을 그대로 싣는다 (모르는 코드는 400).
    let code: String
    /// 무엇을 묻는 태그인가(서버 051). **두 축을 섞지 않는다** —
    /// 장소 평가와 방문 조건은 묻는 대상이 다르고, 작성 화면도 따로 보여 준다.
    var kind: ReviewTagKind = .place
    /// "무장애 친화적이에요" — 작성 칩·집계 막대
    let label: String
    /// "무장애" — 후기 한 줄의 뱃지
    let shortLabel: String
    /// Assets 이미지 이름. **null인 태그가 있다**(반려동물·가성비·친절·주차) —
    /// 브랜드 에셋이 없다는 뜻이므로 대체 아이콘을 끼워 넣지 말고 텍스트만 그린다.
    let icon: String?

    var id: String { code }
}

/// 태그가 묻는 것.
///
/// - `place`: 장소 평가 — "음식이 맛있어요", "무장애 친화적이에요"
/// - `visitor`: 방문 조건 — "휠체어로 방문했어요". **쓴 사람에 대한 정보라 더 조심해서 다룬다**
///   (프로필의 무장애 항목과 코드가 1:1 이지만, 프로필은 비공개이고 이 태그는 공개다).
enum ReviewTagKind: String, Decodable, Sendable {
    case place, visitor
}

/// 장소별 태그 집계 한 칸 (`GET /v1/reviews/summary`의 `tags[]`).
/// 서버가 인원 많은 순으로 정렬해 준다.
struct ReviewTagCount: Identifiable, Hashable, Sendable {
    let tag: ReviewTag
    /// 이 태그를 고른 후기 수
    let count: Int

    var id: String { tag.code }
}
