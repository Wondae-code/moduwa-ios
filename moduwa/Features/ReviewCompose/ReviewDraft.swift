import Foundation

/// 후기 작성 초안. 서버 연동 전이라 전송되지 않지만, `POST /v1/reviews`에 실을 값을
/// 한 곳에 모아 두려고 만든 타입이다. 백엔드가 작성자를 "기기 UUID + 닉네임"으로 식별할 예정이라
/// `deviceId`/`nickname`을 함께 담는다.
struct ReviewDraft: Sendable {
    /// 관광공사 contentId — 어느 장소의 후기인지 식별하는 키
    let contentId: String?
    let placeName: String
    let rating: Int
    let body: String
    let nickname: String
    let deviceId: String
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

/// 작성자 정보 로컬 보관. 로그인이 없어 기기에만 남는다.
enum ReviewAuthorStore {
    /// `@AppStorage`와 같은 키를 공유한다
    static let nicknameKey = "reviewAuthorNickname"
    static let nicknameLimit = 12
    private static let deviceIdKey = "reviewAuthorDeviceId"

    /// 최초 호출 시 만들어 고정하는 익명 작성자 키.
    /// `identifierForVendor`는 앱을 모두 지우면 바뀌므로 직접 생성해 UserDefaults에 남긴다.
    static var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIdKey) { return saved }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }
}
