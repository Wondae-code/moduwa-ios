import SwiftUI

/// 게시글 상세 — **리뷰 상세(`ReviewDetailView`, 시안 318:2)의 골격을 따랐다**
/// (2026-08-16 사용자 지시 "일단 리뷰 상세를 따라서"). 게시글 전용 시안은 아직 없다.
///
/// 같은 것: 헤더 → 사진 → 작성자 → 본문 → 좋아요·댓글 → 구분선 → 댓글 목록, 하단 댓글 입력 바.
/// 다른 것: 별점·재방문·"방문한 장소" 카드가 없고 **붙인 장소 여러 곳**과 **무장애 정보 뱃지**가 들어간다.
/// 게시글은 장소를 평가하는 글이 아니라 경험을 나누는 글이다.
struct PostDetailView: View {
    /// 목록에서 넘어온 값. 좋아요·댓글 수는 목록 시점 값이라 열자마자 다시 받는다.
    let post: TravelPost
    /// 부르는 쪽이 이미 아는 경우("내 게시글" 목록 — `mine=true` 로 받았다).
    /// 모르고 열어도 `MyPostIDStore` 가 가려 주므로 넘기지 않아도 된다 —
    /// 다만 이 값이 true 면 목록을 받아 오기를 기다리지 않고 곧바로 메뉴가 뜬다.
    var isMine = false

