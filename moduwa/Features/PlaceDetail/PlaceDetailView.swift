import SwiftUI

/// 장소 상세 (Figma "추천장소 B")
struct PlaceDetailView: View {
    let place: Place

    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var detail: PlaceDetail?
    @State private var isOverviewExpanded = false
    /// 사진 위 원형 뱃지 중 선택된 유형 — 선택 시에만 안내 칩을 띄운다
    @State private var selectedFeature: AccessibilityFeature?
    /// 카카오맵 엔진은 지도 영역이 화면에 나타난 뒤 활성화해야 한다
    @State private var isMapVisible = false
    /// 후기 작성 시트 (시안 미확보 — ReviewComposeView 참고)
    @State private var isComposingReview = false
    /// 헤더 ☰ 의 "준비 중" 안내 popover
    @State private var showsMenuNotice = false

    /// 후기 집계 (평점·후기 수). 무장애 상세와 다른 엔드포인트라 따로 받는다.
    @State private var summary: PlaceReviewSummary?
    @State private var reviews: [TravelReview] = []
    /// 다음에 받을 페이지 번호 (0부터)
    @State private var reviewPage = 0
    @State private var isLoadingReviews = false
    @State private var reviewLoadFailed = false
    @State private var relatedPlaces: [RelatedPlace] = []
    /// "방문 후기를 남겨주세요!"에서 고른 별점 — 작성 시트의 초기값으로 넘긴다
    @State private var entryRating = 0

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 0) {
                    photoSection
                    actionButtons

                    VStack(alignment: .leading, spacing: 0) {
                        titleRow
                            .padding(.top, 22)
                        ratingRow
                            .padding(.top, 8)
                        overviewSection
                    }
                    .padding(.horizontal, 24)

                    if let info = detail?.info, !info.isEmpty {
                        sectionDivider
                        basicInfoSection
                            .padding(.horizontal, 24)
                    }

                    sectionDivider
                    mapSection
                    sectionDivider
                    extraInfoSection
                        .padding(.horizontal, 24)

                    // 이하 시안 하단 3섹션 (333:1495 / 333:1323 / 352:48+352:54)
                    sectionDivider
                    reviewEntrySection
                        .padding(.horizontal, 24)

                    sectionDivider
                    reviewSection

                    if !relatedPlaces.isEmpty {
                        sectionDivider
                        relatedSection
                    }
                }
                .padding(.bottom, Spacing.xxl)
            }
            .background(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        // 상세·후기·추천은 서로를 기다릴 이유가 없어 별도 task로 동시에 받는다.
        .task { detail = try? await feedService.fetchPlaceDetail(contentId: place.id) }
        .task { await loadReviews(reset: true) }
        .task {
            relatedPlaces = (try? await feedService.fetchRelatedPlaces(contentId: place.id, limit: 10)) ?? []
        }
        .sheet(isPresented: $isComposingReview, onDismiss: { entryRating = 0 }) {
            ReviewComposeView(
                placeName: detail?.name ?? place.name,
                placeAddress: detail?.address ?? place.region,
                contentId: place.id,
                initialRating: entryRating,
                // 등록이 서버에서 성공한 뒤에만 불린다 — 집계·목록을 처음부터 다시 받는다
                onSubmit: { _ in Task { await loadReviews(reset: true) } }
            )
        }
    }

    // MARK: - 후기 로딩

    private func loadReviews(reset: Bool) async {
        guard !isLoadingReviews else { return }
        isLoadingReviews = true
        reviewLoadFailed = false
        if reset { reviewPage = 0 }

        do {
            if reset {
                summary = try await feedService.fetchReviewSummary(contentId: place.id)
            }
            // 장소 상세 프리뷰는 최신 방문 후기가 먼저 보이는 게 유용하다 (정렬 토글은 전용 화면에 있다)
            let page = try await feedService.fetchPlaceReviews(
                contentId: place.id, sort: .latest, hasImage: false,
                page: reviewPage, pageSize: FeedPage.placeReviewSize
            )
            reviews = reset ? page : reviews + page
            reviewPage += 1
        } catch {
            reviewLoadFailed = true
        }
        isLoadingReviews = false
    }

    /// 평점·후기 수의 원본은 집계 엔드포인트다. 아직 도착하지 않았을 때만
    /// `PlaceDetail`의 값(목·프리뷰용)으로 대신한다.
    private var averageRating: Double? {
        if let summary { return summary.averageRating }
        return detail?.rating
    }

    private var reviewCount: Int {
        if let summary { return summary.reviewCount }
        return detail?.reviewCount ?? 0
    }

    // MARK: - 헤더 (뒤로가기 + 타이틀 + 지도/메뉴)

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("장소 상세")
                .font(.notoSans(20, .bold))
                .padding(.leading, 12)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if let url = detail?.kakaoMapURL { openURL(url) }
                } label: {
                    Image("detail_map")
                        .renderingMode(.template)
                        .frame(width: 26, height: 26)
                }
                .accessibilityLabel("지도에서 보기")

                // 눌러도 아무 일이 없으면 고장으로 읽힌다 — 장소 후기 화면의 ☰·팔로우와
                // 같은 방식(기본 popover)으로 준비 중임을 말해 준다.
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

    // MARK: - 사진 (+ 접근성 뱃지, 안내 칩)

    private var photoSection: some View {
        Color.clear
            .frame(height: 227)
            .overlay {
                if let imageURL = detail?.imageURL ?? place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        PhotoPlaceholder()
                    }
                } else {
                    PhotoPlaceholder()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 10) {
                    // 선택된 뱃지의 안내만 칩으로 표시
                    if let group = detail?.accessibilityGroups.first(where: { $0.feature == selectedFeature }),
                       let note = group.notes.first {
                        Text("• \(note)")
                            .font(.notoSans(15, .medium))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.85)))
                            .transition(.opacity)
                    }
                    HStack(spacing: 9) {
                        ForEach(detail?.accessibilityFeatures ?? [], id: \.self) { feature in
                            photoBadgeButton(feature)
                        }
                    }
                }
                .padding(.trailing, 26)
                .padding(.bottom, 15)
            }
    }

    /// 사진 위 원형 접근성 뱃지 버튼 — 탭하면 해당 유형의 안내 칩을 토글한다
    private func photoBadgeButton(_ feature: AccessibilityFeature) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFeature = selectedFeature == feature ? nil : feature
            }
        } label: {
            // 사진 위 뱃지는 흰 배경 + 딥그린 아이콘 (Figma "추천장소 A/B")
            photoBadge(feature, style: .inverted)
                .overlay(
                    Circle().stroke(selectedFeature == feature ? Color.moduwaGreen : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("접근성: \(feature.label)")
        .accessibilityHint("안내 보기")
        .accessibilityAddTraits(selectedFeature == feature ? .isSelected : [])
    }

    /// 원형 접근성 뱃지 (34pt)
    /// - `.filled`: 딥그린 원 + 흰 아이콘 (추가정보 섹션)
    /// - `.inverted`: 흰 원 + 딥그린 아이콘 (사진 위 — 사진과 대비 위해 옅은 그림자)
    private enum BadgeStyle { case filled, inverted }

    private func photoBadge(_ feature: AccessibilityFeature, style: BadgeStyle = .filled) -> some View {
        let iconSize = feature.iconSize(inBadgeDiameter: 34)
        return Circle()
            .fill(style == .filled ? Color.deepGreen : .white)
            .frame(width: 34, height: 34)
            .overlay {
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize.width, height: iconSize.height)
                    .foregroundStyle(style == .filled ? Color.white : .deepGreen)
            }
            .shadow(color: style == .inverted ? .black.opacity(0.15) : .clear, radius: 2.5, y: 1)
            .accessibilityLabel(feature.label)
    }

    // MARK: - 액션 버튼 (저장·일정추가·후기쓰기·공유)

    private var actionButtons: some View {
        // 버튼을 4등분 균등 폭으로 채워 좌우 여백을 다른 섹션과 같은 24로 고정한다.
        // (intrinsic 폭 + 가운데 정렬이면 여백이 글자 크기/기기에 따라 달라진다)
        HStack(spacing: 0) {
            actionButton(title: "저장하기", icon: "detail_bookmark") {}
            actionButton(title: "일정추가", icon: "detail_plus") {}
            actionButton(title: "후기쓰기", icon: "detail_pencil") { isComposingReview = true }
            actionButton(title: "공유하기", icon: "detail_share") {}
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.deepGreen)
                Text(title)
                    .font(.notoSans(13, .semiBold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 이름·주소·별점

    private var titleRow: some View {
        // Figma "추천장소": 이름 아래로 주소가 오는 세로 배치 (이전엔 이름 오른쪽 가로 배치였음)
        VStack(alignment: .leading, spacing: 8) {
            Text(detail?.name ?? place.name)
                .font(.notoSans(22, .bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(detail?.address ?? place.region)
                .font(.notoSans(14))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var ratingRow: some View {
        if let rating = averageRating {
            HStack(spacing: 8) {
                Text(rating, format: .number.precision(.fractionLength(1)))
                    .font(.notoSans(14, .medium))
                // 채운 별/빈 별을 색이 아니라 모양으로 구분한다 (StarRatingDisplay 참고)
                StarRatingDisplay(rating: rating, isAccessible: false)
                Text("(\(reviewCount))")
                    .font(.notoSans(14))
            }
            .foregroundStyle(.textPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("평점 \(rating.formatted(.number.precision(.fractionLength(1))))점, 후기 \(reviewCount)개")
        }
    }

    // MARK: - 설명

    @ViewBuilder
    private var overviewSection: some View {
        if let overview = detail?.overview {
            // 양쪽 정렬 + 글자 단위 줄바꿈 — 줄을 꽉 채워 어간이 벌어지지 않게 한다.
            JustifiedText(
                text: overview,
                font: UIFont(name: NotoSans.regular.rawValue, size: 14) ?? .systemFont(ofSize: 14),
                textColor: UIColor(Color.textSecondary),
                lineSpacing: 5,
                lineLimit: isOverviewExpanded ? nil : 6
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 22)

            // 펼침/접힘 단일 토글 — withAnimation 밖에서 토글하고 .animation(nil)로 높이 변화 애니메이션을 차단해
            // "더 보기" 시 글자가 밀려나는 애니메이션을 없앤다.
            LoadMoreButton(
                title: isOverviewExpanded ? "설명 접기" : "설명 더보기",
                pointsUp: isOverviewExpanded
            ) {
                isOverviewExpanded.toggle()
            }
            .padding(.top, 18)
            .animation(nil, value: isOverviewExpanded)
        }
    }

    // MARK: - 기본정보

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("기본정보")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(detail?.info ?? []) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("•  \(row.label)")
                            .font(.notoSans(16, .semiBold))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 110, alignment: .leading)
                        if row.isLink, let url = URL(string: row.value) {
                            Link(row.value, destination: url)
                                .font(.notoSans(14))
                                .foregroundStyle(.deepGreen)
                                .underline()
                                .lineLimit(1)
                        } else {
                            Text(row.value)
                                .font(.notoSans(14))
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 지도

    /// 시안 420:161에서 지도가 395×180 풀블리드로 커지고, 아래 "카카오맵에서 보기" 링크(249:941)는
    /// hidden 처리됐다. 카카오맵으로 나가는 동선은 헤더의 지도 버튼이 그대로 담당하므로 링크를 없앤다.
    private var mapSection: some View {
        Group {
            if let latitude = detail?.latitude, let longitude = detail?.longitude,
               Secrets.kakaoNativeAppKey != nil {
                // 임베드 카카오맵 — 보기 전용, 제스처는 스크롤에 양보하고 조작은 카카오맵 앱으로
                KakaoMapView(latitude: latitude, longitude: longitude, draw: $isMapVisible)
                    .onAppear { isMapVisible = true }
                    .onDisappear { isMapVisible = false }
                    .allowsHitTesting(false)
                    .accessibilityLabel("\(detail?.name ?? place.name) 위치 지도")
            } else {
                Rectangle()
                    .fill(.white)
                    .overlay(
                        Text("지도")
                            .font(.notoSans(24, .bold))
                            .foregroundStyle(.textPrimary)
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipped()
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 추가정보 (접근성 뱃지·안내·주의 칩)

    private var extraInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추가정보")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 9) {
                ForEach(detail?.accessibilityFeatures ?? [], id: \.self) { feature in
                    photoBadge(feature)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail?.accessibilityNotes ?? [], id: \.self) { note in
                    Text("•  \(note)")
                        .font(.notoSans(15, .medium))
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(4)
                }
            }

            if let tags = detail?.cautionTags, !tags.isEmpty {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.notoSans(14, .semiBold))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.moduwaGreen))
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 방문 후기를 남겨주세요! (333:1495)

    /// 별점 입력이 곧 후기 작성 진입점이다. 별을 고르면 그 점수를 초기값으로 작성 시트를 연다.
    private var reviewEntrySection: some View {
        VStack(spacing: 8) {
            Text("방문 후기를 남겨주세요!")
                .font(.notoSans(16))
                .foregroundStyle(.textSecondary)
                .accessibilityAddTraits(.isHeader)

            // 작성 화면과 같은 컨트롤을 쓴다 — 별점 조작·낭독 규칙(단일 조절 요소)이 두 곳에서 같아야 한다.
            // StarRatingInput은 44pt 터치 영역을 별 오른쪽으로 넓히므로, 가운데 정렬해도
            // 시각적으로는 별 절반 간격만큼 오른쪽으로 치우친다.
            StarRatingInput(rating: $entryRating)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: entryRating) { _, newValue in
            // 시트를 닫을 때 0으로 되돌리므로 0은 무시한다 (되돌림이 시트를 다시 열지 않게)
            guard newValue > 0 else { return }
            isComposingReview = true
        }
    }

    // MARK: - Review (333:1323)

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            overallRatingBlock

            if !reviews.isEmpty {
                // 시안 352:28 — 이 구분선만 좌우 마진 없이 풀블리드다
                Rectangle()
                    .fill(Color.cardStroke)
                    .frame(height: 1)
                    .padding(.top, 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(reviews) { review in
                        NavigationLink(value: review) {
                            PlaceReviewRow(review: review)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22)
                .padding(.horizontal, 24)

                // 이 섹션은 프리뷰다 — 여기서 더 받지 않고 전용 화면으로 넘긴다.
                //  예전에는 인라인 페이징 버튼이었는데, 후기가 페이지 크기보다 적으면
                //  (예: 1건) 버튼이 아예 나타나지 않아 전용 화면으로 갈 길이 없었다.
                //  이제 후기가 하나라도 있으면 항상 보인다.
                reviewsScreenLink
                    .padding(.top, 18)
                    .padding(.horizontal, 24)
            }
        }
    }

    /// "리뷰 더 보기" — 장소 후기 전용 화면으로 이동. `LoadMoreButton`과 같은 알약 모양을 쓰되,
    /// 동작이 "더 받기"가 아니라 "화면 이동"이라 `NavigationLink`로 만든다.
    private var reviewsScreenLink: some View {
        NavigationLink {
            PlaceReviewsView(
                contentId: place.id,
                placeName: detail?.name ?? place.name,
                placeAddress: detail?.address ?? place.region
            )
        } label: {
            HStack(spacing: 5) {
                Text("리뷰 더 보기")
                    .font(.notoSans(15, .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.deepGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("리뷰 더 보기")
        .accessibilityHint("장소 후기 화면으로 이동합니다")
    }

    /// 전체 평점 (352:30) — 제목 · 평균 별점 · 후기 수 · 후기 사진 캐러셀
    private var overallRatingBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("전체 평점")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 24)

            if isLoadingReviews && summary == nil {
                loadingRow.padding(.top, 14).padding(.horizontal, 24)
            } else if reviewLoadFailed && reviews.isEmpty {
                reviewErrorRow.padding(.top, 14).padding(.horizontal, 24)
            } else if reviewCount == 0 {
                emptyReviewsRow.padding(.top, 14).padding(.horizontal, 24)
            } else {
                // 접근성 글자 크기에서 한 줄에 두면 "4.3"이 폭 0으로 눌려 사라진다 — 세로로 쌓는다.
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            ratingSummaryLine
                            reviewCountLink
                        }
                    } else {
                        HStack(alignment: .center, spacing: 8) {
                            ratingSummaryLine
                            Spacer(minLength: 12)
                            reviewCountLink
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 24)

                if !reviewPhotos.isEmpty {
                    reviewPhotoStrip.padding(.top, 21)
                }
            }
        }
    }

    @ViewBuilder
    private var ratingSummaryLine: some View {
        HStack(spacing: 5) {
            if let rating = averageRating {
                Text(rating, format: .number.precision(.fractionLength(1)))
                    .font(.notoSans(14, .medium))
                    .foregroundStyle(.textPrimary)
                    // 폭이 부족할 때 별이 아니라 점수가 먼저 눌리는 것을 막는다
                    .fixedSize()
                StarRatingDisplay(rating: rating, isAccessible: false)
            } else {
                // 후기는 있지만 아무도 별점을 남기지 않은 경우 — 평균을 0점으로 꾸미지 않는다
                Text("별점 없음")
                    .font(.notoSans(14, .medium))
                    .foregroundStyle(.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            averageRating.map {
                "평균 별점 5점 중 \($0.formatted(.number.precision(.fractionLength(1))))점, 별점을 남긴 후기 \(summary?.ratedCount ?? 0)개"
            } ?? "아직 별점을 남긴 후기가 없어요"
        )
    }

    /// "후기 235 ›" (333:1423) — 장소 후기 전용 화면(`PlaceReviewsView`)으로 이동한다.
    ///
    /// 예전에는 여기서 다음 페이지를 이어 받았다(전용 화면이 없던 임시 동작). 이제 정렬·필터·태그 집계는
    /// 전용 화면이 담당하고, 이 섹션은 프리뷰로 남는다 — 아래 "후기 더보기"가 프리뷰 안에서 더 받는 길이다.
    @ViewBuilder
    private var reviewCountLink: some View {
        let label = Text("후기 \(reviewCount)")
            .font(.notoSans(14, .medium))
            .foregroundStyle(.textPrimary)

        if reviewCount > 0 {
            NavigationLink {
                PlaceReviewsView(
                    contentId: place.id,
                    placeName: detail?.name ?? place.name,
                    placeAddress: detail?.address ?? place.region
                )
            } label: {
                HStack(spacing: 8) {
                    label
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("후기 \(reviewCount)개")
            .accessibilityHint("장소 후기 화면으로 이동합니다")
        } else {
            label.accessibilityLabel("후기 \(reviewCount)개")
        }
    }

    /// 불러온 후기들의 사진을 모아 만든 캐러셀 (333:1425, 128×128 · 컨테이너가 화면 폭을 넘어 가로 스크롤)
    private var reviewPhotos: [URL] {
        reviews.flatMap(\.imageURLs)
    }

    private var reviewPhotoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(reviewPhotos.enumerated()), id: \.offset) { index, url in
                    Color.clear
                        .frame(width: 128, height: 128)
                        .overlay {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                PhotoPlaceholder(label: "여행 사진")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                        // 사진 하나하나가 VoiceOver 정지점이어야 캐러셀을 끝까지 순회할 수 있다
                        .accessibilityElement()
                        .accessibilityLabel("후기 사진 \(index + 1), 전체 \(reviewPhotos.count)장")
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityLabel("후기 사진")
    }

    // MARK: - 후기 로딩 · 실패 · 빈 상태

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.deepGreen)
            Text("후기를 불러오는 중이에요")
                .font(.notoSans(14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 스피너만으로는 스크린리더에 아무것도 전달되지 않는다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("후기를 불러오는 중이에요")
    }

    private var reviewErrorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("후기를 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("네트워크 상태를 확인하고 다시 시도해 주세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
            Button {
                Task { await loadReviews(reset: true) }
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

    /// 시안에 빈 상태가 없다 — 시연 데이터가 7건뿐이라 대부분의 장소가 이 상태다.
    /// 리뷰 상세의 '댓글 없음'과 같은 톤으로 만들었다.
    private var emptyReviewsRow: some View {
        VStack(spacing: 6) {
            Text("아직 후기가 없어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("이 장소의 첫 후기를 남겨보세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 함께 가볼만한 곳 (352:48 + 352:54)

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("함께 가볼만한 곳")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(relatedPlaces) { related in
                        NavigationLink(value: related.place) {
                            RelatedPlaceCard(place: related)
                                // 이름이 두 줄인 카드가 섞여도 테두리 높이는 맞춘다
                                // (HStack의 fixedSize가 정한 이상 높이까지 늘어난다)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                // 카드 그림자가 스크롤 뷰 경계에서 잘리지 않게
                .padding(.vertical, 4)
            }
            .padding(.top, 16)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.cardStroke)
            .frame(height: 1)
            .padding(.vertical, 24)
            .accessibilityHidden(true)
    }
}

#Preview("목 데이터") {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .navigationDestination(for: TravelReview.self) { ReviewDetailView(review: $0) }
    }
}

#Preview("후기 없는 장소") {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
            .environment(\.feedService, EmptyReviewPreviewService())
    }
}

#Preview("큰 글자 (AX3)") {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

/// 프리뷰 전용 — 상세는 목 그대로 두고 후기·추천만 비운다.
/// (프로덕션 리뷰가 7건뿐이라 대부분의 장소가 실제로 이 상태다)
private struct EmptyReviewPreviewService: FeedService {
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
        let detail = try await base.fetchPlaceDetail(contentId: contentId)
        return PlaceDetail(
            id: detail.id, name: detail.name, address: detail.address, imageURL: detail.imageURL,
            rating: nil, reviewCount: nil, overview: detail.overview, info: detail.info,
            accessibilityGroups: detail.accessibilityGroups, cautionTags: detail.cautionTags,
            latitude: detail.latitude, longitude: detail.longitude
        )
    }
    // 나머지(집계·목록·추천)는 프로토콜 기본 구현 = "이 소스에는 데이터 없음"
}
