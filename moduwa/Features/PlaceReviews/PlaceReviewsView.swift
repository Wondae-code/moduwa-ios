import SwiftUI

/// 장소 후기 전용 화면 (손그림 기획 스케치 기준 — **피그마 시안 없음**).
///
/// 장소 상세의 "후기 N ›"에서 들어온다. 상세에는 후기 프리뷰가 그대로 남고, 이 화면이
/// 정렬·필터·태그 집계·전체 목록을 담당한다.
///
/// 스케치에 픽셀 규격이 없어 장소 상세(`PlaceDetailView`)의 톤을 그대로 따랐다:
/// 좌우 마진 24, 풀블리드 구분선, 섹션 제목 `.sectionTitle`, 라임 CTA.
/// 시안이 오면 탭 인디케이터 형태·집계 막대 높이·필터 행 배치가 바뀔 수 있다.
struct PlaceReviewsView: View {
    let contentId: String
    let placeName: String
    /// 후기 작성 시트에 넘길 주소 (장소 상세가 이미 받아 둔 값)
    var placeAddress: String = ""

    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedTab: Tab = .reviews

    @State private var summary: PlaceReviewSummary?
    @State private var reviews: [TravelReview] = []
    /// 다음에 받을 페이지 번호 (0부터)
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var loadFailed = false
    /// 겹친 요청 중 마지막 것만 화면에 반영하기 위한 세대 번호
    @State private var loadGeneration = 0

    @State private var sort: PlaceReviewSort = .likes
    @State private var showsPhotoReviewsOnly = false

    /// "방문 후기를 남겨주세요!"에서 고른 별점 — 작성 시트의 초기값
    @State private var entryRating = 0
    @State private var isComposingReview = false
    /// 헤더 ☰ — 대응 기능이 없어 "준비 중" popover만 띄운다
    @State private var showsMenuNotice = false

    private enum Tab: String, CaseIterable, Hashable {
        case reviews = "방문 후기"
        case posts = "여행 게시글"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabBar

            switch selectedTab {
            case .reviews: reviewsTab
            case .posts: postsTab
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load(reset: true) }
        .sheet(isPresented: $isComposingReview, onDismiss: { entryRating = 0 }) {
            ReviewComposeView(
                placeName: placeName,
                placeAddress: placeAddress,
                contentId: contentId,
                initialRating: entryRating,
                // 서버 등록이 성공한 뒤에만 불린다 — 집계·목록을 처음부터 다시 받는다
                onSubmit: { _ in Task { await load(reset: true, refreshSummary: true) } }
            )
        }
    }

    // MARK: - 헤더 (← 장소 후기 ☰)

    private var headerBar: some View {
        // 장소 상세 헤더와 같은 규격 (마진 28/27, 세로 10, 하단 1pt 선)
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("장소 후기")
                .font(.notoSans(20, .bold))
                .padding(.leading, 12)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // 장소 상세는 이 자리를 빈 버튼으로 두었지만, 눌러도 아무 일이 없으면 고장으로 읽힌다.
            // 후기 행의 팔로우·더보기와 같은 방식(기본 popover)으로 준비 중임을 말해 준다.
            Button { showsMenuNotice = true } label: {
                Image("hamburger")
                    .renderingMode(.template)
                    .frame(width: 26, height: 26)
            }
            .accessibilityLabel("메뉴")
            .popover(isPresented: $showsMenuNotice) {
                Text("메뉴는 아직 준비 중이에요")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Color.textPrimary)
                    .padding(16)
                    // 없으면 iPhone(compact)에서 popover가 시트로 바뀐다
                    .presentationCompactAdaptation(.popover)
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.leading, 28)
        .padding(.trailing, 27)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 탭 (방문 후기 / 여행 게시글)

    /// 규격·접근성 처리는 `UnderlineTabBar` 로 옮겼다 — 일정 탭 세그먼트가 같은 모양이라
    /// 값을 베끼는 대신 같은 뷰를 쓴다.
    private var tabBar: some View {
        UnderlineTabBar(tabs: Tab.allCases, selection: $selectedTab)
    }

    // MARK: - 탭 A: 방문 후기

    private var reviewsTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                writePrompt
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                fullWidthDivider.padding(.top, 24)

                summaryRow
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                if let tags = summary?.tags, !tags.isEmpty {
                    tagBars(tags)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                }

                fullWidthDivider.padding(.top, 24)

                filterRow
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                reviewList
                    .padding(.top, 20)
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    /// 별점을 고르면 그 점수를 초기값으로 작성 시트를 연다 (장소 상세의 진입 섹션과 같은 규칙).
    private var writePrompt: some View {
        VStack(spacing: 8) {
            Text("방문 후기를 남겨주세요!")
                .font(.notoSans(16))
                .foregroundStyle(.textSecondary)
                .accessibilityAddTraits(.isHeader)

            // 장소 상세와 같은 컨트롤 — 별점 조작·낭독 규칙(단일 조절 요소)이 두 곳에서 같아야 한다
            StarRatingInput(rating: $entryRating)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: entryRating) { _, newValue in
            // 시트를 닫을 때 0으로 되돌리므로 0은 무시한다 (되돌림이 시트를 다시 열지 않게)
            guard newValue > 0 else { return }
            isComposingReview = true
        }
    }

