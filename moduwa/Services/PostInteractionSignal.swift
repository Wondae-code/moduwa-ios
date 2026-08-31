import SwiftUI

/// 게시글 좋아요가 일어났다는 앱 전역 신호.
///
/// 저장 탭의 "좋아요한 게시물"은 게시글 상세와 **다른 화면**이라, 상세에서 좋아요를 눌러도
/// 그 목록이 저절로 갱신되지 않는다. 탭이 바뀔 때만 재로드하던 구조(`.task(id: selectedTab)`)는
/// liked 탭을 이미 본 뒤 다른 탭에서 좋아요를 누르고 돌아오면 `selectedTab` 이 그대로라
/// 재로드를 놓친다(A13 이 아니라 A23 — 기획 지적).
///
/// 좋아요가 일어난 순간을 여기서 방송하고, 목록을 든 화면이 그 값을 `.task(id:)` 로 지켜본다.
/// `SavedPlacesStore` 처럼 화면마다 상태를 따로 들지 않아도 되는 앱 전역 사건이다.
@Observable
final class PostInteractionSignal {
    /// 좋아요가 바뀔 때마다 오른다. 값 자체에는 뜻이 없고 "바뀌었다"는 신호다.
    private(set) var likeRevision = 0

    /// 게시글 좋아요/취소가 성공했을 때 부른다.
    func postLikeChanged() { likeRevision += 1 }

    /// 이 실행에서 지운 글. 목록을 든 화면이 그리기 전에 걸러낸다 —
    /// 상세에서 지운 글이 홈·저장·장소 후기 목록에 계속 남아 있으면 눌렀을 때 404 가 된다.
    ///
    /// 다시 받아오게 하지 않고 **걸러내는** 쪽을 고른 이유: 삭제는 이미 서버에 반영됐고,
    /// 목록 재요청은 사용자가 보고 있던 스크롤 위치를 잃게 만든다.
    private(set) var deletedPostIDs: Set<String> = []

    /// 게시글 삭제가 성공했을 때 부른다.
    func postDeleted(id: String) { deletedPostIDs.insert(id) }
}
