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
    let review: TravelReview
    /// 좋아요를 눌렀을 때. **nil 이면 표시 전용**(번들·목 후기, 또는 좋아요를 안 붙이는 화면).
    var onLike: (() -> Void)? = nil
    /// 사진을 전부 가로 스크롤로 펼친다 (전용 화면). false면 첫 장만 80×80.
    var showsAllPhotos = false
    /// 팔로우·더보기를 실제로 누를 수 있게 하고, 누르면 "준비 중" popover를 띄운다.
    ///
    /// **false면 시안대로 그리기만 하고 누를 수 없다** — 행 전체가 `NavigationLink`인 자리
    /// (장소 상세 프리뷰)에서 안에 버튼을 넣으면 탭이 갈라지고 VoiceOver 포커스도 쪼개진다.
    /// 링크로 감싸지 않는 화면(`PlaceReviewsView`)에서만 켠다.
    var showsActionNotices = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showsFollowNotice = false
    @State private var showsMoreNotice = false

    /// 버튼이 눌릴 수 있는 화면이면 접근성 구조도 달라진다 —
    /// 행 전체를 한 요소로 묶으면 그 안의 버튼에 도달할 방법이 없다.
    private var isInteractive: Bool { showsActionNotices }

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
            // 시안은 빈 원이지만 이 앱의 아바타는 딥그린 원 + 이름 첫 글자다
            // (ReviewCard·ReviewDetailView와 같은 규격 — 프로필 사진 소스가 없다)
            Circle()
                .fill(Color.deepGreen)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(review.author.prefix(1)))
                        .font(.notoSans(14, .bold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)

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

            // 접근성 글자 크기에서는 동작 없는 장식을 뺀다 (닉네임을 밀어내면 안 된다).
            // 실제로 눌리는 버튼은 글자 크기와 무관하게 남긴다.
            if showsActionNotices {
                followButton
                moreButton
            } else if !dynamicTypeSize.isAccessibilitySize {
                followBadge
                moreDots
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

    /// 동작 없는 장식판 (프리뷰 자리)
    private var followBadge: some View {
        followLabel.accessibilityHidden(true)
    }

    /// 팔로우는 백엔드에 대응 기능이 없다(팔로우 개념 자체가 없다).
    /// 그래도 버튼으로 두는 이유 — 스케치에 있는 요소를 회색 장식으로 두면 "왜 안 눌리지"가 되고,
    /// 눌러서 "준비 중"을 알려 주는 편이 상태가 분명하다. 실제 팔로우가 생기면 여기만 바꾼다.
    private var followButton: some View {
        Button { showsFollowNotice = true } label: { followLabel }
            .buttonStyle(.plain)
            .accessibilityLabel("\(review.author) 팔로우")
            .popover(isPresented: $showsFollowNotice) {
                noticeContent("팔로우는 아직 준비 중이에요")
            }
    }

    /// 리뷰 신고·숨김 라우트도 없어 더보기 역시 같은 처지다 — 팔로우와 같은 방식으로 답한다
    /// (두 버튼이 다르게 반응하면 어느 쪽이 고장인지 구분되지 않는다).
    private var moreButton: some View {
        Button { showsMoreNotice = true } label: {
            moreDots
                // 3pt 점 세 개는 44pt 터치 영역에 한참 못 미친다
                .frame(width: 30, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 후기 더보기")
        .popover(isPresented: $showsMoreNotice) {
            noticeContent("후기 신고·숨기기는 아직 준비 중이에요")
        }
    }

    /// 기능이 아직 없는 버튼의 안내.
    ///
    /// 접근성 판단 — 커스텀 토스트를 쓰지 않는다:
    /// 잠깐 떴다 사라지는 커스텀 뷰는 VoiceOver가 읽어 주지 않아, 스크린리더 사용자에게는
    /// 버튼을 눌러도 아무 일이 없는 것과 같다. iOS 기본 popover는 표시되면 **포커스가 내용으로
    /// 자동 이동**하므로 별도의 announcement를 얹지 않는다(얹으면 중복 낭독이 된다).
    /// `.alert`이 아니라 popover인 이유는 브랜드 폰트를 유지할 수 있어서다
    /// (`.alert` 내용은 시스템 폰트로 고정된다 — `ComingSoonView`를 만든 것과 같은 이유).
    private func noticeContent(_ message: String) -> some View {
        Text(message)
            .font(.notoSans(14, .medium, relativeTo: .subheadline))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(16)
            // 없으면 iPhone(compact)에서 popover가 시트로 바뀐다
            .presentationCompactAdaptation(.popover)
    }

    private var followLabel: some View {
        Text("팔로우")
            .font(.notoSans(12, .medium))
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.moduwaGreen, lineWidth: 1))
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
