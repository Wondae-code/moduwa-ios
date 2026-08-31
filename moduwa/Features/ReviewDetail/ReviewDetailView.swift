import SwiftUI

/// 리뷰 상세 (Figma "리뷰 상세" / "리뷰 상세 — 댓글 없음")
/// 좌우 마진 24, 사진·구분선은 풀블리드. 댓글은 `/v1/reviews/:reviewId/comments` 라이브 연동이다.
struct ReviewDetailView: View {
    let review: TravelReview

    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 후기 작성 화면과 같은 저장소를 공유한다 — 기기에 한 번 정한 표시 이름을 다시 묻지 않는다.
    @AppStorage(ReviewAuthorStore.nicknameKey) private var savedNickname = ""
    @Environment(SessionStore.self) private var session

    /// 방문한 장소 미니카드 채우기용 — contentId가 있을 때만 로드
    @State private var visitedDetail: PlaceDetail?
    /// 사진 캐러셀 현재 인덱스
    @State private var photoIndex = 0

    @State private var comments: [ReviewComment] = []
    /// 서버 집계 댓글 수. **화면의 댓글 수는 전부 이 값에서 나온다** (`commentCount` 참고).
    @State private var commentTotal: Int?
    /// 다음에 받을 페이지 번호 (0부터)
    @State private var commentPage = 0
    @State private var hasMoreComments = false
    @State private var isLoadingComments = false
    @State private var commentsFailed = false

