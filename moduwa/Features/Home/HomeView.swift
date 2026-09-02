import SwiftUI

/// 홈 피드 (Figma "메인화면")
/// 홈 헤더에서 진입하는 서브 화면 라우트
enum HomeRoute: Hashable {
    case search
    case notifications
}

struct HomeView: View {
    @Environment(\.feedService) private var feedService
    @Environment(\.postService) private var postService
    @Environment(NotificationStore.self) private var notificationStore
    @Environment(PostInteractionSignal.self) private var postSignal
    /// 알림(좋아요·댓글)을 눌러 열어야 할 게시글.
    @Environment(\.pushRouter) private var pushRouter
    /// 차단하면 목록을 다시 받는다 — 거르는 일은 서버가 한다.
    @Environment(\.blockSignal) private var blockSignal
    @Environment(SessionStore.self) private var session
    /// 홈 히어로 CTA → 새 플랜 플로우(플랜 탭이 연다).
    @Environment(\.planCreation) private var planCreation
    @State private var viewModel = HomeViewModel()
    @State private var isSortPickerPresented = false
    /// 알림에서 온 게시글 상세. 목록에 없는 글일 수도 있어(다른 사람이 스크롤 밖의 글에
    /// 댓글을 달았다) 아이디로 받아 와 직접 민다.
    @State private var pushedPost: TravelPost?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            // 헤더는 스크롤 밖에 두어 상단에 고정한다 (Figma: top 프레임 sticky)
            VStack(spacing: 0) {
                headerBar
                    .background(Color.gradientLime.ignoresSafeArea(edges: .top))

                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                        recommendationSection
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.xl)

