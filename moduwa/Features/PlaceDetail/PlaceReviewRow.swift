import SwiftUI

/// 후기 한 줄. 두 곳에서 쓴다.
///
/// 1. **장소 상세 프리뷰** (Figma 352:31) — 행 전체가 `NavigationLink`. 사진 1장을 80×80으로 곁들인다.
/// 2. **장소 후기 화면** (`PlaceReviewsView`, 손그림 스케치) — 목록이 본문이라 사진 전부를
///    가로 스크롤로 펼치고 팔로우 버튼이 실제로 동작한다.
///
/// 시안은 절대 좌표로 놓여 있어 값만 옮기면 Dynamic Type에서 겹친다. 세로 흐름
/// (프로필 → 별점·날짜·태그 → 본문 → 좋아요)으로 재구성하고, 시안의 y 간격을 spacing/padding으로 옮겼다.
struct PlaceReviewRow: View {
    /// 작성자 차단 요청. 실제 호출과 목록 갱신은 **목록을 든 화면**이 한다 — 줄마다
    /// 서비스를 붙이면 같은 요청이 화면마다 다르게 처리된다. nil 이면 차단을 두지 않는다.
    var onBlock: ((String) -> Void)? = nil

    let review: TravelReview
    /// 좋아요를 눌렀을 때. **nil 이면 표시 전용**(번들·목 후기, 또는 좋아요를 안 붙이는 화면).
    var onLike: (() -> Void)? = nil
    /// 사진을 전부 가로 스크롤로 펼친다 (전용 화면). false면 첫 장만 80×80.
    var showsAllPhotos = false
    /// 더보기(⋮)를 실제 버튼으로 둘지.
    ///
    /// **false면 아예 그리지 않는다** — 행 전체가 `NavigationLink` 인 자리(장소 상세 프리뷰)
    /// 에서 안에 버튼을 넣으면 탭이 갈라지고 VoiceOver 포커스도 쪼개진다. 그쪽에서는 상세로
    /// 들어가서 신고한다. 링크로 감싸지 않는 화면(`PlaceReviewsView`)에서만 켠다.
    var showsActionNotices = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 신고 시트. 서버 후기일 때만 열린다.
    @State private var isReporting = false

    /// 버튼이 눌릴 수 있는 화면이면 접근성 구조도 달라진다 —
    /// 행 전체를 한 요소로 묶으면 그 안의 버튼에 도달할 방법이 없다.
    private var isInteractive: Bool { showsActionNotices }

    /// 더보기(⋮)를 그릴지. **신고할 대상이 있을 때만** 그린다(후기 상세와 같은 규칙).
    /// 번들·목 후기(`serverId == nil`)에는 붙일 대상이 없다.
    ///
    /// 행 전체가 `NavigationLink` 인 자리(장소 상세 프리뷰)에서는 안에 버튼을 넣으면 탭이
    /// 갈라지고 VoiceOver 포커스도 쪼개진다 — 그쪽에서는 상세로 들어가서 신고한다.
    private var canReport: Bool { showsActionNotices && review.serverId != nil }

