import Foundation

/// 리뷰 상세의 댓글 한 건 (`GET /v1/reviews/:reviewId/comments`).
struct ReviewComment: Identifiable, Hashable, Sendable {
    /// 서버 댓글 id. 리뷰(`TravelReview`)와 달리 목록에 항상 실려 오므로 그대로 `Identifiable` 키로 쓴다.
    let id: Int
    let author: String
    let body: String
    let createdAt: Date
    /// 서버 `authorInfo.level` / `authorInfo.reviewCount` — 후기 작성자 뱃지와 같은 출처.
    /// 지금 댓글 행은 이름·시간·본문만 그리지만, 서버가 주는 값을 모델에서 버리면
    /// 뱃지를 붙일 때 API부터 다시 봐야 한다.
    var authorLevel: Int? = nil
    var authorReviewCount: Int? = nil
    /// 작성자 프로필 사진(`authorInfo.avatarUrl`). 없으면 이니셜 원.
    var authorAvatarURL: URL? = nil
    /// 보는 사람이 쓴 댓글인지(서버 `isMine`, 2026-08-31). 수정·삭제 메뉴를 띄울 근거다.
    var isMine: Bool = false

    /// 아바타에 넣을 이름 첫 글자
    var initial: String { String(author.prefix(1)) }

    /// 서버 본문 상한과 같은 값 (초과하면 400)
    static let bodyLimit = 1000
}

/// 댓글 목록 한 페이지.
///
/// `total`을 함께 들고 오는 이유: 화면의 댓글 수를 **한 곳에서만** 정해야 한다.
/// 받아 온 배열 길이는 페이지 크기에 잘린 값이고, `TravelReview.commentCount`는
/// 리뷰 목록을 받은 시점의 값이라 방금 쓴 댓글이 빠진다. 서버 집계인 `total`이 유일한 출처다.
struct ReviewCommentPage: Sendable {
    let total: Int
    /// **오래된 순**(대화 순서)이다 — 후기 목록처럼 최신순이 아니다.
    let items: [ReviewComment]

    static let empty = ReviewCommentPage(total: 0, items: [])
}
