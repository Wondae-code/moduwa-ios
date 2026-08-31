import Observation

/// 내가 쓴 게시글의 아이디 모음. 어느 목록에서 열어도 "이 글이 내 글인지"를 알기 위한 것이다.
///
/// **왜 필요한가**: 게시글 응답에 **소유 표시가 없다** — `authorInfo` 는 닉네임과 사진만 준다
/// (`likedByMe` 처럼 `isMine` 이 오면 이 저장소는 통째로 사라진다 —
/// `docs/BACKEND_REQUEST_post-ownership.md` 로 요청해 두었다).
/// 그래서 "내 글만" 목록(`GET /v1/posts?mine=true`)을 한 번 받아 아이디를 쥐고 그것으로 가른다.
///
/// **닉네임으로 짐작하지 않는 이유**: 동명이인이 있으면 남의 글에 수정·삭제 메뉴가 달린다.
/// 눌러도 서버가 404 로 막지만, 메뉴가 보이는 것 자체가 "지울 수 있다"는 약속이다.
///
/// 실패하는 방향이 안전하다 — 못 받았거나 창(아래 상한) 밖의 오래된 글이면 메뉴가 **안 보인다**.
/// 남의 글에 메뉴가 보이는 일은 없다.
@MainActor
@Observable
final class MyPostIDStore {
    private(set) var ids: Set<String> = []
    /// 이번 실행에서 한 번이라도 받아 봤는지. 화면마다 다시 받지 않으려고 본다.
    private var didLoad = false
    private var isLoading = false

    /// 한 번에 받는 창. 서버 상한이 100 이고, 그보다 많이 쓴 사람의 오래된 글은
    /// 메뉴가 안 보일 수 있다(그 방향의 실패는 안전하다). 5장까지만 훑는다 —
    /// 상세 화면 하나 여는 값으로 무한히 페이지를 넘길 이유가 없다.
    private static let pageSize = 100
    private static let maxPages = 5

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// 아직 받지 않았으면 받는다. 게시글 상세가 열릴 때 부른다(로그인한 경우에만).
    func loadIfNeeded(using service: any PostService) async {
        guard !didLoad, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var collected: Set<String> = []
        for page in 0..<Self.maxPages {
            do {
                let posts = try await service.fetchPosts(
                    mineOnly: true, likedOnly: false, contentId: nil,
                    limit: Self.pageSize, offset: page * Self.pageSize)
                collected.formUnion(posts.map(\.id))
                // 창보다 적게 왔으면 마지막 장이다.
                if posts.count < Self.pageSize { break }
            } catch {
                // 실패는 "내 글이 없다" 가 아니다 — `didLoad` 를 세우지 않아 다음에 다시 받는다.
                //  받아 둔 것은 남긴다(다음 시도까지 아무것도 못 가르는 것보다 낫다).
                ids.formUnion(collected)
                return
            }
        }
        ids = collected
        didLoad = true
    }

    /// 방금 쓴 글. 목록을 다시 받지 않아도 내 것임을 안다.
    func note(created id: String) { ids.insert(id) }

    /// 지운 글. 남겨 둘 이유가 없다.
    func note(deleted id: String) { ids.remove(id) }

    /// 로그아웃·계정 전환. **반드시 비운다** — 다음 사람의 화면에서 남의 글에 수정 메뉴가
    /// 달리면 안 된다.
    func clear() {
        ids = []
        didLoad = false
    }
}