    var body: some View {
        if isInteractive {
            // 전용 화면: 프로필·본문·팔로우·사진이 각자 요소다. 여기서 하나로 묶으면 팔로우 버튼에
            // 도달할 방법이 사라진다.
            layout
        } else {
            // 프리뷰: 행 전체가 NavigationLink라 한 덩어리로 읽고 한 번에 상세로 들어간다.
            layout
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint("리뷰 상세 보기")
        }
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 4) {
            profileRow

            if dynamicTypeSize.isAccessibilitySize || showsAllPhotos {
                // 80pt 사진과 나란히 두면 남는 본문 폭이 한 단어도 못 담는다 — 사진을 아래로 내린다.
                // 전용 화면은 항상 이 형태다 (사진을 전부 펼치므로 옆에 붙일 수 없다).
                VStack(alignment: .leading, spacing: 10) {
                    textColumn
                    photos
                }
                .padding(.top, 4)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    textColumn
                        // 시안에서 별점 행은 프로필 아래 8, 사진은 4에서 시작한다 (VStack spacing 4 + 여기 4)
                        .padding(.top, 4)
                    photos.padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var textColumn: some View {
        let column = VStack(alignment: .leading, spacing: 10) {
            ratingDateRow
            Text(review.body)
                .font(.notoSans(16))
                .foregroundStyle(.textSecondary)
                .lineSpacing(3)
                // 프리뷰는 옆의 80pt 사진 때문에 폭이 좁아 자연히 짧게 끊기지만,
                // 전용 화면은 본문을 자르지 않는다 (여기가 후기를 끝까지 읽는 자리다).
                .frame(maxWidth: .infinity, alignment: .leading)
            likeRow
        }

        if isInteractive {
            // 별점·날짜·태그·본문·좋아요를 한 문장으로 읽는다
            // (개별 정지점으로 쪼개면 후기 한 건을 훑는 데 다섯 번 스와이프해야 한다).
            column
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(contentSummary)
        } else {
            column
        }
    }

    // MARK: - 프로필 (아바타 · 닉네임 · 레벨/리뷰수 · 팔로우 · 더보기)

    private var profileRow: some View {
        HStack(spacing: 10) {
            // 사진을 올린 작성자면 사진, 아니면 딥그린 원 + 이름 첫 글자(`AuthorAvatar`).
            AuthorAvatar(name: review.author, avatarURL: review.authorAvatarURL,
                         diameter: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(review.author)
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                if !authorMeta.isEmpty {
                    Text(authorMeta)
                        .font(.caption12)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            // 닉네임과 "Level 7 • 3개의 리뷰"는 한 사람의 정보다 — 두 정지점으로 쪼개지 않는다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(authorSummary)

            Spacer(minLength: 8)

            // ⚠️ **팔로우를 지웠다**(2026-09-07). 서버에 팔로우 개념 자체가 없어서, 누르면
            //  "준비 중" 만 뜨거나(후기 화면) **아예 눌리지도 않는 장식**이었다(장소 상세).
            //  없는 기능을 버튼 모양으로 두면 앱이 고장 난 것으로 읽힌다. 생기면 그때 넣는다.
            //
            // 더보기는 **후기 상세와 같은 규칙**이다 — 신고할 대상이 있을 때만 그린다.
            //  예전에는 대상이 없어도 ⋮ 를 그리고 "이 후기는 신고할 수 없어요" 를 눌러야
            //  알려 줬는데, 그건 누르기 전까지 알 수 없는 버튼이다.
            if canReport {
                moreButton
            }
        }
    }

    /// "Level 7 • 3개의 리뷰" — 서버 `authorInfo`가 주는 값만 조립한다 (없으면 그 조각을 뺀다)
    private var authorMeta: String {
        var parts: [String] = []
        if let level = review.authorLevel { parts.append("Level \(level)") }
        if let count = review.authorReviewCount { parts.append("\(count)개의 리뷰") }
        return parts.joined(separator: " • ")
    }

    /// 더보기 — **신고·차단**. 숨기기는 넣지 않았다: 서버에 그 개념이 없고, 앱에만 숨기면
    /// 기기를 바꾸면 되살아나 "숨겼는데 다시 보인다"가 된다.
    ///
    /// 그릴지 말지는 `canReport` 가 정한다 — 후기 상세와 같은 규칙이다.
    private var moreButton: some View {
        Menu {
            Button("신고", systemImage: "flag") { isReporting = true }
            // 작성자 식별자가 없으면(번들 후기) 차단할 대상이 없다.
            if let uuid = review.authorUUID {
                Button("차단", systemImage: "hand.raised") { onBlock?(uuid) }
            }
        } label: {
            moreDots
                // 3pt 점 세 개는 44pt 터치 영역에 한참 못 미친다
                .frame(width: 30, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("이 후기 관리")
        .sheet(isPresented: $isReporting) {
            if let serverId = review.serverId {
                ReportSheet(target: .review(id: serverId))
            }
        }
    }

    private var moreDots: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(Color.iconGray).frame(width: 3, height: 3)
            }
        }
        .frame(width: 3, height: 15)
        .accessibilityHidden(true)
    }

    // MARK: - 별점 · 날짜 · 태그

    /// 별점과 날짜, 그 뒤에 태그 뱃지. 접근성 글자 크기에서는 한 줄에 들어가지 않아 세로로 쌓는다.
    @ViewBuilder
    private var ratingDateRow: some View {
        let stars = review.rating.map {
            StarRatingDisplay(rating: Double($0), starSize: 13, spacing: 1.6, isAccessible: false)
        }
        let date = Text(Self.dateFormatter.string(from: review.createdAt))
            .font(.caption12)
            .foregroundStyle(.textSecondary)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                stars
                date
                tagBadges
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    stars
                    date
                }
                tagBadges
            }
        }
    }