    @State private var draft = ""
    /// 표시 이름이 아직 없을 때만 쓰는 인라인 입력값
    @State private var nicknameInput = ""
    @State private var isSending = false
    @State private var sendError: String?
    /// 고치는 중인 댓글. 입력칸을 그 댓글의 편집기로 쓴다(게시글 상세와 같은 문법).
    @State private var editingComment: ReviewComment?
    /// 지울 댓글(확인 창).
    @State private var deletingComment: ReviewComment?
    /// 댓글 입력칸 포커스 — 고치기 시작하면 키보드를 올린다.
    @FocusState private var isCommentFocused: Bool
    /// 이 후기 신고 시트. 서버 후기일 때만 열린다.
    @State private var isReporting = false

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
        // 방문 장소와 댓글은 서로 독립된 요청이다 — 한 task에 이어 붙이면 뒤엣것이 앞의 응답을 기다린다.
        .task {
            guard let cid = review.contentId else { return }
            visitedDetail = try? await feedService.fetchPlaceDetail(contentId: cid)
        }
        .task { await loadComments(reset: true) }
        // ⚠️ 확인 창은 **바깥 뷰**에 붙인다 — 조건부 하위 뷰에 붙이면 창은 떠도 버튼이 죽는다
        //  (플랜 상세에서 실측한 함정).
        .confirmationDialog("이 댓글을 삭제할까요?", isPresented: Binding(
            get: { deletingComment != nil }, set: { if !$0 { deletingComment = nil } }),
            titleVisibility: .visible, presenting: deletingComment
        ) { comment in
            Button("삭제", role: .destructive) {
                deletingComment = nil
                Task { await deleteComment(comment) }
            }
            Button("취소", role: .cancel) { deletingComment = nil }
        } message: { _ in
            Text("지우면 되돌릴 수 없어요.")
        }
        .sheet(isPresented: $isReporting) {
            if let serverId = review.serverId {
                ReviewReportSheet(reviewId: serverId)
            }
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

            // 하단은 댓글 입력 바가 차지하고 있어 플로팅 버튼을 쓸 수 없다 —
            // 같은 글리프를 헤더에 둬 작성으로 가는 길을 남긴다.
            WriteHeaderButton()

            // 신고는 장소 상세의 후기 줄(`PlaceReviewRow`)에만 있었다 — 후기를 **끝까지 읽은
            //  자리**에서 신고할 길이 없으면, 문제를 발견한 사람이 목록으로 되돌아가야 한다.
            //  번들·목 후기(`serverId == nil`)에는 신고를 붙일 대상이 없어 버튼을 아예 두지 않는다.
            if review.serverId != nil {
                Button { isReporting = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 30, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이 후기 신고")
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
            avatar(name: review.author, avatarURL: review.authorAvatarURL,
                   diameter: 40, fontSize: 15)

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
                Text("\(commentCount)")
            }
        }
        .font(.notoSans(14))
        .foregroundStyle(.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("좋아요 \(review.likeCount)개, 댓글 \(commentCount)개")
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

    /// 화면에 쓰는 댓글 수의 **단일 출처**.
    ///
    /// 서버 `total`이 도착하면 그것만 쓴다. 도착 전에는 리뷰 목록이 준 `commentCount`로 버틴다
    /// (0으로 시작하면 댓글이 있는 리뷰가 잠깐 "댓글 0"으로 깜빡인다).
    /// 받아 온 `comments.count`는 쓰지 않는다 — 페이지 크기에 잘린 값이라 총계가 아니다.
    private var commentCount: Int { commentTotal ?? review.commentCount }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Text("댓글")
                    .font(.notoSans(18, .bold))
                    .foregroundStyle(.textPrimary)
                Text("\(commentCount)")
                    .font(.notoSans(18, .bold))
                    .foregroundStyle(.deepGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("댓글 \(commentCount)개")
            .accessibilityAddTraits(.isHeader)

            commentsBody
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var commentsBody: some View {
        if review.serverId == nil {
            unavailableComments
        } else if isLoadingComments && comments.isEmpty {
            loadingComments
        } else if commentsFailed && comments.isEmpty {
            errorComments
        } else if comments.isEmpty {
            emptyComments
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(comments) { commentRow($0) }
            }

            if hasMoreComments {
                LoadMoreButton(title: "댓글 더보기") {
                    Task { await loadComments(reset: false) }
                }
                .padding(.top, 6)
                .disabled(isLoadingComments)
            }
        }
    }

    private func commentRow(_ comment: ReviewComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(name: comment.author, avatarURL: comment.authorAvatarURL,
                   diameter: 32, fontSize: 13)
            VStack(alignment: .leading, spacing: 3) {
                // 접근성 글자 크기에서는 이름 + 시간이 한 줄에 들어가지 않아 세로로 쌓는다
                authorTimeLine(comment)
                Text(comment.body)
                    .font(.notoSans(14))
                    .foregroundStyle(.textPrimary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 고치는 중인 줄은 어디를 고치고 있는지 보이게 한다(입력칸은 화면 아래에 있다).
        .padding(editingComment?.id == comment.id ? 8 : 0)
        .background {
            if editingComment?.id == comment.id {
                RoundedRectangle(cornerRadius: 10).fill(Color.photoPlaceholder)
            }
        }
        // 한 댓글이 한 단위로 읽히게 묶고, 순서를 잃지 않도록 라벨을 직접 조립한다
        // (기본 결합은 "이름 시간 본문"을 붙여 읽어 어디가 시간인지 구분되지 않는다).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(comment.author), \(comment.createdAt.reviewRelative), \(comment.body)")
        .modifier(CommentActions(
            isMine: comment.isMine,
            edit: { beginEditing(comment) },
            delete: { deletingComment = comment }
        ))
    }

    private func beginEditing(_ comment: ReviewComment) {
        editingComment = comment
        draft = comment.body
        isCommentFocused = true
    }

    private func cancelEditing() {
        editingComment = nil
        draft = ""
        sendError = nil
    }

    @ViewBuilder
    private func authorTimeLine(_ comment: ReviewComment) -> some View {
        let name = Text(comment.author)
            .font(.notoSans(13, .bold))
            .foregroundStyle(Color.textPrimary)
        let time = Text(comment.createdAt.reviewRelative)
            .font(.notoSans(12))
            .foregroundStyle(Color.iconGray)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                name
                time
            }
        } else {
            HStack(spacing: 6) {
                name
                time
            }
        }
    }

    private var emptyComments: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 34))
                .foregroundStyle(.iconGray)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
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

