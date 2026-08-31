import SwiftUI

/// 설정 → 내 게시글. 내가 쓴 여행 게시글만 최근 순으로 모아 본다
/// (`GET /v1/posts?mine=true` — `PostService.fetchPosts(mineOnly:)`).
///
/// 시안이 없다. 저장 탭의 "좋아요한 게시물"과 **같은 화면 문법**을 그대로 쓴다 —
/// 같은 카드(`PostCard`), 같은 상태 네 가지(비로그인·로딩·실패·빈), 같은 여백. 내 글이라고
/// 다른 모양으로 보일 이유가 없고, 두 화면이 갈리면 같은 목록을 두 번 배우게 된다.
///
/// **수정·삭제는 상세 화면에서 한다**(어느 목록에서 열어도 같다 — 서버가 `isMine` 을 준다).
/// 목록에 스와이프 삭제를 두지 않은 이유: 카드가 사진까지 든 큰 행이라 손이 스치기 쉽고,
/// 되돌릴 수 없는 일을 그렇게 가볍게 둘 수 없다.
struct MyPostsView: View {
    @Environment(\.postService) private var postService
    @Environment(PostInteractionSignal.self) private var postSignal

    @State private var posts: [TravelPost] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    /// 한 번이라도 받아 봤는지. 새로고침이 실패했을 때 보고 있던 목록을 지우지 않으려고 본다.
    @State private var didLoad = false
    /// 로그인이 필요해 못 받았다. **오류와 구분한다** — "다시 시도"로는 영원히 같은 결과다.
    @State private var requiresSignIn = false

    var body: some View {
        VStack(spacing: 0) {
            title
            content
        }
        .background(Color.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var title: some View {
        Text("내 게시글")
            .font(.notoSans(20, .bold, relativeTo: .title3))
            .tracking(-0.4)
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// ⚠️ 어느 상태든 **남는 공간을 채운다**. 짧은 쪽이 내용 높이만 차지하면 바깥 `VStack` 이
    /// 짧아지고, SwiftUI 가 그 스택을 가운데로 정렬하면서 제목까지 아래로 내려온다
    /// (저장 탭에서 실측한 것과 같은 함정).
    @ViewBuilder
    private var content: some View {
        if requiresSignIn {
            SignInPromptView(
                title: "로그인하면 내가 쓴 글을 볼 수 있어요",
                message: "쓴 글은 계정에 남아요. 기기를 바꿔도 그대로 따라옵니다.",
                prompt: .writePost
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if isLoading && !didLoad {
            loadingRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if loadFailed && !didLoad {
            failedRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if visiblePosts.isEmpty {
            emptyRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            list
        }
    }

    /// 상세에서 지운 글은 곧바로 빠진다 — 목록을 다시 받지 않는다(스크롤 위치가 유지된다).
    private var visiblePosts: [TravelPost] {
        posts.filter { !postSignal.deletedPostIDs.contains($0.id) }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(visiblePosts) { post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCard(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .refreshable { await load() }
    }

    /// 스피너만 두면 스크린리더에는 아무것도 전달되지 않는다 — 문구를 함께 둔다.
    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.deepGreen)
            Text("내 게시글을 불러오는 중이에요")
                .font(.notoSans(14, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("내 게시글을 불러오는 중이에요")
    }

    private var failedRow: some View {
        VStack(spacing: 14) {
            Text("내 게시글을 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Button("다시 시도") { Task { await load() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    private var emptyRow: some View {
        VStack(spacing: 10) {
            Text("아직 쓴 글이 없어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("홈에서 연필 버튼을 눌러 여행 이야기를 남겨 보세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false
        requiresSignIn = false
        do {
            // 저장 탭의 좋아요 목록과 같은 창(30건). 서버가 최근 글부터 준다.
            posts = try await postService.fetchPosts(
                mineOnly: true, likedOnly: false, contentId: nil, limit: 30, offset: 0)
            didLoad = true
        } catch PostServiceError.loginRequired, PostServiceError.sessionExpired {
            // 로그아웃한 기기는 비어야 한다 — 이전 계정의 글이 남아 보이면 안 된다.
            posts = []
            didLoad = false
            requiresSignIn = true
        } catch {
            // 이미 받아 둔 목록은 지우지 않는다 — 새로고침이 실패했다고 보고 있던 글이
            //  사라지면 안 된다.
            loadFailed = true
        }
        isLoading = false
    }
}

#Preview("내 게시글") {
    NavigationStack {
        MyPostsView()
    }
    .environment(\.postService, MockPostService())
    .environment(SessionStore(service: MockAuthService()))
    .environment(PostInteractionSignal())
}
