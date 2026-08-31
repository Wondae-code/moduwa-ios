import SwiftUI

/// 저장 탭 — Figma "04. 저장 - 모아보기"(642:837) / "좋아요한 게시물"(642:1255)
///
/// 두 탭이 담는 것이 다르다. **저장 모아보기**는 저장한 장소를 카테고리별로 묶고,
/// **좋아요한 게시물**은 좋아요를 누른 여행 게시글을 **누른 순서**로 쌓는다.
///
/// 후기(`ReviewCard`)는 이 탭에 오지 않는다 — 후기 좋아요는 서버에 숫자(`like_count`)만
/// 있고 누가 눌렀는지가 없어 "내가 좋아한 후기"를 물을 수 없다. 게시글은 `post_likes` 에
/// 사람이 남아 물을 수 있다. 후기도 담으려면 서버에 좋아요 테이블이 먼저 필요하다.
struct CollectionView: View {
    @Environment(SavedPlacesStore.self) private var store
    @Environment(\.postService) private var postService
    @Environment(SessionStore.self) private var session
    @Environment(PostInteractionSignal.self) private var postSignal

    @State private var selectedTab: SavedTab = .places
    @State private var selectedCategory: PlaceCategory?

    /// 좋아요한 게시글. 탭을 처음 열 때 받는다 — 저장 탭을 여는 것만으로 부르면
    /// 보지도 않는 목록을 받는다.
    @State private var likedPosts: [TravelPost] = []
    @State private var isLoadingLiked = false
    @State private var didLoadLiked = false
    @State private var likedLoadFailed = false
    /// 로그인해야 볼 수 있음. 실패와 구분한다("다시 시도"가 답이 아니다).
    @State private var likedRequiresSignIn = false

    /// 시안 세그먼트 그대로.
    enum SavedTab: String, CaseIterable, Hashable {
        case places = "저장 모아보기"
        case liked = "좋아요한 게시물"
    }

    /// 칩 순서는 시안(전체 / 숙소 / 맛집 / 관광지)을 따른다.
    /// 축제·공연·전시는 시안 칩에 없지만 저장은 될 수 있어, "전체"에서는 함께 보인다.
    private static let chipCategories: [PlaceCategory] = [.stay, .food, .attraction]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                UnderlineTabBar(tabs: SavedTab.allCases, selection: $selectedTab)

