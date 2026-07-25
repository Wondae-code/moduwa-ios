import Foundation

/// 리뷰 상세의 댓글 한 건.
/// 백엔드 댓글 API가 아직 없어 현재는 **더미 + 로컬 입력**으로만 다룬다.
/// (서버 도입 시 `id`/작성시각을 서버 값으로 대체)
struct ReviewComment: Identifiable, Hashable {
    let id: UUID
    let author: String
    let timeAgo: String
    let body: String

    init(id: UUID = UUID(), author: String, timeAgo: String, body: String) {
        self.id = id
        self.author = author
        self.timeAgo = timeAgo
        self.body = body
    }

    /// 아바타에 넣을 이름 첫 글자
    var initial: String { String(author.prefix(1)) }
}

extension ReviewComment {
    /// 시연용 더미 댓글 풀 (Figma 리뷰 상세 시안 문구 포함)
    private static let pool: [ReviewComment] = [
        .init(author: "김민수", timeAgo: "2일 전", body: "저도 지난주에 다녀왔는데 정말 편했어요. 유용한 정보 감사합니다!"),
        .init(author: "이서연", timeAgo: "1일 전", body: "휠체어 대여도 되나요? 부모님 모시고 가려고 하는데 궁금합니다."),
        .init(author: "여행가고파", timeAgo: "3시간 전", body: "주차장에서 입구까지 경사로가 잘 되어 있어요. 걱정 마세요~"),
        .init(author: "초록발자국", timeAgo: "5일 전", body: "사진 잘 봤습니다. 다음 주말에 방문 예정인데 기대되네요."),
        .init(author: "바다보러가자", timeAgo: "6시간 전", body: "경사로 정보 정말 도움됐어요. 감사합니다!"),
    ]

    /// 리뷰별로 **결정적으로** 더미 댓글을 만든다.
    /// - 같은 리뷰는 항상 같은 목록(문자열 시드 기반) → 실행마다 흔들리지 않음
    /// - 일부 리뷰는 빈 목록을 돌려줘 '아직 댓글이 없어요' 빈 상태도 실제로 노출된다
    static func dummies(for review: TravelReview) -> [ReviewComment] {
        let key = review.contentId ?? review.author
        var seed = 0
        for scalar in key.unicodeScalars { seed = (seed &* 31 &+ Int(scalar.value)) & 0x7fff_ffff }

        // 40%는 빈 상태로 둔다
        let counts = [3, 0, 2, 3, 0]
        let n = counts[seed % counts.count]
        guard n > 0 else { return [] }

        let start = seed % pool.count
        return (0..<n).map { pool[(start + $0) % pool.count] }
    }
}