    /// `4.7 ★★★★★` (좌) … `후기 118` (우)
    @ViewBuilder
    private var summaryRow: some View {
        let rating = ratingLine
        let count = Text("후기 \(reviewCount)")
            .font(.notoSans(14, .medium))
            .foregroundStyle(.textPrimary)
            .fixedSize()
            .accessibilityLabel("후기 \(reviewCount)개")

        if dynamicTypeSize.isAccessibilitySize {
            // 큰 글자에서 한 줄에 두면 "4.7"이 폭 0으로 눌려 사라진다
            VStack(alignment: .leading, spacing: 10) {
                rating
                count
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                rating
                Spacer(minLength: 12)
                count
            }
        }
    }

    private var ratingLine: some View {
        HStack(spacing: 5) {
            if let average = summary?.averageRating {
                Text(average, format: .number.precision(.fractionLength(1)))
                    .font(.notoSans(16, .bold))
                    .foregroundStyle(.textPrimary)
                    .fixedSize()
                StarRatingDisplay(rating: average, isAccessible: false)
            } else {
                // 후기는 있어도 아무도 별점을 남기지 않은 경우 — 평균을 0점으로 꾸미지 않는다
                Text("별점 없음")
                    .font(.notoSans(14, .medium))
                    .foregroundStyle(.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            summary?.averageRating.map {
                "평균 별점 5점 중 \($0.formatted(.number.precision(.fractionLength(1))))점, 별점을 남긴 후기 \(summary?.ratedCount ?? 0)개"
            } ?? "아직 별점을 남긴 후기가 없어요"
        )
    }

    /// 태그 집계 막대. "N명 이상만" 같은 임계값은 두지 않는다 —
    /// 시연 데이터가 태그당 1~2명이라 걸러 내면 화면이 통째로 빈다.
    private func tagBars(_ tags: [ReviewTagCount]) -> some View {
        // 서버가 인원 많은 순으로 정렬해 주므로 첫 항목이 분모다
        let maxCount = tags.map(\.count).max() ?? 1
        return VStack(spacing: 14) {
            ForEach(tags) { ReviewTagCountBar(item: $0, maxCount: maxCount) }
        }
    }

    // MARK: - 정렬 · 필터

    @ViewBuilder
    private var filterRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // 큰 글자에서 나란히 두면 둘 다 두 줄로 접히며 겹친다
            VStack(alignment: .leading, spacing: 12) {
                sortMenu
                photoOnlyToggle
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 12) {
                sortMenu
                Spacer(minLength: 8)
                photoOnlyToggle
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            // Picker로 두면 선택된 항목에 시스템 체크가 붙어 상태가 색 말고도 전달된다
            Picker("정렬", selection: $sort) {
                ForEach(PlaceReviewSort.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sort.rawValue)
                    .font(.notoSans(14, .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .accessibilityLabel("정렬")
        .accessibilityValue(sort.rawValue)
        .onChange(of: sort) { Task { await load(reset: true) } }
    }

    /// "사진/영상 후기만 보기". 스케치의 `∨` 표시를 체크박스로 읽어 형태로 상태를 전달한다
    /// (라임 배경만 바꾸면 색각 이상 환경에서 켜졌는지 알 수 없다).
    private var photoOnlyToggle: some View {
        Button {
            showsPhotoReviewsOnly.toggle()
            Task { await load(reset: true) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsPhotoReviewsOnly ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(showsPhotoReviewsOnly ? .deepGreen : .iconGray)
                Text("사진/영상 후기만 보기")
                    .font(.notoSans(14, showsPhotoReviewsOnly ? .bold : .medium))
                    .foregroundStyle(showsPhotoReviewsOnly ? .textPrimary : .textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진/영상 후기만 보기")
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(showsPhotoReviewsOnly ? "켜짐" : "꺼짐")
    }

    // MARK: - 후기 목록

    @ViewBuilder
    private var reviewList: some View {
        if isLoading && reviews.isEmpty {
            loadingRow.padding(.horizontal, 24)
        } else if loadFailed && reviews.isEmpty {
            errorRow.padding(.horizontal, 24)
        } else if reviews.isEmpty {
            emptyRow.padding(.horizontal, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                    if index > 0 {
                        // 후기 사이 경계 — 목록이 길어 간격만으로는 어디서 끊기는지 읽히지 않는다
                        Rectangle()
                            .fill(Color.cardStroke)
                            .frame(height: 1)
                            .padding(.vertical, 20)
                            .accessibilityHidden(true)
                    }
                    // 팔로우·더보기는 백엔드에 대응 기능이 없다 — 눌리되 "준비 중"을 알린다
                    PlaceReviewRow(review: review, showsAllPhotos: true, showsActionNotices: true)
                }
            }
            .padding(.horizontal, 24)

            if hasMore {
                LoadMoreButton(title: "후기 더보기") {
                    Task { await load(reset: false) }
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .disabled(isLoading)
            }
        }
    }

    // MARK: - 탭 B: 여행 게시글 (미구현)

    /// 서버에 게시글 개념이 없다 — 자리만 잡아 둔다.
    private var postsTab: some View {
        ComingSoonView(
            title: "여행 게시글",
            systemImage: "text.below.photo",
            message: "이 장소를 다룬 여행 게시글을 모아 보여줄 예정이에요"
        )
    }

    // MARK: - 상태 표시

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.deepGreen)
            Text("후기를 불러오는 중이에요")
                .font(.notoSans(14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 스피너만으로는 스크린리더에 아무것도 전달되지 않는다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("후기를 불러오는 중이에요")
    }

    private var errorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("후기를 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("네트워크 상태를 확인하고 다시 시도해 주세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
            Button {
                Task { await load(reset: true) }
            } label: {
                Text("다시 시도")
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("후기 다시 불러오기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 필터 때문에 비었는지, 후기가 아예 없는지를 구분해 알린다 —
    /// 같은 문구를 쓰면 사용자가 필터를 껐다 켜 볼 이유를 못 찾는다.
    private var emptyRow: some View {
        VStack(spacing: 6) {
            Text(showsPhotoReviewsOnly ? "사진이 있는 후기가 없어요" : "아직 후기가 없어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text(showsPhotoReviewsOnly ? "필터를 끄면 모든 후기를 볼 수 있어요" : "이 장소의 첫 후기를 남겨보세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    private var fullWidthDivider: some View {
        Rectangle()
            .fill(Color.cardStroke)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    // MARK: - 로딩

    private var reviewCount: Int { summary?.reviewCount ?? reviews.count }

    /// - Parameters:
    ///   - reset: 목록을 처음부터 다시 받는다 (정렬·필터 변경, 후기 등록 후)
    ///   - refreshSummary: 집계(평점·후기 수·태그)까지 다시 받는다.
    ///     집계는 정렬·필터와 무관하므로 필터를 껐다 켤 때는 다시 받지 않고,
    ///     **후기를 등록한 뒤에는 반드시 받는다** — 안 받으면 방금 쓴 후기가 개수에 빠진다.
    private func load(reset: Bool, refreshSummary: Bool = false) async {
        if reset {
            page = 0
        } else if isLoading {
            return   // 더보기 연타 방지 (정렬·필터 변경은 진행 중이어도 최신 조건이 이겨야 한다)
        }
        // 정렬을 바꾸고 곧바로 필터를 켜면 요청 두 개가 겹친다. 먼저 보낸 응답이 늦게 도착해
        // 최신 조건의 목록을 덮어쓰지 않도록 세대 번호로 걸러 낸다.
        loadGeneration += 1
        let generation = loadGeneration

        isLoading = true
        loadFailed = false

        let requestedSort = sort
        let requestedHasImage = showsPhotoReviewsOnly
        do {
            if refreshSummary || summary == nil {
                let received = try await feedService.fetchReviewSummary(contentId: contentId)
                guard generation == loadGeneration else { return }
                summary = received
            }
            let received = try await feedService.fetchPlaceReviews(
                contentId: contentId,
                sort: requestedSort,
                hasImage: requestedHasImage,
                page: page,
                pageSize: FeedPage.placeReviewListSize
            )
            guard generation == loadGeneration else { return }
            reviews = reset ? received : reviews + received
            hasMore = received.count == FeedPage.placeReviewListSize
            page += 1
        } catch {
            guard generation == loadGeneration else { return }
            loadFailed = true
        }
        isLoading = false
    }
}

#Preview("목 데이터") {
    NavigationStack {
        PlaceReviewsView(
            contentId: "264337",
            placeName: "불국사",
            placeAddress: "경북 경주시 불국로 385"
        )
    }
}

#Preview("후기 없는 장소") {
    NavigationStack {
        PlaceReviewsView(contentId: "126508", placeName: "국립중앙박물관")
            .environment(\.feedService, EmptyPlaceReviewsPreviewService())
    }
}

#Preview("큰 글자 (AX3)") {
    NavigationStack {
        PlaceReviewsView(contentId: "264337", placeName: "불국사")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

/// 프리뷰 전용 — 후기가 0건인 장소 (프로덕션 후기가 8건뿐이라 대부분의 장소가 실제로 이 상태다).
/// 나머지는 프로토콜 기본 구현 = "이 소스에는 데이터 없음".
private struct EmptyPlaceReviewsPreviewService: FeedService {
    private let base = MockFeedService()

    func fetchHeroRecommendation() async throws -> HeroRecommendation {
        try await base.fetchHeroRecommendation()
    }

    func fetchRecommendedPlaces(category: PlaceCategory, page: Int) async throws -> [Place] {
        try await base.fetchRecommendedPlaces(category: category, page: page)
    }

    func fetchReviews(sort: ReviewSort, page: Int) async throws -> [TravelReview] {
        try await base.fetchReviews(sort: sort, page: page)
    }

    func fetchPlaceDetail(contentId: String) async throws -> PlaceDetail {
        try await base.fetchPlaceDetail(contentId: contentId)
    }

    func fetchReviewTags() async throws -> [ReviewTag] {
        MockFeedService.tagPool
    }
}