    /// 태그 뱃지 줄. 여러 개면 폭이 차는 대로 다음 줄로 넘긴다.
    @ViewBuilder
    private var tagBadges: some View {
        if !review.tags.isEmpty {
            FlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
                ForEach(review.tags) { ReviewTagBadge(tag: $0) }
            }
            // 뱃지 하나하나가 정지점이면 후기마다 스와이프가 늘어난다 —
            // 상위 요약 문장이 태그를 포함하므로 여기서는 지운다.
            .accessibilityHidden(true)
        }
    }

    /// 시안(333:1431)의 "2026.05.07" 표기. 홈 피드는 상대 시간을 쓰지만 여기는 절대 날짜다.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    // MARK: - 좋아요

    /// 채움/빈 하트로 상태를 **형태로** 구분한다(색만으로 전달하지 않는다) — 게시글 카드와 같은 방식.
    /// `onLike` 가 없으면(번들·목) 탭 없이 숫자만 보여 준다.
    private var likeRow: some View {
        Button {
            onLike?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: review.likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(review.likedByMe ? .moduwaGreen : .textSecondary)
                Text("\(review.likeCount)")
                    .font(.meta13)
                    .foregroundStyle(.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onLike == nil)
        .accessibilityLabel(review.likedByMe ? "좋아요 취소" : "좋아요")
        .accessibilityValue("\(review.likeCount)개")
    }

    // MARK: - 사진

    @ViewBuilder
    private var photos: some View {
        if showsAllPhotos {
            if !review.imageURLs.isEmpty { photoStrip }
        } else if let photo = review.imageURLs.first {
            reviewPhoto(photo, size: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        }
    }

    /// 전용 화면 — 사진을 전부 가로로 펼친다. 컨테이너 마진(24)을 넘어 화면 끝까지 스크롤되게
    /// 음수 패딩으로 폭을 되돌리고 내용에만 마진을 준다 (장소 상세의 후기 사진 캐러셀과 같은 규칙).
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(review.imageURLs.enumerated()), id: \.offset) { index, url in
                    reviewPhoto(url, size: 120)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.badge))
                        // 사진 하나하나가 정지점이어야 캐러셀을 끝까지 순회할 수 있다
                        .accessibilityElement()
                        .accessibilityLabel("후기 사진 \(index + 1), 전체 \(review.imageURLs.count)장")
                }
            }
        }
    }

    private func reviewPhoto(_ url: URL, size: CGFloat) -> some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    PhotoPlaceholder(label: "여행 사진")
                }
            }
    }

    // MARK: - 접근성 문장

    /// 프로필 정지점에서 읽을 문장 (전용 화면 전용)
    private var authorSummary: String {
        authorMeta.isEmpty ? review.author : "\(review.author), \(authorMeta)"
    }

    /// 본문 정지점에서 읽을 문장 — 별점·날짜·태그·본문·좋아요를 한 번에 (전용 화면 전용)
    private var contentSummary: String {
        var parts: [String] = []
        if let rating = review.rating { parts.append("별점 5점 중 \(rating)점") }
        parts.append(Self.dateFormatter.string(from: review.createdAt))
        if !review.tags.isEmpty {
            parts.append(review.tags.map(\.label).joined(separator: ", "))
        }
        if let wouldRevisit = review.wouldRevisit, wouldRevisit {
            parts.append("재방문하고 싶다고 했어요")
        }
        parts.append(review.body)
        parts.append("좋아요 \(review.likeCount)개")
        return parts.joined(separator: ", ")
    }

    /// 프리뷰 자리에서 행 전체를 한 번에 읽을 문장
    private var accessibilitySummary: String {
        var parts = [review.author]
        if !authorMeta.isEmpty { parts.append(authorMeta) }
        if let rating = review.rating { parts.append("별점 5점 중 \(rating)점") }
        parts.append(Self.dateFormatter.string(from: review.createdAt))
        if !review.tags.isEmpty {
            parts.append(review.tags.map(\.shortLabel).joined(separator: ", "))
        }
        parts.append(review.body)
        parts.append("좋아요 \(review.likeCount)개")
        if !review.imageURLs.isEmpty { parts.append("사진 \(review.imageURLs.count)장") }
        return parts.joined(separator: ", ")
    }
}

#Preview("프리뷰 (장소 상세)") {
    VStack(spacing: 24) {
        PlaceReviewRow(review: .preview)

        // 별점·태그 없이 남긴 후기 (서버 `rating: null`, `tags: []`)
        PlaceReviewRow(review: TravelReview(
            author: "여행자",
            location: "불국사",
            body: "주차장에서 매표소까지 단차가 없습니다.",
            likeCount: 0,
            commentCount: 0,
            createdAt: Date(),
            isAccessibilityVerified: false
        ))
    }
    .padding(24)
}

#Preview("전용 화면 (사진 전부 · 팔로우/더보기 동작)") {
    PlaceReviewRow(review: .preview, showsAllPhotos: true, showsActionNotices: true)
        .padding(24)
}

extension TravelReview {
    /// 프리뷰용 — 별점·태그·사진이 모두 있는 후기
    static let preview = TravelReview(
        author: "공민희",
        location: "불국사",
        body: "휠체어 경사로가 잘 되어 있어서 편하게 둘러봤어요. 화장실도 넓고 손잡이가 있어 편했습니다.",
        likeCount: 3,
        commentCount: 1,
        createdAt: Date(timeIntervalSince1970: 1_777_000_000),
        isAccessibilityVerified: true,
        imageURLs: [],
        contentId: "264337",
        rating: 4,
        authorLevel: 7,
        authorReviewCount: 3,
        tags: Array(MockFeedService.tagPool.prefix(2)),
        wouldRevisit: true
    )
}
