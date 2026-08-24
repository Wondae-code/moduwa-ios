import Foundation

/// 후기 작성 초안. `POST /v1/reviews`에 실을 값을 한 곳에 모아 둔다.
///
/// 작성자는 **세션의 계정**이다(백엔드 030). 예전에는 기기 UUID 를 함께 실어 그것으로
/// 작성자를 정했는데, 그 방식은 "값을 아는 사람이 그 사람"이라 남의 글을 대신 쓸 수 있었다.
/// `nickname` 만 남는데, 그것도 신원이 아니라 **계정 닉네임을 갱신하려는 값**이다.
struct ReviewDraft: Sendable {
    /// 관광공사 contentId — 어느 장소의 후기인지 식별하는 키
    let contentId: String?
    let placeName: String
    let rating: Int
    let body: String
    /// 사용자가 직접 정한 표시 이름. 비어 있으면 서버가 계정 닉네임을 그대로 쓴다.
    let nickname: String
    /// 고른 태그의 `ReviewTag.code`. 서버가 모르는 코드는 400이므로
    /// `fetchReviewTags()`로 받은 목록에서만 만든다.
    var tags: [String] = []
    /// "재방문을 하고 싶어요". **미체크는 false가 아니라 nil**(미응답)이다 —
    /// 서버가 세 상태를 구분해 저장하고, 생략하면 별점으로 추측하지 않는다.
    var wouldRevisit: Bool? = nil
    /// `POST /v1/reviews/images`가 돌려준 URL. 등록 전에 업로드를 먼저 끝낸다.
    var imageURLs: [URL] = []

    /// 서버 본문 상한과 같은 값
    static let bodyLimit = 2000
    /// 서버가 한 번에 받는 사진 수 상한
    static let imageLimit = 5
}

/// 작성자 정보 로컬 보관.
enum ReviewAuthorStore {
    /// `@AppStorage`와 같은 키를 공유한다.
    /// ⚠️ 표시 이름의 정본은 **계정**(`Account.nickname`)이다 — 이 값은 입력칸 초기값일 뿐이다.
    static let nicknameKey = "reviewAuthorNickname"
    static let nicknameLimit = 12
    private static let deviceIdKey = "reviewAuthorDeviceId"

    /// 이 기기를 가리키는 키. **신원이 아니다** — 가입·로그인 요청에 실어
    /// "이 계정이 이 기기를 쓴다"는 기록(`author_devices`)을 남기는 데만 쓴다.
    /// 예전에는 이 값이 곧 작성자였고, 그래서 값을 아는 사람이 남이 될 수 있었다.
    ///
    /// `identifierForVendor`는 앱을 모두 지우면 바뀌므로 직접 생성해 UserDefaults에 남긴다.
    static var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIdKey) { return saved }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }
}
