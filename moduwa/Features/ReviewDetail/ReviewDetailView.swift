import SwiftUI

/// 리뷰 상세 (Figma "리뷰 상세" / "리뷰 상세 — 댓글 없음")
/// 좌우 마진 24, 사진·구분선은 풀블리드. 댓글은 백엔드 API가 아직 없어 **더미 + 로컬 입력**으로 다룬다.
struct ReviewDetailView: View {
    let review: TravelReview

    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss

    /// 방문한 장소 미니카드 채우기용 — contentId가 있을 때만 로드
    @State private var visitedDetail: PlaceDetail?
    /// 사진 캐러셀 현재 인덱스
    @State private var photoIndex = 0
    /// 로컬 댓글 (더미로 시작, 입력 시 추가)
    @State private var comments: [ReviewComment]
    @State private var draft = ""

    init(review: TravelReview) {
        self.review = review
        _comments = State(initialValue: ReviewComment.dummies(for: review))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 0) {
                    photoSection

                    authorRow
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    Text(review.body)
                        .font(.notoSans(16))
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    likeCommentRow
                        .padding(.horizontal, 24)
                        .padding(.top, 18)

                    fullDivider.padding(.top, 32)

                    visitedPlaceSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    fullDivider.padding(.top, 32)

                    commentsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                }
            }
            .background(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { commentInputBar }
        .task {
            guard let cid = review.contentId else { return }
            visitedDetail = try? await feedService.fetchPlaceDetail(contentId: cid)
        }
    }

    // MARK: - 헤더 (뒤로가기 + 타이틀)

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("리뷰 상세")
                .font(.notoSans(20, .bold))
                .padding(.leading, 12)

            Spacer()
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

    // MARK: - 사진 (캐러셀 + 접근성 뱃지 + 페이징 점)

    private var photoSection: some View {
        Group {
            if review.imageURLs.count > 1 {
                TabView(selection: $photoIndex) {
                    ForEach(Array(review.imageURLs.enumerated()), id: \.offset) { index, url in
                        reviewPhoto(url).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else if let url = review.imageURLs.first {
                reviewPhoto(url)
            } else {
                cameraPlaceholder
            }
        }
        .frame(height: 260)
        .clipped()
        .overlay(alignment: .topLeading) {
            if review.isAccessibilityVerified {
                photoBadge.padding(16)
            }
        }
        .overlay(alignment: .bottom) {
            if review.imageURLs.count > 1 {
                pagingDots.padding(.bottom, 16)
            }
        }
    }

    private func reviewPhoto(_ url: URL) -> some View {
        Color.clear.overlay {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                cameraPlaceholder
            }
        }
        .clipped()
    }

    private var cameraPlaceholder: some View {
        ZStack {
            Rectangle().fill(Color.photoPlaceholder)
            Image(systemName: "camera")
                .font(.system(size: 30))
                .foregroundStyle(.iconGray)
        }
        .accessibilityHidden(true)
    }

    /// 흰 원 + 딥그린 아이콘 (사진 위 접근성 검증 뱃지)
    private var photoBadge: some View {
        let feature = AccessibilityFeature.wheelchairAccessible
        let iconSize = feature.iconSize(inBadgeDiameter: 34)
        return Circle()
            .fill(.white)
            .frame(width: 34, height: 34)
            .overlay {
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize.width, height: iconSize.height)
                    .foregroundStyle(.deepGreen)
            }
            .shadow(color: .black.opacity(0.15), radius: 2.5, y: 1)
            .accessibilityLabel("접근성 검증됨")
    }

    private var pagingDots: some View {
        HStack(spacing: 6) {
            ForEach(review.imageURLs.indices, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == photoIndex ? 1 : 0.5))
                    .frame(width: index == photoIndex ? 8 : 6,
                           height: index == photoIndex ? 8 : 6)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 작성자 / 좋아요·댓글

    private var authorRow: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar(initial: String(review.author.prefix(1)), diameter: 40, fontSize: 15)

            VStack(alignment: .leading, spacing: 3) {
                Text(review.author)
                    .font(.notoSans(15, .bold))
                    .foregroundStyle(.textPrimary)
                Text(review.location)
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
            }

            Spacer(minLength: 8)

            Text(review.createdAt.reviewRelative)
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var likeCommentRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image("favorite")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.moduwaGreen)
                Text("\(review.likeCount)")
            }
            HStack(spacing: 4) {
                Image("chat_bubble")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.moduwaGreen)
                Text("\(review.commentCount)")
            }
        }
        .font(.notoSans(14))
        .foregroundStyle(.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("좋아요 \(review.likeCount)개, 댓글 \(review.commentCount)개")
    }

    // MARK: - 방문한 장소

    private var visitedPlaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("방문한 장소")
                .font(.notoSans(18, .bold))
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let place = visitedPlace {
                NavigationLink(value: place) {
                    placeMiniCard(showChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                placeMiniCard(showChevron: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// contentId가 있으면 장소 상세로 넘길 최소 Place를 구성 (상세는 넘어가서 재조회)
    private var visitedPlace: Place? {
        guard let cid = review.contentId else { return nil }
        return Place(
            id: cid,
            name: visitedDetail?.name ?? review.location,
            region: visitedDetail.map { APIFeedService.shortRegion($0.address) } ?? "",
            rating: nil,
            accessibilityNote: "",
            feature: .wheelchairAccessible,
            category: .attraction,
            imageURL: visitedDetail?.imageURL
        )
    }

    private func placeMiniCard(showChevron: Bool) -> some View {
        let name = visitedDetail?.name ?? review.location
        let region = visitedDetail.map { APIFeedService.shortRegion($0.address) }
        return HStack(spacing: 12) {
            Group {
                if let img = visitedDetail?.imageURL {
                    AsyncImage(url: img) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { cameraThumb }
                } else {
                    cameraThumb
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.notoSans(15, .bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                if let region, !region.isEmpty {
                    HStack(spacing: 3) {
                        Image("location_on").renderingMode(.template)
                        Text(region).font(.notoSans(13))
                    }
                    .foregroundStyle(.textSecondary)
                }
            }

            Spacer(minLength: 8)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.iconGray)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cardStroke, lineWidth: 1))
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint(showChevron ? "장소 상세 보기" : "")
    }

    private var cameraThumb: some View {
        ZStack {
            Rectangle().fill(Color.photoPlaceholder)
            Image(systemName: "camera")
                .font(.system(size: 22))
                .foregroundStyle(.iconGray)
        }
    }

    // MARK: - 댓글

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Text("댓글")
                    .font(.notoSans(18, .bold))
                    .foregroundStyle(.textPrimary)
                Text("\(comments.count)")
                    .font(.notoSans(18, .bold))
                    .foregroundStyle(.deepGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("댓글 \(comments.count)개")

            if comments.isEmpty {
                emptyComments
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(comments) { commentRow($0) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commentRow(_ comment: ReviewComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(initial: comment.initial, diameter: 32, fontSize: 13)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.author)
                        .font(.notoSans(13, .bold))
                        .foregroundStyle(.textPrimary)
                    Text(comment.timeAgo)
                        .font(.notoSans(12))
                        .foregroundStyle(.iconGray)
                }
                Text(comment.body)
                    .font(.notoSans(14))
                    .foregroundStyle(.textPrimary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyComments: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 34))
                .foregroundStyle(.iconGray)
                .padding(.bottom, 4)
            Text("아직 댓글이 없어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("첫 댓글을 남겨보세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 댓글 입력 (로컬)

    private var commentInputBar: some View {
        HStack(spacing: 8) {
            TextField("댓글을 남겨보세요", text: $draft)
                .font(.notoSans(14))
                .foregroundStyle(.textPrimary)
                .tint(.deepGreen)
                .submitLabel(.send)
                .onSubmit(submitComment)

            Button(action: submitComment) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(draft.trimmed.isEmpty ? Color.iconGray : .deepGreen)
            }
            .disabled(draft.trimmed.isEmpty)
            .accessibilityLabel("댓글 보내기")
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(height: 48)
        .background(Capsule().fill(Color.photoPlaceholder))
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
    }

    private func submitComment() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        comments.append(ReviewComment(author: "나", timeAgo: "방금", body: text))
        draft = ""
    }

    // MARK: - 공통

    private func avatar(initial: String, diameter: CGFloat, fontSize: CGFloat) -> some View {
        Circle()
            .fill(Color.deepGreen)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initial)
                    .font(.notoSans(fontSize, .bold))
                    .foregroundStyle(.white)
            )
    }

    private var fullDivider: some View {
        Rectangle()
            .fill(Color.cardStroke)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension Date {
    /// "3일 전" 형태의 한국어 상대 시간 (리뷰 헤더용)
    var reviewRelative: String {
        let seconds = Date().timeIntervalSince(self)
        let minute = 60.0, hour = 3600.0, day = 86_400.0
        switch seconds {
        case ..<minute: return "방금"
        case ..<hour: return "\(Int(seconds / minute))분 전"
        case ..<day: return "\(Int(seconds / hour))시간 전"
        case ..<(day * 30): return "\(Int(seconds / day))일 전"
        default: return "\(Int(seconds / (day * 30)))개월 전"
        }
    }
}

#Preview {
    NavigationStack {
        ReviewDetailView(review: MockData.reviews[1])
            .environment(\.feedService, MockFeedService())
    }
}