    @Environment(\.postService) private var postService
    @Environment(SessionStore.self) private var session
    @Environment(PostInteractionSignal.self) private var postSignal
    /// 어느 목록에서 열었든 내 글인지 가른다. 서버 응답에 소유 표시가 없어서 필요하다
    /// (`MyPostIDStore` 주석 — `isMine` 이 오면 이 저장소는 사라진다).
    @Environment(MyPostIDStore.self) private var myPostIDs
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReviewAuthorStore.nicknameKey) private var savedNickname = ""

    /// 서버에서 다시 받은 글. 없으면 목록에서 온 값으로 그린다 —
    /// 스피너만 띄우고 기다리면 이미 아는 내용까지 감추게 된다.
    @State private var detail: TravelPost?
    @State private var comments: [PostComment] = []
    @State private var didLoadComments = false
    @State private var commentsFailed = false

    @State private var isLiking = false
    @State private var draft = ""
    @State private var nicknameInput = ""
    @State private var isSending = false
    @State private var sendError: String?

    /// 수정 화면(작성 화면을 그대로 쓴다).
    @State private var isEditing = false
    /// 삭제 확인 창. 되돌릴 수 없는 일이라 한 번 더 묻는다.
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var current: TravelPost { detail ?? post }

    /// 수정·삭제 메뉴를 띄울지. 넘겨받았거나(확실한 경우) 내 글 목록에 있으면 띄운다.
    private var canManage: Bool {
        isMine || myPostIDs.contains(post.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !current.imageURLs.isEmpty { photoSection }

                    authorRow
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    Text(current.body)
                        .font(.notoSans(16))
                        .foregroundStyle(.textSecondary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    if !current.accessFeatures.isEmpty {
                        accessSection.padding(.horizontal, 24).padding(.top, 20)
                    }
                    if !current.places.isEmpty {
                        placeSection.padding(.horizontal, 24).padding(.top, 20)
                    }

                    likeCommentRow.padding(.horizontal, 24).padding(.top, 20)

                    Rectangle().fill(Color.cardStroke).frame(height: 1).padding(.top, 28)

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
        .onAppear { nicknameInput = savedNickname }
        // 글과 댓글은 서로 독립된 요청이다 — 한 task 에 이어 붙이면 뒤엣것이 앞의 응답을 기다린다.
        // ⚠️ `task(id: post.id)` 다. 알림을 연달아 누르면(`navigationDestination(item:)` 의 값이
        //  띄워진 채로 바뀐다) SwiftUI 가 이 뷰를 **같은 것으로 보고 `@State` 를 유지**한다 —
        //  그러면 `post` 는 새 글인데 `detail`·`comments` 는 앞 글의 것이 남아, 본문은 앞 글이고
        //  수정 메뉴는 새 글 기준으로 그려지는 화면이 된다(실측). 아이디가 바뀌면 비우고 다시 받는다.
        .task(id: post.id) {
            detail = nil
            detail = try? await postService.fetchPost(id: post.id)
        }
        .task(id: post.id) {
            comments = []
            didLoadComments = false
            await loadComments()
        }
        // 내 글 목록은 이번 실행에 한 번만 받는다. 비로그인이면 받을 것이 없다(401).
        //  ⚠️ `isMine` 으로 건너뛰지 않는다 — 그 글만 내 것이라고 아는 상태에서 다른 글로
        //  이어 들어가면(장소·댓글에서) 그때는 가릴 근거가 없다.
        // 계정을 키로 둔다 — 이 화면을 열어 둔 채로 댓글 게이트에서 로그인하면 그때 받아야 한다.
        .task(id: session.account?.uuid) {
            guard session.account != nil else { return }
            await myPostIDs.loadIfNeeded(using: postService)
        }
        // 수정은 작성 화면을 그대로 쓴다(`PostComposeView.editing`). 돌아오면 이 화면을 다시
        //  받는다 — 고친 내용이 곧바로 보여야 한다.
        .navigationDestination(isPresented: $isEditing) {
            PostComposeView(
                onPosted: { Task { detail = try? await postService.fetchPost(id: post.id) } },
                editing: current)
        }
        // ⚠️ 확인 창은 **바깥 뷰**에 붙인다 — 헤더 메뉴 안이나 조건부 하위 뷰에 붙이면
        //  창은 떠도 버튼이 죽는 일이 있었다(플랜 상세에서 실측).
        .confirmationDialog("이 글을 삭제할까요?", isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("삭제", role: .destructive) { Task { await deletePost() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 사진과 댓글도 함께 사라지고, 되돌릴 수 없어요.")
        }
        .alert("삭제하지 못했어요", isPresented: .init(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("확인") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    /// 삭제는 서버가 먼저다 — 화면에서 먼저 지우고 실패하면 사라진 글이 되살아나는 것처럼 보인다.
    /// 성공하면 화면을 닫고, 이 글을 든 다른 목록들이 걸러내도록 전역 신호를 올린다.
    private func deletePost() async {
        guard !isDeleting else { return }
        isDeleting = true
        do {
            try await postService.deletePost(id: post.id)
            postSignal.postDeleted(id: post.id)
            myPostIDs.note(deleted: post.id)
            dismiss()
        } catch {
            deleteError = (error as? LocalizedError)?.errorDescription
                ?? "잠시 후 다시 시도해 주세요."
        }
        isDeleting = false
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("게시글")
                .font(.notoSans(20, .bold))
                .padding(.leading, 12)

            Spacer()

            if canManage {
                Menu {
                    Button("수정", systemImage: "pencil") { isEditing = true }
                    Button("삭제", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 25, height: 25)
                }
                .accessibilityLabel("이 글 관리")
                .disabled(isDeleting)
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

    /// 게시글 사진은 최대 5장이라 `TabView` 페이지 스타일로 충분하다.
    private var photoSection: some View {
        TabView {
            ForEach(Array(current.imageURLs.enumerated()), id: \.offset) { _, url in
                Color.photoPlaceholder
                    .overlay {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.photoPlaceholder
                        }
                    }
                    .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: current.imageURLs.count > 1 ? .automatic : .never))
        .frame(height: 260)
        .accessibilityLabel("사진 \(current.imageURLs.count)장")
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            AuthorAvatar(name: current.author, avatarURL: current.authorAvatarURL,
                         diameter: 36, fontSize: 15)

            VStack(alignment: .leading, spacing: 2) {
                Text(current.author)
                    .font(.notoSans(15, .bold))
                    .foregroundStyle(.textPrimary)
                Text(RelativeTimeText.string(from: current.createdAt))
                    .font(.caption12)
                    .foregroundStyle(.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    /// 작성자가 고른 것이다 — 장소 데이터에서 파생된 공식 정보와 섞이면 안 되므로
    /// "작성자가 알려준" 이라고 밝혀 둔다.
    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("작성자가 알려준 무장애 정보")
                .font(.notoSans(13, .bold))
                .foregroundStyle(.textSecondary)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(current.accessFeatures, id: \.self) { feature in
                    HStack(spacing: 5) {
                        Image(feature.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: feature.iconSize(height: 14).width, height: 14)
                        Text(feature.label)
                            .font(.notoSans(13, .medium))
                    }
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(Color.moduwaGreen.opacity(0.18)))
                    .overlay(Capsule().stroke(Color.deepGreen.opacity(0.35), lineWidth: 1))
                }
            }
        }
    }

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이 글의 장소")
                .font(.notoSans(13, .bold))
                .foregroundStyle(.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(current.places) { place in
                HStack(spacing: 8) {
                    Image("location_on")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.deepGreen)

                    Text(place.name)
                        .font(.notoSans(14, .bold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    if let region = place.region, !region.isEmpty {
                        Text(region)
                            .font(.meta13)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.photoPlaceholder))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var likeCommentRow: some View {
        HStack(spacing: 16) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 4) {
                    // 누른 상태를 색만으로 전달하지 않는다 — 채워진 하트/빈 하트가 형태로 알린다.
                    Image(systemName: current.likedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .medium))
                    Text("\(current.likeCount)")
                        .font(.meta13)
                }
                .foregroundStyle(current.likedByMe ? .moduwaGreen : .textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isLiking)
            .accessibilityLabel(current.likedByMe ? "좋아요 취소" : "좋아요")
            .accessibilityValue("\(current.likeCount)개")

            HStack(spacing: 4) {
                Image("chat_bubble")
                    .renderingMode(.template)
                    .foregroundStyle(.moduwaGreen)
                Text("\(current.commentCount)")
            }
            .font(.meta13)
            .foregroundStyle(.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("댓글 \(current.commentCount)개")

            Spacer(minLength: 0)
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("댓글 \(current.commentCount)")
                .font(.notoSans(16, .bold))
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if !didLoadComments && !commentsFailed {
                HStack(spacing: 8) {
                    ProgressView().tint(.deepGreen)
                    Text("댓글을 불러오는 중이에요")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("댓글을 불러오는 중이에요")
            } else if commentsFailed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("댓글을 불러오지 못했어요")
                        .font(.notoSans(14, .bold))
                        .foregroundStyle(.textPrimary)
                    Button("다시 시도") { Task { await loadComments() } }
                        .font(.notoSans(13, .bold))
                        .foregroundStyle(.deepGreen)
                }
            } else if comments.isEmpty {
                Text("아직 댓글이 없어요")
                    .font(.notoSans(14))
                    .foregroundStyle(.iconGray)
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(comment.author)
                                .font(.notoSans(14, .bold))
                                .foregroundStyle(.textPrimary)
                            Text(RelativeTimeText.string(from: comment.createdAt))
                                .font(.caption12)
                                .foregroundStyle(.textSecondary)
                        }
                        Text(comment.body)
                            .font(.notoSans(14))
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var commentInputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sendError {
                Text(sendError)
                    .font(.notoSans(13))
                    .foregroundStyle(.deepGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
            }

            // 표시 이름이 없을 때만 나오는 인라인 입력 — 리뷰 상세와 같은 판단이다.
            //  시트로 물으면 읽던 글이 가려지고 키보드가 두 번 오간다.
            if savedNickname.isEmpty {
                TextField("댓글에 표시될 이름", text: $nicknameInput)
                    .font(.notoSans(14))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .onChange(of: nicknameInput) {
                        if nicknameInput.count > ReviewAuthorStore.nicknameLimit {
                            nicknameInput = String(nicknameInput.prefix(ReviewAuthorStore.nicknameLimit))
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(Color.photoPlaceholder))
                    .padding(.horizontal, 24)
                    .accessibilityLabel("댓글에 표시될 이름")
            }

            HStack(spacing: 8) {
                TextField("댓글을 입력해 주세요", text: $draft, axis: .vertical)
                    .font(.notoSans(14))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.photoPlaceholder))
                    .accessibilityLabel("댓글 내용")

                Button {
                    Task { await sendComment() }
                } label: {
                    ZStack {
                        Image("compose_send")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .opacity(isSending ? 0 : 1)
                        if isSending { ProgressView().tint(.deepGreen) }
                    }
                    .foregroundStyle(canSend ? .deepGreen : .iconGray)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isSending)
                .accessibilityLabel(isSending ? "댓글 등록 중" : "댓글 등록")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(savedNickname.isEmpty
                 && nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - 동작

    /// 화면을 먼저 바꾸고 서버에 보낸다 — 하트는 누른 즉시 반응해야 한다.
    /// 성공하면 **서버가 센 값으로 맞춘다**(그 사이 다른 사람이 눌렀을 수 있다), 실패하면 되돌린다.
    private func toggleLike() async {
        // 좋아요도 로그인 필수다. 낙관적 갱신을 먼저 하는 화면이라 **게이트가 그 앞에 있어야**
        //  한다 — 뒤에 두면 하트가 잠깐 켜졌다 꺼진다.
        guard session.requireSignIn(.like) else { return }
        guard !isLiking else { return }
        isLiking = true
        defer { isLiking = false }

        let before = current
        var optimistic = before
        optimistic.likedByMe = !before.likedByMe
        optimistic.likeCount = max(0, before.likeCount + (before.likedByMe ? -1 : 1))
        detail = optimistic

        do {
            let result = try await postService.setPostLiked(id: post.id, !before.likedByMe)
            var synced = optimistic
            synced.likeCount = result.likeCount
            synced.likedByMe = result.likedByMe
            detail = synced
            // 저장 탭의 "좋아요한 게시물"이 이 변화를 받아 갈 기회다(A23).
            postSignal.postLikeChanged()
        } catch {
            detail = before
        }
    }

    private func loadComments() async {
        commentsFailed = false
        do {
            comments = try await postService.fetchPostComments(id: post.id, limit: 50, offset: 0)
            didLoadComments = true
        } catch {
            commentsFailed = true
        }
    }

    private func sendComment() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        // 쓴 댓글은 입력칸에 그대로 남는다 — 로그인하고 돌아와 다시 보내면 된다.
        guard session.requireSignIn(.comment) else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        let name = savedNickname.isEmpty
            ? nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        do {
            let created = try await postService.createPostComment(
                id: post.id, body: trimmed, authorNm: name)
            comments.append(created)
            draft = ""
            // 이름을 방금 정했으면 다음 댓글부터 자동으로 채워진다. 서버가 계정 닉네임까지
            //  갱신하므로 계정 화면에도 함께 반영한다.
            if let name, !name.isEmpty {
                savedNickname = name
                session.noteNicknameChanged(name)
            }
            var updated = current
            updated.commentCount += 1
            detail = updated
            UIAccessibility.post(notification: .announcement, argument: "댓글을 등록했어요")
        } catch PostServiceError.nicknameRequired {
            sendError = "댓글에 표시될 이름을 입력해 주세요."
        } catch {
            sendError = (error as? PostServiceError)?.errorDescription
                ?? "댓글을 등록하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        }
    }
}
