import Foundation

/// 신고할 대상 (`POST /v1/reports` 의 `targetType` + `targetId`, 서버 2026-08-31).
///
/// 대상이 넷이어도 **화면은 한 벌**이다(`ReportSheet`) — 사유·상세·멱등 규칙이 전부 같아서,
/// 대상마다 시트를 두면 같은 것을 네 번 손보게 된다. 달라지는 것은 제목 한 줄뿐이다.
///
/// `targetId` 가 문자열인 이유: 게시글은 uuid 이고 나머지는 정수인데 서버가 **전부 문자열로**
/// 통일해 받는다. 앱도 그 경계에서만 문자열로 만들고 모델에는 각자의 타입을 유지한다.
enum ReportTarget: Hashable, Sendable, Identifiable {
    case post(id: String)
    case postComment(id: String)
    case review(id: Int)
    case reviewComment(id: Int)

    /// 서버가 받는 `targetType`.
    var type: String {
        switch self {
        case .post: "post"
        case .postComment: "post_comment"
        case .review: "review"
        case .reviewComment: "review_comment"
        }
    }

    /// 서버가 받는 `targetId`.
    var targetId: String {
        switch self {
        case .post(let id), .postComment(let id): id
        case .review(let id), .reviewComment(let id): String(id)
        }
    }

    /// `sheet(item:)` 용. 종류가 다르면 아이디가 같아도 다른 대상이다(게시글 12 ≠ 댓글 12).
    var id: String { "\(type):\(targetId)" }

    /// 시트 제목에 들어가는 대상 이름.
    var noun: String {
        switch self {
        case .post: "게시글"
        case .review: "후기"
        case .postComment, .reviewComment: "댓글"
        }
    }
}
