import SwiftUI

/// 장소 상세 (Figma "추천장소 B")
struct PlaceDetailView: View {
    let place: Place

    @Environment(\.feedService) private var feedService
    @Environment(SavedPlacesStore.self) private var savedStore
    @Environment(SessionStore.self) private var session
    @Environment(\.blockService) private var blockService
    @Environment(\.blockSignal) private var blockSignal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reader = SpeechReader.shared
    @State private var detail: PlaceDetail?
    @State private var isOverviewExpanded = false
    /// 사진 위 원형 뱃지 중 선택된 유형 — 선택 시에만 안내 칩을 띄운다
    @State private var selectedFeature: AccessibilityFeature?
    /// 카카오맵 엔진은 지도 영역이 화면에 나타난 뒤 활성화해야 한다
    @State private var isMapVisible = false
    /// 후기 작성 시트 (시안 미확보 — ReviewComposeView 참고)
    @State private var isComposingReview = false
    @State private var isAddingToPlan = false
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

                    // 데이터 출처. **이 화면이 원본 데이터를 가장 많이 그린다** — 이름·주소·
                    //  사진·무장애 28속성이 모두 관광공사 TourAPI 다. 라이선스가 표출 시 출처
                    //  표시를 요구하므로 데이터가 보이는 자리에 함께 둔다(설정에도 한 줄 있다).
                    Text("정보 출처: 한국관광공사 TourAPI")
                        .font(.notoSans(12, .regular, relativeTo: .caption))
                        .foregroundStyle(.iconGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                }
                .padding(.bottom, Spacing.xxl)
            }
            .background(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        // 상세·후기·추천은 서로를 기다릴 이유가 없어 별도 task로 동시에 받는다.
        .task { detail = try? await feedService.fetchPlaceDetail(contentId: place.id) }
        // 화면을 떠나면 낭독을 멈춘다. **다른 화면이 읽고 있으면 건드리지 않는다** —
        //  뒤로 갔다가 다른 장소를 열어도 앞의 소리가 이어지면 어느 글을 듣는지 알 수 없다.
        .onDisappear { reader.stop(ifReading: place.id) }
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
        .sheet(isPresented: $isAddingToPlan) {
            // `detail` 이 아니라 `place` 를 넘긴다 — `PlaceDetail` 에는 좌표가 없고,
            // 일정에 담긴 장소는 지도 핀과 구간 거리에 좌표가 필요하다.
            PlaceAddToPlanView(place: place)
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
                // 프리뷰는 거르지 않는다 — 방문 조건 필터는 전용 화면에 있다.
                contentId: place.id, sort: .latest, hasImage: false, visitorTag: nil,
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
                        // 시안 249:760 — 글머리표 없이 문장만, 15 Medium.
                        Text(note)
                            .font(.notoSans(15, .medium))
                            .tracking(-0.4)
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

    /// - Parameter diameter: 시안이 자리마다 다르다 — 사진 위는 34(249:690), 추가정보는 28(249:804).
    private func photoBadge(
        _ feature: AccessibilityFeature, style: BadgeStyle = .filled, diameter: CGFloat = 34
    ) -> some View {
        let iconSize = feature.iconSize(inBadgeDiameter: diameter)
        return Circle()
            .fill(style == .filled ? Color.deepGreen : .white)
            .frame(width: diameter, height: diameter)
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
            // 저장은 앱 전체가 함께 보는 상태다 — 저장 탭이 곧바로 반영한다(`SavedPlacesStore`).
            actionButton(
                title: savedStore.isSaved(place.id) ? "저장됨" : "저장하기",
                icon: "detail_bookmark",
                isOn: savedStore.isSaved(place.id)
            ) {
                // 저장·일정·후기는 모두 로그인 필수다(백엔드 030). 들어가는 문에서 묻는다 —
                //  다 쓰고 나서 401 을 만나면 쓴 것을 잃을까 불안해진다.
                guard session.requireSignIn(.save) else { return }
                Task { await toggleSaved() }
            }
            .disabled(savedStore.isPending(place.id))
            actionButton(title: "일정추가", icon: "detail_plus") {
                guard session.requireSignIn(.plan) else { return }
                isAddingToPlan = true
            }
            actionButton(title: "후기쓰기", icon: "detail_pencil") {
                guard session.requireSignIn(.writeReview) else { return }
                isComposingReview = true
            }
            // 공유는 로그인이 필요 없다 — 계정 없이도 남에게 보낼 수 있어야 한다.
            //  `Button` 이 아니라 `ShareLink` 라서 라벨만 같은 모양으로 맞춘다.
            // ⚠️ `preview:` 를 두지 않는다. 넣으면 공유 시트 머리에 장소 이름이 뜨는 대신
            //  **"복사" 동작이 사라진다**(실측 — 같은 화면에서 그 한 줄만 넣고 뺐다).
            //  머리글은 꾸밈이고 복사는 기능이라, 복사를 남긴다.
            //  아이콘도 시도했다가 뺐다: 정사각으로 잘려 가로로 긴 로고는 가운데만("두오")
            //  남았고, SF 심볼은 흰 바탕에 흰색으로 사라졌다.
            ShareLink(item: shareText, subject: Text(shareTitle)) {
                actionLabel(title: "공유하기", icon: "detail_share")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    /// 저장 상태를 색만으로 알리지 않는다 — 글자가 "저장하기 → 저장됨"으로 바뀐다.
    /// 후기 좋아요 토글. 하트는 누른 즉시 반응해야 해서 화면을 먼저 바꾸고 서버에 보낸다.
    /// 성공하면 서버가 센 값으로 맞추고(그 사이 남이 눌렀을 수 있다), 실패하면 되돌린다.
    /// 후기 작성자를 차단한다. 거르는 일은 서버가 하므로 후기 목록을 다시 받는다.
    private func block(_ uuid: String) async {
        do {
            try await blockService.block(uuid: uuid)
            blockSignal.changed()
            await loadReviews(reset: true)
            UIAccessibility.post(notification: .announcement, argument: "차단했어요")
        } catch {
            UIAccessibility.post(notification: .announcement,
                                 argument: "차단하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private func toggleReviewLike(_ review: TravelReview) async {
        // 번들·목 후기는 서버 id 가 없어 좋아요를 붙일 수 없다.
        guard let serverId = review.serverId else { return }
        // 좋아요는 로그인 필수(백엔드 038). 비로그인이면 로그인 시트를 띄우고 멈춘다.
        guard session.requireSignIn(.like) else { return }
        guard let idx = reviews.firstIndex(where: { $0.id == review.id }) else { return }

        let before = reviews[idx]
        reviews[idx].likedByMe = !before.likedByMe
        reviews[idx].likeCount = max(0, before.likeCount + (before.likedByMe ? -1 : 1))

        do {
            let result = try await feedService.setReviewLiked(reviewId: serverId, !before.likedByMe)
            if let i = reviews.firstIndex(where: { $0.id == review.id }) {
                reviews[i].likeCount = result.likeCount
                reviews[i].likedByMe = result.likedByMe
            }
        } catch {
            if let i = reviews.firstIndex(where: { $0.id == review.id }) { reviews[i] = before }
        }
    }

    private func toggleSaved() async {
        let nowSaved = await savedStore.toggle(place)
        UIAccessibility.post(
            notification: .announcement,
            argument: nowSaved ? "저장했어요" : "저장을 해제했어요")
    }

    private func actionButton(
        title: String, icon: String? = nil, systemIcon: String? = nil,
        isOn: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(title: title, icon: icon, systemIcon: systemIcon, isOn: isOn)
        }
        .buttonStyle(.plain)
    }

    /// 다섯 버튼의 겉모습(시안 249:770 — 셀 88×67, 아이콘 22, 라벨 13).
    /// 공유만 `ShareLink` 라서 라벨을 따로 뽑아 둔다 — 모양을 두 번 적으면 한쪽만 바뀐다.
    ///
    /// `systemIcon` 은 시안 에셋이 아직 없는 읽어주기용이다. 22pt 로 맞춰 다른 넷과 같은
    /// 자리에 서게 한다.
    private func actionLabel(
        title: String, icon: String? = nil, systemIcon: String? = nil, isOn: Bool = false
    ) -> some View {
        VStack(spacing: 3) {
            Group {
                if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .resizable()
                        .scaledToFit()
                }
            }
                .frame(width: 22, height: 22)
                .foregroundStyle(.deepGreen)
                // 켜진 상태를 글자만으로 두지 않는다 — 아이콘도 함께 진해진다.
                .opacity(isOn ? 1 : 0.65)
            // 시안 249:773 — 13 Medium, 자간 -0.4. 켜진 상태만 굵게 한다.
            Text(title)
                .font(.notoSans(13, isOn ? .bold : .medium))
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().stroke(Color.cardStroke, lineWidth: 1))
    }

    /// 메일 제목처럼 **제목 자리가 따로 있는 앱**이 쓰는 이름(`subject`).
    /// 상세를 아직 못 받았어도 목록에서 넘어온 이름이 있다.
    private var shareTitle: String { detail?.name ?? place.name }

    /// 보낼 글.
    ///
    /// 링크는 **우리 앱 링크**다(`PlaceLink`) — 앱이 깔려 있으면 이 화면으로 곧장 열린다.
    /// contentId 만 있으면 만들 수 있어서 상세가 오기 전에 눌러도 링크는 온전하다.
    /// 관광공사 contentId 가 아닌 곳(번들·목 데이터)만 카카오맵 링크로 물러난다.
    private var shareText: String {
        PlaceShareText.make(
            name: shareTitle,
            address: detail?.address ?? place.region,
            features: detail?.accessibilityFeatures ?? [place.feature],
            url: PlaceLink.url(contentId: place.id) ?? detail?.kakaoMapURL
        )
    }

    // MARK: - 읽어주기

    /// 시안이 정한 자리 — **섹션 제목 오른쪽의 헤드폰**(1081:208 기본정보 / 1081:217 추가정보).
    ///
    /// 화면 전체를 읽지 않고 **그 섹션만** 읽는다. iOS 의 "화면 읽어주기"는 탭 바와 버튼
    /// 라벨까지 순서대로 훑지만, 여기서는 사용자가 지금 보고 있는 덩어리 하나만 들려준다.
    /// 보이는 버튼이라야 닿는다 — 이 기능이 겨냥하는 사람(VoiceOver 를 켜지 않는 저시력·
    /// 고령·난독 사용자)은 두 손가락 제스처를 모른다.
    private enum SpeechSection: String {
        case info, access
        var title: String { self == .info ? "기본정보" : "추가정보" }
    }

    private func speechID(_ section: SpeechSection) -> String { "\(place.id)#\(section.rawValue)" }

    /// 기본정보에서 읽을 줄들.
    ///
    /// ⚠️ 홈페이지처럼 **주소를 값으로 가진 줄은 빈 문자열로 둔다** — 소리로 읽으면
    /// "에이치티티피 콜론 슬래시 슬래시…" 가 된다. 낭독기가 빈 조각을 건너뛰면서도
    /// 번호는 그대로 두므로(`SpeechReader.utterances`), 아래 강조가 줄과 어긋나지 않는다.
    private var infoSpeech: [String] {
        (detail?.info ?? []).map { $0.isLink ? "" : "\($0.label). \($0.value)" }
    }

    /// 추가정보에서 읽을 줄들 — 무장애 안내 문장 그대로, 주의 태그는 마지막 한 줄로.
    private var accessSpeech: [String] {
        var lines = detail?.accessibilityNotes ?? []
        if let tags = detail?.cautionTags, !tags.isEmpty {
            lines.append("주의. " + tags.joined(separator: ", "))
        }
        return lines
    }

    /// 지금 읽고 있는 줄인가. 글자 단위가 아니라 **줄 단위로 짚는다** —
    /// 섹션의 각 줄이 조각 하나라서 이 편이 눈으로 따라가기 쉽다.
    private func isSpeaking(_ section: SpeechSection, line index: Int) -> Bool {
        reader.isReading(speechID(section)) && reader.segment == index
    }

    /// 섹션 제목 + 읽어주기(시안 26×26 프레임에 22×22 아이콘).
    ///
    /// 읽는 중에는 딥그린 원을 채우고 아이콘을 희게 뒤집는다 — 시안에 "읽는 중" 상태가
    /// 없어서, 같은 화면의 추가정보 뱃지(딥그린 원 + 흰 픽토그램)와 같은 말을 쓴다.
    private func sectionHeader(_ section: SpeechSection, segments: [String]) -> some View {
        let id = speechID(section)
        let isReading = reader.isReading(id)
        return HStack(spacing: 8) {
            Text(section.title)
                .font(.sectionTitle)
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if !segments.contains(where: { !$0.isEmpty }) {
                EmptyView()
            } else {
                Button {
                    reader.toggle(segments, id: id)
                } label: {
                    Image("detail_tts")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(isReading ? .white : .textPrimary)
                        .frame(width: 26, height: 26)
                        .background {
                            if isReading { Circle().fill(Color.deepGreen) }
                        }
                        // 26pt 글리프는 44pt 터치 영역에 못 미친다 — 영역만 넓힌다.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isReading ? "읽기 멈추기" : "\(section.title) 읽어주기")
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - 이름·주소·별점

    private var titleRow: some View {
        // Figma "추천장소": 이름 아래로 주소가 오는 세로 배치 (이전엔 이름 오른쪽 가로 배치였음)
        VStack(alignment: .leading, spacing: 8) {
            // 시안 249:688 — 24 Bold, 자간 -0.4.
            Text(detail?.name ?? place.name)
                .font(.notoSans(24, .bold))
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(detail?.address ?? place.region)
                .font(.notoSans(14))
                .tracking(-0.4)
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
                // 시안 lineHeight 23 (14pt 본문). 5 는 그보다 성겼다.
                lineSpacing: 3,
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
            sectionHeader(.info, segments: infoSpeech)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array((detail?.info ?? []).enumerated()), id: \.element.id) { index, row in
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
                    .speakingLine(isSpeaking(.info, line: index))
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
            sectionHeader(.access, segments: accessSpeech)

            HStack(spacing: 9) {
                ForEach(detail?.accessibilityFeatures ?? [], id: \.self) { feature in
                    photoBadge(feature, diameter: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 시안 249:810 — 15 Regular, 보조색(#4D4D4D), lineHeight 26.
                ForEach(Array((detail?.accessibilityNotes ?? []).enumerated()), id: \.element) { index, note in
                    Text("•  \(note)")
                        .font(.notoSans(15))
                        .tracking(-0.4)
                        .foregroundStyle(.textSecondary)
                        .lineSpacing(4)
                        .speakingLine(isSpeaking(.access, line: index))
                }
            }

            if let tags = detail?.cautionTags, !tags.isEmpty {
                HStack(spacing: 10) {
                    // 시안 249:756 — 채움이 아니라 **테두리**다(딥그린 보더 + 딥그린 글자).
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.notoSans(14, .semiBold))
                            .tracking(-0.4)
                            .foregroundStyle(.deepGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().stroke(Color.deepGreen, lineWidth: 1))
                    }
                }
                .padding(.top, 8)
                .speakingLine(isSpeaking(.access, line: (detail?.accessibilityNotes ?? []).count))
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
            // 별을 눌러 들어오는 길도 로그인 필수다. 별점은 되돌려 둔다 —
            //  로그인하고 돌아왔을 때 누른 적 없는 별이 남아 있으면 안 된다.
            guard session.requireSignIn(.writeReview) else {
                entryRating = 0
                return
            }
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
                            PlaceReviewRow(
                                onBlock: { uuid in Task { await block(uuid) } },
                                review: review
                            ) {
                                Task { await toggleReviewLike(review) }
                            }
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
    .environment(SavedPlacesStore(service: MockFeedService()))
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("후기 없는 장소") {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
            .environment(\.feedService, EmptyReviewPreviewService())
    }
    .environment(SavedPlacesStore(service: MockFeedService()))
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("큰 글자 (AX3)") {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(SavedPlacesStore(service: MockFeedService()))
    .environment(SessionStore(service: MockAuthService()))
}

/// 프리뷰 전용 — 상세는 목 그대로 두고 후기·추천만 비운다.
/// (프로덕션 리뷰가 7건뿐이라 대부분의 장소가 실제로 이 상태다)
private struct EmptyReviewPreviewService: FeedService {
    private let base = MockFeedService()


    func fetchRecommendedPlaces(
        category: PlaceCategory, page: Int, accessFeatures: [AccessibilityFeature]
    ) async throws -> [Place] {
        try await base.fetchRecommendedPlaces(
            category: category, page: page, accessFeatures: accessFeatures)
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

/// 지금 소리로 읽고 있는 줄을 짚어 준다.
///
/// 글자 단위가 아니라 **줄 단위**다 — 섹션의 각 줄이 낭독 조각 하나라서, 눈으로 따라가기에는
/// 이 편이 낫다. 색만으로 알리지 않도록 배경과 함께 좌우 여백을 줘 자리 자체가 움직여 보인다.
private extension View {
    @ViewBuilder
    func speakingLine(_ isOn: Bool) -> some View {
        if isOn {
            padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.moduwaGreen.opacity(0.35)))
                .padding(.horizontal, -6)
                .padding(.vertical, -2)
        } else {
            self
        }
    }
}