                switch selectedTab {
                case .places:
                    categoryChips
                    placeList
                case .liked:
                    likedList
                }
            }
            .background(Color.appBackground)
            // 홈과 같은 자리에 같은 버튼. 하단에 고정 바가 없어 겹칠 것이 없다.
            .overlay(alignment: .bottomTrailing) { WriteFloatingButton() }
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
        }
        // 다른 화면에서 저장을 눌렀을 수도 있다 — 탭을 열 때마다 최신을 받는다.
        .task { await store.load(accessFeatures: session.accessFeatures) }
        // 좋아요 탭으로 넘어올 때마다 다시 받는다 — 다른 화면에서 하트를 눌렀을 수 있다.
        .task(id: selectedTab) {
            if selectedTab == .liked { await loadLiked() }
        }
        // 게시글 상세에서 좋아요를 누르면 이 값이 오른다 — liked 탭을 이미 본 뒤라도
        //  다른 탭에서 누르고 돌아왔을 때 목록이 갱신되지 않던 것을 고친다(A23).
        //  이미 한 번 받아 둔 뒤에만 다시 받는다(첫 진입은 위 task 가 맡는다).
        .task(id: postSignal.likeRevision) {
            if selectedTab == .liked, didLoadLiked { await loadLiked() }
        }
        // 로그인·로그아웃 직후에도 두 목록이 맞아야 한다. 로그아웃한 기기는 비어야 하고,
        //  로그인한 직후에는 곧바로 보여야 한다.
        // 무장애 요소를 고치면 카드의 뱃지·문구도 그 기준으로 다시 받는다(홈과 같다).
        //  목록 자체는 그대로다 — 저장한 것은 조건과 무관하게 다 보인다.
        .onChange(of: session.accessFeatures) { _, features in
            Task { await store.load(accessFeatures: features) }
        }
        .onChange(of: session.phase) {
            Task {
                await store.load(accessFeatures: session.accessFeatures)
                if selectedTab == .liked { await loadLiked() }
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Text("내 저장")
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .tracking(-0.4)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
    }

    // MARK: - 카테고리 칩

    /// 서버에 다시 묻지 않고 앱에서 거른다 — 저장 목록은 개인이 고른 것이라 크지 않고,
    /// 칩을 누를 때마다 왕복이 생기면 즉시 반응하지 않는다.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "전체", category: nil)
                ForEach(Self.chipCategories) { chip(label: $0.rawValue, category: $0) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
    }

    private func chip(label: String, category: PlaceCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withoutAnimation { selectedCategory = category }
        } label: {
            HStack(spacing: 6) {
                if let category {
                    Image(category.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                }
                Text(label)
                    .font(.notoSans(14, isSelected ? .bold : .medium, relativeTo: .subheadline))
                    .tracking(-0.4)
            }
            // 선택을 색만으로 전달하지 않는다 — 글자 굵기와 테두리 유무가 함께 바뀐다.
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(Capsule().fill(isSelected ? Color.deepGreen : .white))
            .overlay(Capsule().stroke(isSelected ? .clear : Color.cardStroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 목록

    /// 시안은 카테고리마다 "저장된 OO 모아보기" 제목을 달고 2열 그리드를 깐다.
    /// 칩으로 한 종류만 골랐어도 제목은 남긴다 — 지금 무엇을 보고 있는지가 사라지면 안 된다.
    @ViewBuilder
    private var placeList: some View {
        let sections = visibleSections
        ScrollView {
            if store.requiresSignIn {
                SignInPromptView(
                    title: "로그인하면 저장한 장소를 볼 수 있어요",
                    message: "저장은 계정에 남아요. 기기를 바꿔도 그대로 따라옵니다.",
                    prompt: .save
                )
            } else if store.isLoading && !store.didLoad {
                message("저장한 장소를 불러오는 중이에요", isLoading: true)
            } else if store.loadFailed && !store.didLoad {
                failedRow
            } else if sections.isEmpty {
                message(emptyText, isLoading: false)
            } else {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sections, id: \.category) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text("저장된 \(section.category.rawValue) 모아보기")
                                .font(.notoSans(18, .bold, relativeTo: .title3))
                                .tracking(-0.4)
                                .foregroundStyle(Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)

                            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 14) {
                                ForEach(section.places) { place in
                                    NavigationLink(value: place) {
                                        SavedPlaceCard(place: place)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBackground)
        .refreshable { await store.load(accessFeatures: session.accessFeatures) }
    }

    private static let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
    ]

    /// 저장 순서를 지키면서 카테고리별로 묶는다 — 먼저 저장한 종류의 섹션이 위로 온다.
    private var visibleSections: [(category: PlaceCategory, places: [Place])] {
        let filtered = selectedCategory.map { c in store.places.filter { $0.category == c } }
            ?? store.places
        var order: [PlaceCategory] = []
        var grouped: [PlaceCategory: [Place]] = [:]
        for place in filtered {
            if grouped[place.category] == nil { order.append(place.category) }
            grouped[place.category, default: []].append(place)
        }
        return order.map { (category: $0, places: grouped[$0] ?? []) }
    }

    private var emptyText: String {
        selectedCategory == nil
            ? "저장한 장소가 없어요"
            : "저장한 \(selectedCategory?.rawValue ?? "")이(가) 없어요"
    }

    private func message(_ text: String, isLoading: Bool) -> some View {
        VStack(spacing: 10) {
            if isLoading { ProgressView().tint(.deepGreen) }
            Text(text)
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
            if !isLoading {
                Text("장소 상세에서 저장하기를 눌러 담아 보세요")
                    .font(.notoSans(13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .combine)
    }

    private var failedRow: some View {
        VStack(spacing: 14) {
            Text("저장한 장소를 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
            Button("다시 시도") { Task { await store.load(accessFeatures: session.accessFeatures) } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 좋아요한 게시물

    /// 홈 피드와 **같은 카드**(`PostCard`)를 쓴다 — 같은 글이 자리마다 달리 보일 이유가 없다.
    ///
    /// ⚠️ 어느 상태든 남는 공간을 채워야 한다. 짧은 쪽이 내용 높이만 차지하면 바깥 `VStack` 이
    /// 짧아지고, SwiftUI 가 그 스택을 화면 가운데로 정렬하면서 **헤더까지 아래로 내려온다**
    /// (장소 후기의 "여행 게시글" 탭에서 실측한 것과 같은 함정).
    @ViewBuilder
    private var likedList: some View {
        if likedRequiresSignIn {
            SignInPromptView(
                title: "로그인하면 좋아요한 글을 볼 수 있어요",
                message: "누른 하트는 계정에 남아요. 기기를 바꿔도 그대로 따라옵니다.",
                prompt: .like
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if isLoadingLiked && !didLoadLiked {
            message("좋아요한 게시물을 불러오는 중이에요", isLoading: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if likedLoadFailed && !didLoadLiked {
            likedFailedRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if likedPosts.isEmpty {
            VStack(spacing: 10) {
                Text("좋아요한 게시물이 없어요")
                    .font(.notoSans(15, .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("마음에 드는 여행 게시글에 하트를 눌러 보세요")
                    .font(.notoSans(13))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 80)
            .accessibilityElement(children: .combine)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(likedPosts) { post in
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
            .background(Color.appBackground)
            .refreshable { await loadLiked() }
        }
    }

    private var likedFailedRow: some View {
        VStack(spacing: 14) {
            Text("좋아요한 게시물을 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
            Button("다시 시도") { Task { await loadLiked() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    /// 서버가 **내가 누른 순서**로 준다 — 앱에서 다시 줄 세우지 않는다.
    private func loadLiked() async {
        guard !isLoadingLiked else { return }
        isLoadingLiked = true
        likedLoadFailed = false
        likedRequiresSignIn = false
        do {
            likedPosts = try await postService.fetchPosts(
                mineOnly: false, likedOnly: true, contentId: nil, limit: 30, offset: 0)
            didLoadLiked = true
        } catch PostServiceError.loginRequired, PostServiceError.sessionExpired {
            // 로그아웃한 기기는 비어야 한다 — 이전 계정이 좋아요한 글이 남아 보이면 안 된다.
            likedPosts = []
            didLoadLiked = false
            likedRequiresSignIn = true
        } catch {
            // 이미 받아 둔 목록이 있으면 지우지 않는다 — 새로고침이 실패했다고
            // 보고 있던 글이 사라지면 안 된다.
            likedLoadFailed = true
        }
        isLoadingLiked = false
    }
}

#Preview {
    CollectionView()
        .environment(SavedPlacesStore(service: MockFeedService()))
        .environment(SessionStore(service: MockAuthService()))
}
