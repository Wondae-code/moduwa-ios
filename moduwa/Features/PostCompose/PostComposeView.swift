import PhotosUI
import SwiftUI

/// 게시글 작성 — Figma "여행 후기 - 글쓰기"(642:2639, 페이지 265:2)
///
/// **UI 만 구현한 상태다**(2026-08-16 사용자 지시 "일단 UI만, 플로우는 다시 알려줄게").
/// 헤더의 "최근코스 불러오기"·"임시저장", 사진·장소 버튼, 전송, "무장애 정보 추가"는
/// 모두 목적지가 정해지지 않았다 — 눌러도 아무 일이 없으면 고장으로 읽히므로
/// 앱의 다른 준비 중 버튼과 같은 방식(`PlanPlaceholderButton`)으로 알린다.
///
/// 게시하기·사진·장소·최근코스 불러오기·임시저장·무장애 정보 추가 모두 동작한다
/// (서버 `71ba407`).
struct PostComposeView: View {
    /// 게시가 서버에서 성공한 뒤, 닫히기 직전에 불린다. 밀어 넣은 화면이 목록을
    /// 다시 받는 자리다(`WriteFloatingButton.onPosted` 주석 참고).
    var onPosted: (() -> Void)? = nil

    /// 고칠 글. nil 이면 새 글이다.
    ///
    /// **수정 화면을 따로 만들지 않는다** — 고칠 수 있는 것(내용·사진·장소·무장애 정보)이
    /// 새로 쓸 때와 정확히 같고, 두 화면을 두면 한쪽에만 고친 것이 생긴다. 다른 점 셋만
    /// 여기서 가른다: 제목, 임시저장 없음(초안은 새 글의 것이다), 저장 경로(PATCH).
    var editing: TravelPost? = nil

    private var isEditing: Bool { editing != nil }

    /// 고치는 글에 이미 올라가 있는 사진. 새로 고른 사진(`photos`)과 달리 서버에 이미 있어
    /// URL 만 들고 있고, 저장할 때 남긴 것 + 새로 올린 것을 이어 보낸다.
    @State private var keptImageURLs: [URL] = []

    /// 프로필에 보일 작성자. 후기 작성과 같은 저장소를 쓴다 — 같은 사람이다.
    @AppStorage(ReviewAuthorStore.nicknameKey) private var savedNickname = ""
    @Environment(SessionStore.self) private var session

    @Environment(\.dismiss) private var dismiss
    @Environment(\.postService) private var postService
    /// 방금 쓴 글도 내 글이다 — 목록을 다시 받지 않아도 상세에서 수정·삭제가 뜨게 한다.
    @Environment(MyPostIDStore.self) private var myPostIDs
    @Environment(\.feedService) private var feedService
    @State private var text = ""
    @FocusState private var isFocused: Bool

    /// 붙인 사진. 후기 작성과 **같은 타입**을 쓴다(`ComposePhoto`) — 고르고 줄이는 일이 같다.
    /// 다만 `uploadedURL` 은 늘 nil 이다: 게시글 저장 API 가 없어 올릴 곳이 없다.
    @State private var photos: [ComposePhoto] = []
    /// PhotosPicker 의 선택값. 받아서 `photos` 로 옮긴 뒤 바로 비운다(picker 가 항상 빈 상태로 열리게).
    @State private var photoSelection: [PhotosPickerItem] = []
    /// 사진을 디코딩·다운스케일하는 동안
    @State private var isPreparingPhotos = false
    /// 사진을 읽지 못한 사유. 사진 줄 위에 그대로 띄운다.
    @State private var photoError: String?

    /// 글에 붙인 장소.
    @State private var places: [Place] = []
    @State private var isPickingPlace = false
    @State private var isPickingCourse = false

    /// 작성자가 고른 무장애 정보. 시안의 라임 캡슐이 이 값을 담는다.
    @State private var accessFeatures: [AccessibilityFeature] = []
    @State private var isPickingAccess = false