    private var loadingComments: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.deepGreen)
            Text("댓글을 불러오는 중이에요")
                .font(.notoSans(14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 스피너만으로는 스크린리더에 아무것도 전달되지 않는다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("댓글을 불러오는 중이에요")
    }

    private var errorComments: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("댓글을 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("네트워크 상태를 확인하고 다시 시도해 주세요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
            Button {
                Task { await loadComments(reset: true) }
            } label: {
                Text("다시 시도")
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("댓글 다시 불러오기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 서버 리뷰 id가 없는 리뷰 — 번들/목 데이터로 그린 화면이다(오프라인·API 키 미설정).
    /// 더미 댓글로 메우지 않는다. 남의 댓글을 이 리뷰 밑에 붙여 보여 주는 것과 같다.
    private var unavailableComments: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("댓글을 불러올 수 없어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Text("네트워크에 연결되면 댓글을 보고 남길 수 있어요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 댓글 입력

    /// 서버 리뷰 id가 없으면 입력 자체를 그리지 않는다. 보낼 곳이 없는 입력창은 고장으로 읽힌다
    /// (이유는 위 `unavailableComments`가 글로 알려 준다).
    @ViewBuilder
    private var commentInputBar: some View {
        if review.serverId != nil {
            VStack(alignment: .leading, spacing: 8) {
                // 디자인 시스템에 오류 색이 없다 — 후기 작성 화면과 같이 딥그린으로 두고
                // 무엇이 잘못됐는지는 문장으로 전달한다.
                if let sendError {
                    Text(sendError)
                        .font(.notoSans(13))
                        .foregroundStyle(.deepGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                }

                if editingComment != nil {
                    HStack(spacing: 8) {
                        Text("댓글 수정 중")
                            .font(.notoSans(13, .bold))
                            .foregroundStyle(.deepGreen)
                        Spacer(minLength: 8)
                        Button("취소", action: cancelEditing)
                            .font(.notoSans(13, .bold))
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.horizontal, 24)
                }

                // 고치는 중에는 이름을 묻지 않는다 — 이미 이름이 붙은 댓글이다.
                if savedNickname.isEmpty && editingComment == nil { nicknameField }

                draftField.padding(.horizontal, 24)
            }
            .padding(.vertical, 10)
            .background(.white)
        }
    }

    /// 표시 이름이 아직 없을 때만 나오는 인라인 입력.
    ///
    /// 시트로 따로 묻지 않는 이유: 서버는 기기의 첫 작성에만 `authorNm`을 요구하므로 평생 한 번뿐인
    /// 입력인데, 시트를 띄우면 읽던 후기가 가려지고 키보드가 두 번 오간다. 후기 작성 화면
    /// (`ReviewComposeView`)도 같은 화면 안에서 인라인으로 묻는다.
    /// 필수인 것도 그 화면과 같다 — 지어낸 기본 이름을 보내면 서버가 이 기기의 기존 닉네임을
    /// 덮어쓰고, 작성자가 전부 같은 이름이 된다.
    private var nicknameField: some View {
        HStack(spacing: 8) {
            TextField("댓글에 표시될 이름", text: $nicknameInput)
                .font(.notoSans(14))
                .foregroundStyle(.textPrimary)
                .tint(.deepGreen)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: nicknameInput) {
                    if nicknameInput.count > ReviewAuthorStore.nicknameLimit {
                        nicknameInput = String(nicknameInput.prefix(ReviewAuthorStore.nicknameLimit))
                    }
                }
                .accessibilityLabel("댓글에 표시될 이름")
                .accessibilityHint(
                    "처음 한 번만 입력하면 다음 댓글에는 자동으로 채워져요. 최대 \(ReviewAuthorStore.nicknameLimit)자")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(Capsule().fill(Color.photoPlaceholder))
        .padding(.horizontal, 24)
    }

    private var draftField: some View {
        // 접근성 글자 크기에서는 입력창과 보내기 버튼이 한 캡슐 안에 나란히 들어가지 않는다.
        let field = TextField("댓글을 남겨보세요", text: $draft, axis: .vertical)
            .focused($isCommentFocused)
            .font(.notoSans(14))
            .foregroundStyle(Color.textPrimary)
            .tint(.deepGreen)
            .lineLimit(1...4)
            .disabled(isSending)
            .onChange(of: draft) {
                // 서버 상한을 넘겨 보내면 400이다 — 넘기기 전에 끊는다
                if draft.count > ReviewComment.bodyLimit {
                    draft = String(draft.prefix(ReviewComment.bodyLimit))
                }
                // 고치기 시작했으면 지난 실패 문구는 더 이상 지금 상태가 아니다
                sendError = nil
            }
            .accessibilityLabel("댓글 입력")
            .accessibilityHint("최대 \(ReviewComment.bodyLimit)자")

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    field
                    sendButton.frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 24).fill(Color.photoPlaceholder))
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    // 한 줄짜리 입력은 높이가 글자만큼(약 20)이라, bottom 정렬만 두면 텍스트가
                    // 캡슐 아래쪽에 붙는다. 보내기 버튼과 같은 높이를 주고 그 안에서 가운데로
                    // 맞춰 캡슐 중앙에 오게 한다.
                    //  bottom 정렬 자체는 유지한다 — 여러 줄로 늘어나면 버튼이 마지막 줄 옆에 남아야 한다.
                    field.frame(minHeight: 44)
                    sendButton
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                // 고정 높이(48)를 주면 여러 줄로 늘어난 입력창이 잘린다
                .frame(minHeight: 48)
                .background(Capsule().fill(Color.photoPlaceholder))
            }
        }
    }

    private var sendButton: some View {
        Button { Task { await submitComment() } } label: {
            // 전송 중에는 같은 자리에 스피너 — 버튼이 사라지면 레이아웃이 튀고
            // 스크린리더 포커스도 잃는다.
            Group {
                if isSending {
                    ProgressView().tint(.deepGreen)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(canSend ? Color.deepGreen : Color.iconGray)
                }
            }
            // 최소 탭 영역 44pt
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel(isSending ? "댓글 보내는 중" : "댓글 보내기")
        // 왜 눌리지 않는지를 알려 준다 — 회색 아이콘만으로는 이유가 전달되지 않는다
        .accessibilityHint(sendDisabledReason ?? "")
    }

    /// 표시 이름이 아직 정해지지 않았다면 입력을 받아야 보낼 수 있다.
    ///  기본 이름을 지어내 등록하면 댓글 작성자가 전부 같은 이름이 된다.
    private var needsNickname: Bool { savedNickname.isEmpty && nicknameInput.trimmed.isEmpty }

    private var canSend: Bool {
        guard !draft.trimmed.isEmpty, !isSending else { return false }
        // 고치는 중이면 이름은 이미 붙어 있다.
        return editingComment != nil || !needsNickname
    }

    private var sendDisabledReason: String? {
        if isSending { return "보내는 중이에요" }
        return switch (draft.trimmed.isEmpty, needsNickname) {
        case (true, true): "이름과 댓글 내용을 입력하면 보낼 수 있어요"
        case (true, false): "댓글 내용을 입력하면 보낼 수 있어요"
        case (false, true): "댓글에 표시될 이름을 입력하면 보낼 수 있어요"
        case (false, false): nil
        }
    }

    // MARK: - 댓글 로드 · 전송

    /// - Parameter reset: 첫 페이지부터 다시 받는다 (진입, 재시도, 작성 성공 후)
    private func loadComments(reset: Bool) async {
        guard let reviewId = review.serverId else { return }
        if reset {
            commentPage = 0
        } else if isLoadingComments {
            return   // "더보기" 연타 방지
        }

        isLoadingComments = true
        commentsFailed = false
        let requestedPage = commentPage
        defer { isLoadingComments = false }

        do {
            let page = try await feedService.fetchReviewComments(
                reviewId: reviewId, page: requestedPage, pageSize: FeedPage.reviewCommentSize)
            comments = reset ? page.items : comments + page.items
            commentTotal = page.total
            // 빈 페이지가 왔으면 더 받을 게 없다. `total`만 보고 판단하면 남이 댓글을 지운 사이
            // 개수가 어긋났을 때 아무것도 불러오지 못하는 "더보기"가 계속 남는다.
            hasMoreComments = !page.items.isEmpty && comments.count < page.total
            commentPage = requestedPage + 1
        } catch {
            // 번들/목 데이터로 폴백하지 않는다 — 다른 리뷰의 댓글이 붙는다.
            commentsFailed = true
        }
    }

    private func send(reviewId: Int, text: String, authorNm: String?) async throws {
        try await feedService.submitReviewComment(
            reviewId: reviewId, body: text, authorNm: authorNm)
    }

    /// 고친 내용을 저장한다. 개수가 바뀌지 않으므로 **그 줄만 갈아끼운다** — 목록을 다시 받으면
    /// 페이지를 이어 받아 둔 것까지 잃고 보고 있던 자리가 튄다(작성은 개수가 바뀌어 재조회한다).
    private func saveEdit(of comment: ReviewComment, reviewId: Int, body: String) async {
        isSending = true
        sendError = nil
        defer { isSending = false }
        do {
            let updated = try await feedService.updateReviewComment(
                reviewId: reviewId, commentId: comment.id, body: body)
            if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[index] = updated
            }
            cancelEditing()
            isCommentFocused = false
            UIAccessibility.post(notification: .announcement, argument: "댓글을 수정했어요")
        } catch FeedServiceError.notFound {
            comments.removeAll { $0.id == comment.id }
            cancelEditing()
            sendError = "이 댓글은 이미 지워졌어요."
        } catch {
            sendError = (error as? FeedServiceError)?.errorDescription
                ?? "댓글을 수정하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        }
    }

    /// 댓글을 지운다. 서버가 먼저다 — 화면에서 먼저 지우고 실패하면 되살아나는 것처럼 보인다.
    ///
    /// 지운 뒤에는 **목록을 다시 받는다**: 서버가 같은 트랜잭션에서 `reviews.comment_count` 를
    /// 내리므로 `total` 까지 함께 맞춰야 한다(작성과 같은 판단).
    private func deleteComment(_ comment: ReviewComment) async {
        guard let reviewId = review.serverId else { return }
        do {
            try await feedService.deleteReviewComment(reviewId: reviewId, commentId: comment.id)
        } catch FeedServiceError.notFound {
            // ⚠️ 삭제는 멱등이 아니다(두 번 지우면 404). 이미 없어진 것은 성공과 같게 다룬다.
        } catch {
            sendError = (error as? FeedServiceError)?.errorDescription
                ?? "댓글을 지우지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            return
        }
        comments.removeAll { $0.id == comment.id }
        if editingComment?.id == comment.id { cancelEditing() }
        UIAccessibility.post(notification: .announcement, argument: "댓글을 지웠어요")
        await loadComments(reset: true)
    }

    private func submitComment() async {
        guard let reviewId = review.serverId, canSend else { return }
        if let editing = editingComment {
            await saveEdit(of: editing, reviewId: reviewId, body: draft.trimmed)
            return
        }
        // 댓글은 로그인 필수다. 쓴 글은 입력칸에 남으므로 로그인하고 돌아와 다시 보내면 된다.
        guard session.requireSignIn(.comment) else { return }
        let text = draft.trimmed

        // 사용자가 **직접 정한** 이름만 보낸다. 아무것도 정하지 않았으면 nil 이다.
        //  ⚠️ 여기서 기본 표시명을 지어내 보내면 안 된다. 서버는 받은 이름으로 이 기기의 닉네임을
        //     갱신하므로, 기기에 저장된 값이 비었다는 이유만으로 기본 이름을 보내면 서버에 있던
        //     실제 닉네임을 덮어쓴다(프로덕션에서 한 번 실제로 지워졌다).
        //     nil 을 보내면 서버가 기존 닉네임을 재사용하고, 정말 첫 작성일 때만 이름을 요구한다.
        let typed = nicknameInput.trimmed
        let chosen: String? = !typed.isEmpty ? typed
            : (!savedNickname.isEmpty ? savedNickname : nil)

        isSending = true
        sendError = nil

        do {
            try await send(reviewId: reviewId, text: text, authorNm: chosen)
            // 성공한 뒤에만 기기에 남긴다 — 실패한 이름을 굳혀 두면 다시 물을 기회가 없다.
            //  서버가 받은 이름으로 계정 닉네임을 갱신하므로 계정 화면에도 반영한다.
            if let chosen {
                savedNickname = chosen
                session.noteNicknameChanged(chosen)
            }
            draft = ""
            isSending = false
            // 목록이 조용히 바뀌면 스크린리더 사용자는 등록됐는지 알 수 없다.
            UIAccessibility.post(notification: .announcement, argument: "댓글을 등록했어요")
            // 개수(`total`)와 대화 순서를 서버 기준으로 다시 맞춘다.
            //
            // ⚠️ 댓글은 오래된 순이라 새 댓글은 **맨 끝**에 붙는다. 총 댓글이 한 페이지
            // (`FeedPage.reviewCommentSize`)를 넘는 리뷰에서는 첫 페이지만 다시 받는 지금 방식으로는
            // 방금 쓴 댓글이 화면에 안 보이고 "댓글 더보기"로 따라가야 한다. 등록 성공은 음성 안내로
            // 이미 알렸고, 실제 댓글 수가 20건을 넘는 리뷰가 아직 없어 이 정도로 둔다.
            await loadComments(reset: true)
        } catch {
            isSending = false
            // URLError 등 시스템 오류의 영어 문구가 새지 않게, 서버가 준 한국어 사유만 쓴다.
            let message = (error as? FeedServiceError)?.errorDescription
                ?? "댓글을 등록하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            sendError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // MARK: - 공통

    /// 사진이 있으면 사진, 없으면 이니셜 원. 규칙은 `AuthorAvatar` 한 곳에 있다 —
    /// 이 화면만 따로 그리면 카드와 상세에서 같은 작성자가 달리 보인다.
    private func avatar(name: String, avatarURL: URL?, diameter: CGFloat, fontSize: CGFloat) -> some View {
        AuthorAvatar(name: name, avatarURL: avatarURL, diameter: diameter, fontSize: fontSize)
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
    /// "3일 전" 형태의 한국어 상대 시간. 리뷰 헤더와 댓글 행이 같은 표기를 쓴다.
    ///
    /// `RelativeDateTimeFormatter`를 쓰지 않는 이유: 한국어 로케일에서 "3일 전"이 아니라
    /// "3일 전에"·"지난주"처럼 표기가 흔들리고, 초 단위는 "0초 전"이 나온다.
    /// 시안 문구("방금", "N시간 전")를 그대로 내려면 직접 계산하는 편이 확실하다.
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

/// 댓글이 달린 상태. 목 리뷰에는 서버 id가 없어 프리뷰에서 직접 붙여 준다.
private var previewReviewWithComments: TravelReview {
    var review = MockData.reviews[1]
    review.serverId = 2
    return review
}

#Preview("댓글 있음") {
    NavigationStack {
        ReviewDetailView(review: previewReviewWithComments)
            .environment(\.feedService, CommentPreviewService())
    }
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("큰 글자 (AX3)") {
    NavigationStack {
        ReviewDetailView(review: previewReviewWithComments)
            .environment(\.feedService, CommentPreviewService())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(SessionStore(service: MockAuthService()))
}

/// 서버 id가 없는 리뷰 — 댓글을 불러올 수 없다고 알리고 입력을 감춘 상태
#Preview("댓글 불가 (서버 id 없음)") {
    NavigationStack {
        ReviewDetailView(review: MockData.reviews[1])
            .environment(\.feedService, MockFeedService())
    }
    .environment(SessionStore(service: MockAuthService()))
}

/// 프리뷰 전용 — 상세는 목 그대로 두고 댓글만 채운다.
private struct CommentPreviewService: FeedService {
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
        try await base.fetchPlaceDetail(contentId: contentId)
    }

    func fetchReviewComments(
        reviewId: Int, page: Int, pageSize: Int
    ) async throws -> ReviewCommentPage {
        let items = [
            ReviewComment(
                id: 1, author: "민지",
                body: "실내라 비 오는 날에도 좋겠네요. 정보 감사합니다!",
                createdAt: Date().addingTimeInterval(-3 * 86_400)),
            ReviewComment(
                id: 2, author: "준호",
                body: "음성 안내가 있다니 반갑네요. 시각장애인 동반 방문에 참고하겠습니다.",
                createdAt: Date().addingTimeInterval(-5 * 3_600)),
        ]
        return ReviewCommentPage(total: items.count, items: items)
    }

    func submitReviewComment(reviewId: Int, body: String, authorNm: String?) async throws {}
}