                        reviewSection
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.xl)
                    }
                }
                .background(.white)
            }
            .toolbar(.hidden, for: .navigationBar)
            // 시안 "01. 메인화면"의 Write Button(652:3399) — 우하단 라임 원.
            //  스크롤과 무관하게 떠 있어야 해서 `overlay` 로 얹는다(ScrollView 안에 두면 함께 밀린다).
            .overlay(alignment: .bottomTrailing) {
                // 쓰고 돌아오면 목록을 다시 받는다 — 그러지 않으면 방금 쓴 글이 보이지 않는다
                //  (`.task` 는 돌아올 때 다시 돌지 않는다, `WriteFloatingButton.onPosted` 참고).
                WriteFloatingButton {
                    Task { await viewModel.loadPosts(using: postService) }
                }
            }
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .search: SearchView()
                case .notifications: NotificationsView()
                }
            }
            .navigationDestination(for: TravelReview.self) { review in
                ReviewDetailView(review: review)
            }
            // 알림에서 온 글. 소유는 서버가 준 `isMine` 이 가른다.
            .navigationDestination(item: $pushedPost) { post in
                PostDetailView(post: post)
            }
        }
        // ⚠️ `onChange` 가 아니라 `task(id:)` 다 — 종료 상태에서 알림으로 앱이 열리면 값이
        //  이 뷰보다 먼저 담겨 변화 이벤트가 오지 않는다.
        .task(id: pushRouter.pendingPostID) { await openPushedPost() }
        // 차단하면 그 사람의 글이 응답에서 빠진다 — 다시 받아야 화면에서도 사라진다.
        .task(id: blockSignal.revision) {
            guard blockSignal.revision > 0 else { return }
            await viewModel.loadPosts(using: postService)
        }
        .task {
            await viewModel.loadInitial(using: feedService, accessFeatures: session.accessFeatures)
        }
        // 로그인·로그아웃, 그리고 내 정보에서 무장애 요소를 고쳤을 때 추천을 다시 받는다.
        .onChange(of: session.accessFeatures) { _, features in
            Task { await viewModel.applyAccessFeatures(features, using: feedService) }
        }
        // 게시글은 리뷰와 별도 요청이다 — 한 task 에 이어 붙이면 뒤엣것이 앞의 응답을 기다린다.
        .task { await viewModel.loadPosts(using: postService) }
        // 로그인·로그아웃이 일어나면 게시글을 다시 받는다 — 하트가 눌린 상태는 **보는 사람**에
        //  달려 있어서, 로그인만 하고 목록을 그대로 두면 내가 누른 글이 빈 하트로 남는다.
        .onChange(of: session.phase) { Task { await viewModel.loadPosts(using: postService) } }
    }

    // MARK: - 헤더

    /// 알림에서 온 게시글을 열어 준다.
    ///
    /// 실패하면 **조용히 넘긴다** — 대개 그 사이에 지워진 글이고, 알림을 눌렀더니 오류창이
    /// 뜨는 것보다 아무 일도 없는 편이 낫다(알림 자체는 이미 읽혔다).
    private func openPushedPost() async {
        guard let id = pushRouter.pendingPostID else { return }
        // ⚠️ **값을 먼저 비우지 않는다.** `task(id:)` 는 id 가 바뀌면 돌던 작업을 취소하는데,
        //  여기서 비우면 바로 아래 요청이 그 자리에서 취소된다(실측: 10ms 만에 실패).
        //  받아 온 뒤에 비우면 그 취소가 두 번째 호출을 막아 주는 역할까지 한다.
        let post = try? await postService.fetchPost(id: id)
        pushRouter.pendingPostID = nil
        pushedPost = post
        PushRegistrar.log.notice("알림에서 게시글 열기: \(id, privacy: .public) → \(post == nil ? "실패" : "성공", privacy: .public)")
    }

    private var headerBar: some View {
        HStack {
            Image("logo")
                .accessibilityLabel("모두와 홈")

            Spacer()

            // Figma: 아이콘마다 25×25 정렬 박스, 간격 10
            HStack(spacing: 10) {
                NavigationLink(value: HomeRoute.search) {
                    // 시안(153:20)의 돋보기는 25×25 — 앱의 `search`(17×20)가 아니라
                    //  장소 검색에서 쓰는 `plan_search` 와 같은 글리프다.
                    Image("plan_search")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                }
                .accessibilityLabel("검색")

                NavigationLink(value: HomeRoute.notifications) {
                    // 시안의 벨(13:549, 25×25)을 에셋으로 받아 쓴다 — 예전에는 SF Symbol
                    //  `bell` 이었고 글리프가 시안과 달랐다.
                    Image("notification")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .overlay(alignment: .topTrailing) {
                            // 안 읽은 알림이 있을 때만 도트 표시
                            if notificationStore.hasUnread {
                                Circle()
                                    .fill(.deepGreen)
                                    .stroke(.white, lineWidth: 1)
                                    .frame(width: 7, height: 7)
                                    .offset(x: -1, y: 1)
                            }
                        }
                }
                .accessibilityLabel(notificationStore.hasUnread ? "알림, 새 알림 있음" : "알림")

                // 설정으로 가는 문. 시안에서 이 자리가 햄버거 → 톱니로 바뀌었고, 다른 탭
                //  헤더에서는 아이콘이 빠졌다 — 그래서 앱의 설정 진입점은 여기 하나다.
                SettingsButton()
            }
            .foregroundStyle(.textPrimary)
        }
        // Figma header: 로고 좌측 28, 아이콘 우측 24 (비대칭), 아이콘 간격 10
        .padding(.leading, 28)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
    }

    // MARK: - 상단 (헤더 + 히어로, 배경 공유)

    /// 히어로 카드 영역 — 고정 헤더의 라임색에서 이어지는 그라데이션 배경.
    /// Figma: #CAF354 → 흰색 그라디언트 (히어로 카드 하단 부근에서 흰색 도달)
    private var heroSection: some View {
        VStack(spacing: 0) {
            // 카드 내용이 전부 계정에서 온다 — 받아 올 것이 없으니 조건 없이 그린다.
            //  (예전에는 번들 JSON 의 hero 를 기다렸고, 그 사이 카드 자리가 비어 있었다.)
            HeroCard(
                userName: session.account?.nickname,
                // 로그인했으면 계정 값, 아니면 기기에 있는 온보딩 값(`SessionStore.accessFeatures`).
                accessFeatures: session.accessFeatures,
                onSignIn: { session.prompt = .recommendation },
                // 플로우는 플랜 탭이 쥐고 있다 — 만들고 싶다고만 알린다(`PlanCreationSignal`).
                onStartPlan: { planCreation.isRequested = true }
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .gradientLime, location: 0),
                    .init(color: .gradientLime, location: 0.15),
                    .init(color: .white, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(alignment: .top) {
            // 오버스크롤(바운스) 영역까지 라임 배경이 이어지도록 위로 연장
            Color.gradientLime
                .frame(height: 1000)
                .offset(y: -1000)
        }
    }

    // MARK: - 추천 장소

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                title: "내 일정에 어울리는 추천 맛집·장소",
                subtitle: "온보딩 정보를 바탕으로 골라봤어요"
            )

            // 칩 스크롤은 섹션 좌우 마진을 뚫고 화면 끝까지 보이게 한다 (음수 패딩 + 내부 인셋)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { category in
                        CategoryChip(category: category, isSelected: category == viewModel.selectedCategory) {
                            Task { await viewModel.selectCategory(category, using: feedService) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 6) // 선택 칩 그림자가 잘리지 않도록
            }
            .padding(.horizontal, -Spacing.xl)
            .padding(.vertical, -6)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(viewModel.places) { place in
                    NavigationLink(value: place) {
                        PlaceCard(place: place)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.canLoadMorePlaces {
                LoadMoreButton(title: "맞춤 추천 더보기") {
                    Task { await viewModel.loadMorePlaces(using: feedService) }
                }
            }
        }
    }

    // MARK: - 여행자 리뷰

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .top) {
                SectionHeader(
                    title: "여행자 리뷰",
                    subtitle: "다녀온 여행자들의 생생한 후기"
                )
                sortMenu
            }

            // 게시글과 리뷰를 **고른 정렬대로 섞는다**(`HomeViewModel.feedItems`). 두 목록을
            //  따로 쌓으면 한쪽이 늘 위에 몰려 다른 쪽이 스크롤 아래로 밀리고,
            //  "여행자 리뷰"라는 한 섹션인데 둘로 갈려 보인다.
            ForEach(viewModel.feedItems) { item in
                switch item {
                case .review(let review):
                    NavigationLink(value: review) {
                        ReviewCard(review: review)
                    }
                    .buttonStyle(.plain)
                case .post(let post):
                    // 상세에서 지운 글은 목록에서 빠진다 — 남겨 두면 눌렀을 때 404 가 된다.
                    if !postSignal.deletedPostIDs.contains(post.id) {
                        NavigationLink { PostDetailView(post: post) } label: {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 후기와 게시글을 함께 이어 받는다 — 한 섹션에 섞여 있으니 한쪽만 늘면 안 된다.
            if viewModel.canLoadMoreFeed {
                LoadMoreButton(title: "리뷰 더보기") {
                    Task {
                        await viewModel.loadMoreFeed(
                            feedService: feedService, postService: postService)
                    }
                }
            }
        }
    }

    // 시스템 Menu는 스크롤 뷰 안에서 라벨이 플로팅 레이어에 남아
    // 스크롤과 어긋나게 움직이는 버그가 있어 버튼 + 팝오버로 구현한다.
    private var sortMenu: some View {
        Button {
            isSortPickerPresented = true
        } label: {
            HStack(spacing: 5) {
                Text(viewModel.reviewSort.rawValue)
                    .font(.notoSans(14, .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.deepGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isSortPickerPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ReviewSort.allCases, id: \.self) { sort in
                    Button {
                        isSortPickerPresented = false
                        Task { await viewModel.selectSort(sort, using: feedService) }
                    } label: {
                        HStack {
                            Text(sort.rawValue)
                                .font(.chip14)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if sort == viewModel.reviewSort {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.deepGreen)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sort == viewModel.reviewSort ? .isSelected : [])
                }
            }
            .frame(minWidth: 130)
            .padding(.vertical, 4)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("리뷰 정렬: \(viewModel.reviewSort.rawValue)순")
    }
}

#Preview {
    HomeView()
        .environment(NotificationStore())
        .environment(SessionStore(service: MockAuthService()))
        .environment(PostInteractionSignal())
}