    @State private var isSubmitting = false
    /// 게시 실패 사유. 서버가 한국어로 알려 주면 그대로 담는다.
    @State private var submitError: String?
    /// 닉네임을 아직 정하지 않은 기기다. 서버가 이름을 요구하면 켜지고, 프로필 줄이
    /// 정적 텍스트에서 입력칸으로 바뀐다 — 시안에 없는 요소지만 이름 없이는 글이 남지 않는다.
    ///
    /// **조건부로 두는 것이 확정 사항이다**(2026-08-16 사용자 지시) — 로그인 기능이 생기면
    /// 이름은 계정에서 오므로 이 입력칸 자체가 사라진다. 그때까지 미리 묻지 않는다.
    @State private var isEditingNickname = false
    @FocusState private var isNicknameFocused: Bool

    /// 내용이 비면 게시할 것이 없다. 이름을 정하는 중이라면 그것도 채워야 한다.
    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(isEditingNickname && savedNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// 시안 좌우 여백. 헤더만 26/24 로 다르고 본문 블록은 24 다.
    private static let sideMargin: CGFloat = 24

    /// 닉네임을 아직 정하지 않았을 수도 있다(후기를 한 번도 안 썼다면 비어 있다).
    private var nickname: String {
        savedNickname.isEmpty ? "여행자" : savedNickname
    }

    /// 프로필 원 안의 한 글자. 시안은 닉네임 첫 글자를 쓴다("효도여행중" → "효").
    private var initial: String {
        String(nickname.prefix(1))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileRow
                    editor
                    if !photos.isEmpty || !keptImageURLs.isEmpty || isPreparingPhotos || photoError != nil {
                        photoStrip
                    }
                    if !places.isEmpty { placeStrip }
                    if submitError != nil { errorBanner }
                    toolbar
                }
                .padding(.horizontal, Self.sideMargin)
                .padding(.top, 30)
            }

            // 시안은 툴바 아래 화면 폭을 가득 채우는 선을 긋는다(652:3433) —
            // 좌우 여백 안쪽이 아니라 **끝에서 끝까지**다.
            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)

            Spacer(minLength: 0)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let editing {
                fill(from: editing)
            } else {
                restoreDraft()
            }
            isFocused = true
        }
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            Task { await addPhotos(items) }
        }
        .sheet(isPresented: $isPickingPlace) {
            PostPlacePickerView(attached: places) { place in
                withoutAnimation { places.append(place) }
            }
        }
        .sheet(isPresented: $isPickingAccess) {
            PostAccessibilityPickerView(selection: $accessFeatures)
        }
        .sheet(isPresented: $isPickingCourse) {
            PostCoursePickerView(attached: attachedPostPlaces) { picked in
                withoutAnimation { places.append(contentsOf: picked.map(Self.place(from:))) }
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("뒤로")

            Text(isEditing ? "게시글 수정" : "게시글 작성")
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.leading, 8)

            Spacer(minLength: 12)

            Button { isPickingCourse = true } label: {
                Text("최근코스 불러오기")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.deepGreen)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityHint("짜 놓은 플랜의 장소를 한꺼번에 붙입니다")

            // 임시저장은 새 글에만 있다 — 고치는 글의 초안을 따로 들면 다음에 새 글을 쓸 때
            //  남의 글 내용이 되살아난다.
            if !isEditing {
            Button(action: saveDraft) {
                Text("임시저장")
                    .font(.notoSans(14, .regular, relativeTo: .subheadline))
                    .tracking(-0.4)
                    // 저장할 것이 없으면 흐려진다 — 색만이 아니라 스크린리더에도 실린다.
                    .foregroundStyle(hasContent ? Color.textSecondary : Color.iconGray)
                    .padding(.leading, 12)
            }
            .buttonStyle(.plain)
            .disabled(!hasContent || isSubmitting)
            .accessibilityLabel("임시저장")
            .accessibilityHint(hasContent ? "쓴 내용을 기기에 저장하고 나갑니다" : "저장할 내용이 없어요")
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 24)
        .frame(height: 49)
        .background(.white)
    }

    // MARK: - 프로필 줄

    private var profileRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // 프로필 사진을 올린 계정이면 그 사진을 쓴다 — 글에 붙어 남에게 보일 얼굴을
            //  쓰는 자리에서 미리 보여 주는 것이 맞다(`AuthorAvatar`).
            AuthorAvatar(name: nickname, avatarURL: session.account?.avatarURL,
                         diameter: 40, fontSize: 16)

            if isEditingNickname {
                // 시안에는 없는 입력칸이다. 서버가 첫 작성에 이름을 요구하므로(글은 사람에게
                //  귀속되는 내용이다) 그때만 자리를 낸다. 로그인이 붙으면 이 자리는 없어진다.
                TextField("표시될 이름", text: $savedNickname)
                    .font(.notoSans(15, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.textPrimary)
                    .tint(.deepGreen)
                    .focused($isNicknameFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.photoPlaceholder))
                    .padding(.top, 3)
                    .accessibilityLabel("표시될 이름")
            } else {
                Text(nickname)
                    .font(.notoSans(15, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .padding(.top, 9)
            }

            Spacer(minLength: 8)

            accessibilityButton
        }
    }

    /// 라임 캡슐. 고른 것이 있으면 개수를 함께 보여 준다 — 시트를 닫은 뒤 무엇을 골랐는지
    /// 알 길이 이 버튼뿐이다.
    private var accessibilityButton: some View {
        Button { isPickingAccess = true } label: {
            HStack(spacing: 4) {
                Image("access_wheelchair")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: AccessibilityFeature.wheelchairAccessible.iconSize(height: 18).width,
                        height: 18)
                Text(accessFeatures.isEmpty
                     ? "무장애 정보 추가"
                     : "무장애 정보 \(accessFeatures.count)")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .tracking(-0.4)
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 35)
            .background(Capsule().fill(Color.moduwaGreen))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityLabel(accessFeatures.isEmpty
            ? "무장애 정보 추가"
            : "무장애 정보 \(accessFeatures.count)개 선택됨")
    }

    // MARK: - 본문

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // TextEditor 는 플레이스홀더를 지원하지 않아 겹쳐 그린다.
            // 위치 상수(top 8 / leading 5)는 TextEditor 내부 기본 인셋에 맞춘 값이다.
            if text.isEmpty {
                Text("모두와 여행 경험을 공유해보세요\n(여행꿀팁, 후기, 기대감 등)")
                    .font(.notoSans(16, .regular, relativeTo: .body))
                    .foregroundStyle(Color.iconGray)
                    .lineSpacing(10)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .accessibilityHidden(true)
            }

            TextEditor(text: $text)
                .font(.notoSans(16, .regular, relativeTo: .body))
                .foregroundStyle(Color.textPrimary)
                .tint(.deepGreen)
                .lineSpacing(10)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .focused($isFocused)
                .accessibilityLabel("게시글 내용")
        }
        .padding(.top, 22)
    }

    // MARK: - 툴바

    /// 시안은 사진·장소를 왼쪽에, 전송을 오른쪽 끝에 둔다.
    /// 아이콘 크기는 시안값 그대로(카메라 28×22.4, 지도 26, 전송 17.9) — 탭 영역은 44 로 넓힌다.
    private var toolbar: some View {
        HStack(spacing: 0) {
            // 카메라를 쓰지 않는다 — `PhotosPicker` 는 사진 라이브러리 권한조차 요청하지 않고
            // 사용자가 고른 사진만 앱에 전달한다(후기 작성과 같은 판단).
            PhotosPicker(
                selection: $photoSelection,
                maxSelectionCount: max(Self.photoLimit - photos.count, 1),
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image("compose_camera")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 22.4)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(photos.count >= Self.photoLimit || isPreparingPhotos)
            .accessibilityLabel("사진 추가")
            .accessibilityHint("남은 자리 \(Self.photoLimit - photos.count)장")

            Button { isPickingPlace = true } label: {
                Image("plan_map")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("장소 추가")

            Spacer(minLength: 8)

            Button {
                Task { await submit() }
            } label: {
                ZStack {
                    Image("compose_send")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .opacity(isSubmitting ? 0 : 1)
                    if isSubmitting { ProgressView().tint(.deepGreen) }
                }
                // 보낼 수 없는 상태를 색만으로 알리지 않는다 — 흐려지고, 스크린리더에도 실린다.
                .opacity(canSubmit ? 1 : 0.35)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
            .accessibilityLabel(isSubmitting ? (isEditing ? "저장 중" : "게시 중")
                                             : (isEditing ? "수정 완료" : "게시하기"))
            .accessibilityHint(canSubmit ? "" : "내용을 입력하면 게시할 수 있어요")
        }
        .foregroundStyle(Color.deepGreen)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    /// 지금 붙어 있는 장소를 서버 표기로. 코스 불러오기가 중복을 걸러 내는 데 쓴다.
    private var attachedPostPlaces: [PostPlace] {
        places.map { PostPlace(contentID: $0.id, name: $0.name, region: $0.region) }
    }

    /// `PostPlace`(박제된 이름) → 화면이 쓰는 `Place`.
    ///
    /// 카테고리·평점·사진은 코스에도 초안에도 없다 — 장소 줄이 이름과 지역만 보여 주므로
    /// 표시상 차이는 없다. 그 줄에 사진이나 카테고리를 넣게 되면 그때 같이 실어야 한다.
    private static func place(from post: PostPlace) -> Place {
        Place(
            id: post.contentID,
            name: post.name,
            region: post.region ?? "",
            rating: nil,
            accessibilityNote: "",
            feature: .wheelchairAccessible,
            category: .attraction,
            imageURL: nil
        )
    }

    /// 고치는 글의 값을 화면에 채운다. `onAppear` 에서 한 번만 부른다 —
    /// 다시 부르면 사용자가 지운 사진·장소가 되살아난다.
    private func fill(from post: TravelPost) {
        text = post.body
        keptImageURLs = post.imageURLs
        places = post.places.map(Self.place(from:))
        accessFeatures = post.accessFeatures
    }

    // MARK: - 임시저장

    /// 저장하거나 게시할 거리가 있는지.
    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !photos.isEmpty || !places.isEmpty || !accessFeatures.isEmpty
    }

    /// 저장하고 **나간다**. 임시저장은 "나중에 마무리하겠다"는 뜻이라, 저장만 하고 남으면
    /// 저장이 됐는지 알 길이 없다 — 나갔다 다시 들어오면 글이 그대로 있는 것이 확인이 된다.
    private func saveDraft() {
        guard hasContent else { return }
        PostDraftStore.save(
            body: text,
            places: attachedPostPlaces,
            accessFeatures: accessFeatures.map(\.rawValue),
            photos: photos.map(\.data)
        )
        UIAccessibility.post(notification: .announcement, argument: "임시저장했어요")
        dismiss()
    }

    /// 화면이 열릴 때 초안을 되살린다.
    ///
    /// 묻지 않고 바로 채우는 이유: "임시저장"을 눌러 둔 사람이 다시 열었다면 이어 쓰려는 것이다.
    /// 확인 창을 띄우면 매번 한 번 더 눌러야 하고, 글이 그대로 있는 것이 곧 저장됐다는 확인이다.
    ///
    /// 장소는 이름·지역만 정확하다(`place(from:)` 주석 참고).
    private func restoreDraft() {
        guard let draft = PostDraftStore.load() else { return }
        text = draft.body
        places = draft.places.map(Self.place(from:))
        accessFeatures = draft.accessFeatures.compactMap(AccessibilityFeature.init(rawValue:))
        photos = draft.photos.compactMap { data in
            UIImage(data: data).map { ComposePhoto(thumbnail: $0, data: data) }
        }
        UIAccessibility.post(notification: .announcement, argument: "임시저장한 글을 불러왔어요")
    }

    // MARK: - 게시

    /// 실패해도 화면은 열려 있다 — 쓴 글과 붙인 사진을 그대로 두고 다시 누르면 된다.
    private var errorBanner: some View {
        Text(submitError ?? "")
            .font(.notoSans(13))
            .foregroundStyle(Color.deepGreen)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
    }

    /// 사진을 **게시할 때 올린다**(고를 때 올리지 않는다).
    ///
    /// 후기 작성은 고르는 즉시 올리는데, 거기서는 실패가 바로 드러나야 하고 등록 직전에
    /// 다섯 장이 한꺼번에 실패하면 무엇을 지울지 알 수 없기 때문이다. 게시글은 반대다 —
    /// 쓰다가 그만두는 일이 흔해서, 고를 때 올리면 **버려진 글의 사진만 서버에 쌓인다.**
    private func submit() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        var uploaded: [URL] = []
        if !photos.isEmpty {
            do {
                uploaded = try await feedService.uploadReviewImages(photos.map(\.data))
            } catch {
                submitError = (error as? FeedServiceError)?.errorDescription
                    ?? "사진을 올리지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
                return
            }
        }

        let attached = places.map {
            PostPlace(contentID: $0.id, name: $0.name, region: $0.region)
        }

        // 고치는 글이면 여기서 갈린다. 남긴 사진 + 새로 올린 사진을 이어 보낸다 —
        //  서버는 배열을 통째로 갈아끼우므로(부분 병합이 아니다) 남길 것도 함께 실어야 한다.
        if let editing {
            do {
                try await postService.updatePost(
                    id: editing.id, body: trimmed, imageURLs: keptImageURLs + uploaded,
                    places: attached, accessFeatures: accessFeatures)
                UIAccessibility.post(notification: .announcement, argument: "수정했어요")
                onPosted?()
                dismiss()
            } catch {
                submitError = (error as? PostServiceError)?.errorDescription
                    ?? "수정하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            }
            return
        }
        // 이름을 정하는 중이면 그 값을 함께 보낸다. 아니면 nil — 빈 문자열을 보내면
        // 서버가 기존 닉네임을 덮어쓴다.
        let name = isEditingNickname ? savedNickname.trimmingCharacters(in: .whitespacesAndNewlines) : nil

        do {
            let created = try await postService.createPost(
                body: trimmed, imageURLs: uploaded, places: attached,
                accessFeatures: accessFeatures, authorNm: name)
            myPostIDs.note(created: created.id)
            // 게시됐으면 초안은 더 이상 이어 쓸 것이 아니다 — 남겨 두면 다음에 열 때
            // 이미 올린 글이 되살아난다.
            PostDraftStore.clear()
            // 이름을 함께 보냈으면 서버가 계정 닉네임을 갱신했다 — 계정 화면에도 반영한다.
            if let name, !name.isEmpty { session.noteNicknameChanged(name) }
            UIAccessibility.post(notification: .announcement, argument: "게시했어요")
            // 닫기 전에 알린다 — 목록을 들고 있는 화면이 이 글을 받아 갈 기회다.
            onPosted?()
            dismiss()
        } catch PostServiceError.nicknameRequired {
            // 이름을 받아 다시 시도할 수 있게 입력칸을 연다. 사진은 이미 올라갔으므로
            // 다시 누를 때 두 번 올리지 않도록 올린 URL 을 사진 대신 들고 있진 않는다 —
            // 같은 사진은 내용 해시가 같아 서버에 한 번만 저장된다(중복이 쌓이지 않는다).
            isEditingNickname = true
            isNicknameFocused = true
            submitError = "게시글에 표시될 이름을 입력해 주세요."
        } catch {
            submitError = (error as? PostServiceError)?.errorDescription
                ?? "게시하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        }
    }

    // MARK: - 첨부

    /// 후기와 같은 상한. 게시글 저장 API 가 생기면 서버 상한(요청당 5장)과 맞춰야 한다.
    private static let photoLimit = ReviewDraft.imageLimit

    /// 고른 사진 줄. 업로드하지 않으므로 진행 표시나 재시도 버튼이 없다 —
    /// 지금은 "붙였다"까지가 전부다.
    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photoError {
                Text(photoError)
                    .font(.notoSans(13))
                    .foregroundStyle(Color.deepGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !photos.isEmpty || !keptImageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // 이미 올라가 있는 사진(수정 중) — 빼면 저장할 때 목록에서 사라진다.
                        ForEach(keptImageURLs, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.photoPlaceholder
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    withoutAnimation { keptImageURLs.removeAll { $0 == url } }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white, .black.opacity(0.45))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("이 사진 빼기")
                            }
                        }
                        ForEach(photos) { photo in
                            Image(uiImage: photo.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        withoutAnimation { photos.removeAll { $0.id == photo.id } }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white, .black.opacity(0.45))
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("이 사진 빼기")
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if isPreparingPhotos {
                HStack(spacing: 8) {
                    ProgressView().tint(.deepGreen)
                    Text("사진을 준비하는 중이에요")
                        .font(.notoSans(13))
                        .foregroundStyle(Color.textSecondary)
                }
                // 스피너만으로는 스크린리더에 아무것도 전달되지 않는다
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("사진을 준비하는 중이에요")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
    }

    /// 붙인 장소 줄. 검색 결과 행(`PlaceSearchRow`)을 쓰지 않는다 — 56pt 썸네일 행은
    /// 고를 때의 규격이고, 여기서는 이미 고른 것을 짧게 확인만 하면 된다.
    private var placeStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(places) { place in
                HStack(spacing: 8) {
                    Image("location_on")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.deepGreen)

                    Text(place.name)
                        .font(.notoSans(14, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(place.region)
                        .font(.notoSans(13, .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button {
                        withoutAnimation { places.removeAll { $0.id == place.id } }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.iconGray)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(place.name) 빼기")
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.photoPlaceholder))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    /// 고른 사진을 줄여서 담는다. 후기 작성과 같은 인코더를 쓴다(장변 1280·q0.8, 2MB 상한).
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        isPreparingPhotos = true
        photoError = nil
        defer { isPreparingPhotos = false }

        for item in items {
            guard photos.count < Self.photoLimit else { break }
            guard let raw = try? await item.loadTransferable(type: Data.self) else {
                photoError = "사진을 읽지 못했어요. 다른 사진을 선택해 주세요."
                continue
            }
            // 디코딩·리샘플링을 메인 스레드에서 하면 큰 사진에서 화면이 멈춘다.
            let prepared = await Task.detached(priority: .userInitiated) {
                ReviewPhotoEncoder.encode(raw).flatMap { data in
                    UIImage(data: data).map { (data: data, image: $0) }
                }
            }.value
            guard let prepared else {
                photoError = "사진을 처리하지 못했어요. 다른 사진을 선택해 주세요."
                continue
            }
            photos.append(ComposePhoto(thumbnail: prepared.image, data: prepared.data))
        }
    }

    private func toolButton<Icon: View>(
        notice: String, label: String, @ViewBuilder icon: @escaping () -> Icon
    ) -> some View {
        PlanPlaceholderButton(notice: notice) {
            icon()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

#Preview("게시글 작성") {
    NavigationStack { PostComposeView() }
}

#Preview("닉네임 없음") {
    NavigationStack { PostComposeView() }
        .onAppear { UserDefaults.standard.removeObject(forKey: ReviewAuthorStore.nicknameKey) }
}
