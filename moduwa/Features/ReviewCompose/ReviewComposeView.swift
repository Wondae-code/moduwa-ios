import PhotosUI
import SwiftUI

/// 작성 화면에 담긴 사진 한 장. 선택 → 인코딩 → 업로드까지의 상태를 그대로 들고 있다.
///
/// 등록 버튼을 누를 때 한꺼번에 올리지 않고 **고르는 즉시 올린다**. 그래야 실패가 바로 드러나고
/// (등록 직전에 다섯 장이 한꺼번에 실패하면 무엇을 지워야 하는지 알 수 없다) 장별로 다시 시도할 수 있다.
struct ComposePhoto: Identifiable {
    let id = UUID()
    /// 화면에 보여 줄 썸네일 (다운스케일 결과를 그대로 쓴다)
    let thumbnail: UIImage
    /// 업로드할 JPEG 바이트 (`ReviewPhotoEncoder`를 이미 통과한 값)
    let data: Data
    var uploadedURL: URL?
    /// 서버가 준 한국어 사유 (있으면 다시 시도 버튼을 띄운다)
    var errorMessage: String?
    var isUploading = false
}

/// 후기 작성 화면.
///
/// **시안 미확보** — 디자인이 아직 없어 장소 상세(`PlaceDetailView`)·리뷰 상세(`ReviewDetailView`)의
/// 톤(좌우 마진 24, 풀블리드 구분선, 라임 캡슐 CTA)을 기준으로 자체 구성했다.
/// 시안이 나오면 헤더 형태·섹션 간격·CTA 배치가 바뀔 수 있다.
///
struct ReviewComposeView: View {
    let placeName: String
    let placeAddress: String
    /// 관광공사 contentId — 후기를 장소에 붙이는 키
    let contentId: String?
    /// 장소 상세의 "방문 후기를 남겨주세요!"에서 고른 별점 (없으면 0)
    var initialRating: Int = 0
    /// **서버 등록이 성공한 뒤에만** 불린다 — 호출부가 목록·집계를 갱신하는 훅
    var onSubmit: (ReviewDraft) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.feedService) private var feedService
    @AppStorage(ReviewAuthorStore.nicknameKey) private var savedNickname = ""
    @Environment(SessionStore.self) private var session

    @State private var rating = 0
    @State private var isSubmitting = false
    /// 등록 실패 사유 — 서버가 준 한국어 메시지를 그대로 띄운다
    @State private var submitError: String?
    @State private var reviewText = ""
    @State private var nicknameInput = ""
    /// "변경"을 눌러 입력 필드를 직접 열었는지.
    @State private var didRequestNicknameEdit = false
    @FocusState private var focusedField: Field?

    /// 저장된 닉네임이 없으면 처음부터 입력 필드를 열어 둔다.
    ///  ⚠️ 이 값을 `onAppear` 에서 `@State` 로 바꾸면 안 된다 — 화면이 나타난 **뒤에** 입력 필드가
    ///     끼어들면서 ScrollView 가 그 위치로 따라가, 시트가 별점을 지나쳐 스크롤된 채 열렸다.
    ///     `@AppStorage` 는 첫 렌더에서 이미 읽히므로 파생 값으로 두면 레이아웃이 흔들리지 않는다.
    private var isEditingNickname: Bool { didRequestNicknameEdit || savedNickname.isEmpty }

    /// "재방문을 하고 싶어요" 체크. **미체크는 false가 아니라 미응답(nil)으로 보낸다** —
    /// 서버가 true/false/null 세 상태를 구분하고, 미응답을 false로 접으면
    /// "다시 오지 않겠다"는 뜻이 되어 버린다. 그래서 화면에도 "아니오"를 두지 않는다.
    @State private var wantsRevisit = false

    /// `GET /v1/review-tags`로 받은 태그 사전. 실패하면 칩 섹션을 그리지 않는다
    /// (서버가 모르는 코드는 400이므로 앱에 하드코딩한 목록으로 대신할 수 없다).
    @State private var availableTags: [ReviewTag] = []
    /// 방문 조건을 미리 체크해 준 적이 있는가. 한 번만 한다(아래 `suggestVisitorTags` 주석).
    @State private var didSuggestVisitorTags = false
    @State private var selectedTagCodes: Set<String> = []

    @State private var photos: [ComposePhoto] = []
    /// PhotosPicker의 선택값. 받아서 `photos`에 옮긴 뒤 바로 비운다 (picker가 항상 빈 상태로 열리게).
    @State private var photoSelection: [PhotosPickerItem] = []
    /// 사진을 디코딩·다운스케일하는 동안 (네트워크 이전 단계)
    @State private var isPreparingPhotos = false

    private enum Field { case nickname, review }

    var body: some View {
        // 스케치 순서: 별점 → 재방문 → (구분선) 태그 → (구분선) 닉네임 → 후기(사진 + 본문).
        //  헤더 바가 없어 닫기 버튼도 없다 — 시트의 기본 스와이프 닫기에 맡기고, 그게
        //  가능하다는 걸 보이도록 드래그 인디케이터를 띄운다(VoiceOver 는 스크럽 제스처로 닫는다).
        //  닉네임은 스케치에 없는 요소다(서버가 첫 작성 때 필수로 요구한다). 후기 바로 위에 둔다.
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 0) {
                    ratingSection
                        .padding(.horizontal, 24)
                        .padding(.top, 28)

                    revisitSection
                        .padding(.horizontal, 24)
                        .padding(.top, 18)

                    if !availableTags.isEmpty {
                        sectionDivider
                        tagSection
                            .padding(.horizontal, 24)

                        visitorTagSection
                            .padding(.horizontal, 24)
                            .padding(.top, Spacing.xl)
                    }

                    sectionDivider
                    nicknameSection
                        .padding(.horizontal, 24)

                    sectionDivider
                    reviewSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, Spacing.xxl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { submitBar }
        .onAppear {
            nicknameInput = savedNickname
            if rating == 0 { rating = initialRating }
        }
        // 태그 사전은 별점·본문과 무관하게 받아 둔다. 실패하면 섹션이 빠질 뿐 작성은 계속된다.
        .task {
            availableTags = (try? await feedService.fetchReviewTags()) ?? []
            suggestVisitorTags()
        }
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            Task { await addPhotos(items) }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    // MARK: - 헤더

    /// 타이틀도 닫기 버튼도 없는 빈 바다. 그래도 두는 이유는 시트 상단의 드래그 인디케이터가
    /// 바로 아래 콘텐츠(별점) 위에 겹쳐 보이기 때문이다 — 인디케이터에 제 영역을 주고
    /// 아래 구분선으로 콘텐츠와 경계를 만든다. 닫기는 여전히 스와이프로 한다.
    private var headerBar: some View {
        Color.clear
            .frame(height: 22)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityHidden(true)
    }

    // MARK: - 재방문 (체크박스 — 드롭다운이 아니다)

    /// 스케치는 이 항목을 둥근 알약으로 감싸 별점 아래 가운데 둔다.
    ///  알약은 내용 폭에만 맞춘다(`fixedSize`) — 화면 폭을 다 쓰면 알약이 아니라 배너로 보인다.
    private var revisitSection: some View {
        VStack(spacing: 8) {
            // 접근성 판단: 체크 상태를 색만으로 전달하지 않는다.
            // 네모/체크 글리프가 형태로, `.isToggle` + `accessibilityValue`가 스크린리더로 전달한다.
            Button {
                // 체크 글리프·글자 굵기·테두리가 한꺼번에 바뀌므로 애니메이션되면 알약이 들썩인다.
                withoutAnimation { wantsRevisit.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: wantsRevisit ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(wantsRevisit ? .deepGreen : .iconGray)
                    Text("재방문을 하고 싶어요")
                        .font(.notoSans(16, wantsRevisit ? .bold : .medium))
                        .foregroundStyle(wantsRevisit ? .textPrimary : .textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(wantsRevisit ? Color.moduwaGreen.opacity(0.18) : Color.photoPlaceholder)
                )
                // 선택 상태를 배경색만으로 전달하지 않는다 — 테두리 두께도 함께 바뀐다.
                .overlay(
                    Capsule().stroke(wantsRevisit ? Color.deepGreen : Color.cardStroke,
                                     lineWidth: wantsRevisit ? 2 : 1)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("재방문을 하고 싶어요")
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(wantsRevisit ? "선택함" : "선택하지 않음")

            // "아니오"가 없는 이유를 말해 준다 — 체크하지 않은 상태가 부정 답변으로 읽히지 않게.
            Text("체크하지 않으면 답하지 않은 것으로 남겨요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 태그 다중 선택

    /// 장소 평가 칩(`kind == .place`).
    private var placeTags: [ReviewTag] { availableTags.filter { $0.kind == .place } }
    /// 방문 조건 칩(`kind == .visitor`).
    private var visitorTags: [ReviewTag] { availableTags.filter { $0.kind == .visitor } }

    /// 내 무장애정보와 겹치는 방문 조건을 **미리 체크해 둔다.**
    ///
    /// ⚠️ 자동 저장이 아니다 — 체크된 채로 보이고, 지우는 것도 본인이 한다. 프로필은 비공개인데
    /// 이 태그는 공개라, 묻지 않고 붙이면 프로필을 대신 공개하는 것이 된다. 그래서 아래 칩
    /// 묶음에 "후기에 함께 공개돼요" 를 적어 두고, 한 번 손댄 뒤에는 다시 건드리지 않는다
    /// (사전이 늦게 와도 사용자가 이미 고른 것을 덮지 않게).
    private func suggestVisitorTags() {
        guard !didSuggestVisitorTags else { return }
        didSuggestVisitorTags = true
        let mine = Set(session.accessFeatures.compactMap(\.visitorTagCode))
        for tag in visitorTags where mine.contains(tag.code) {
            selectedTagCodes.insert(tag.code)
        }
    }

    private var tagSection: some View {
        // 스케치는 제목·부제만 가운데로 두고 칩은 왼쪽부터 채운다.
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("어떤 점이 좋았나요?")
                .frame(maxWidth: .infinity)

            Text("여러개 선택 가능합니다")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            // 폭이 차면 다음 줄로 넘긴다 — 접근성 글자 크기에서 칩 하나가 한 줄을 다 써도 잘리지 않는다
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(placeTags) { tag in
                    ReviewTagSelectChip(tag: tag, isSelected: selectedTagCodes.contains(tag.code)) {
                        // 애니메이션 없이 즉시 바뀐다. 선택하면 글자가 굵어져 칩 폭이 조금 달라지는데,
                        // 그게 애니메이션되면 옆·아랫줄 칩까지 밀려 흔들린다.
                        withoutAnimation { selectedTagCodes.toggle(tag.code) }
                    }
                }
            }
            .padding(.top, 2)
            // 개별 칩이 "선택됨"을 알려 주지만, 몇 개를 골랐는지는 어느 칩에도 담기지 않는다
            .accessibilityElement(children: .contain)
            .accessibilityLabel("어떤 점이 좋았나요, 여러개 선택 가능")
            .accessibilityValue(selectedTagCodes.isEmpty ? "선택한 태그 없음" : "\(selectedTagCodes.count)개 선택")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "어떻게 방문하셨나요" — 방문 조건 칩(서버 051).
    ///
    /// 장소 평가와 **묻는 대상이 다르다.** 앞은 이 장소가 어땠는지이고, 이것은 쓴 사람이 어떤
    /// 조건으로 갔는지다. 그래서 묶음을 나눠 보여 준다 — 섞으면 "휠체어로 방문했어요" 가
    /// 장소의 특징으로 읽힌다.
    @ViewBuilder
    private var visitorTagSection: some View {
        if !visitorTags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("어떻게 방문하셨나요?")
                    .frame(maxWidth: .infinity)

                // 공개된다는 사실을 고를 자리에서 말한다 — 프로필은 비공개인데 이 태그는 공개다.
                Text("같은 조건으로 여행하는 분들이 이 후기를 찾을 수 있어요. 후기에 함께 공개돼요.")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(visitorTags) { tag in
                        ReviewTagSelectChip(tag: tag, isSelected: selectedTagCodes.contains(tag.code)) {
                            withoutAnimation { selectedTagCodes.toggle(tag.code) }
                        }
                    }
                }
                .padding(.top, 2)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("어떻게 방문하셨나요, 여러개 선택 가능. 고른 항목은 후기에 공개됩니다")
                .accessibilityValue(
                    selectedVisitorCount == 0 ? "선택한 항목 없음" : "\(selectedVisitorCount)개 선택")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedVisitorCount: Int {
        visitorTags.filter { selectedTagCodes.contains($0.code) }.count
    }


    // MARK: - 별점

    /// 스케치는 별점만 가운데 두고 제목·설명 문구를 넣지 않는다. 화면 최상단이라 무엇을
    /// 고르는 자리인지 별 모양만으로 충분하다는 판단으로 읽힌다.
    ///  VoiceOver 에는 여전히 `StarRatingInput` 이 "별점 / 5점 중 N점, 좋아요"로 읽어 준다 —
    ///  눈으로 별을 볼 수 없는 사용자에게는 그 문구가 유일한 단서라 지우지 않았다.
    private var ratingSection: some View {
        StarRatingInput(rating: $rating)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 닉네임

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("닉네임")

            if isEditingNickname {
                HStack(spacing: 8) {
                    TextField("후기에 표시될 이름", text: $nicknameInput)
                        .font(.notoSans(15))
                        .foregroundStyle(.textPrimary)
                        .tint(.deepGreen)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { focusedField = .review }
                        .onChange(of: nicknameInput) {
                            if nicknameInput.count > ReviewAuthorStore.nicknameLimit {
                                nicknameInput = String(nicknameInput.prefix(ReviewAuthorStore.nicknameLimit))
                            }
                        }
                        .accessibilityLabel("닉네임")

                    Text("\(nicknameInput.count)/\(ReviewAuthorStore.nicknameLimit)")
                        .font(.notoSans(12, .medium))
                        .foregroundStyle(.iconGray)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(Capsule().fill(Color.photoPlaceholder))

                Text("처음 한 번만 입력하면 다음 후기에는 자동으로 채워져요")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
            } else {
                HStack(spacing: 8) {
                    Text(savedNickname)
                        .font(.notoSans(15, .medium))
                        .foregroundStyle(.textPrimary)

                    Spacer(minLength: 8)

                    Button {
                        didRequestNicknameEdit = true
                        focusedField = .nickname
                    } label: {
                        Text("변경")
                            .font(.notoSans(14, .bold))
                            .foregroundStyle(.deepGreen)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닉네임 변경")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(Capsule().fill(Color.photoPlaceholder))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 후기 (사진 + 본문)

    /// 스케치는 사진과 본문을 "후기를 작성해 보세요!" 하나 아래 묶고, 사진 슬롯을 본문 **위**에 둔다.
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("후기를 작성해 보세요", isRequired: true)

            photoStrip

            ZStack(alignment: .topLeading) {
                // TextEditor는 플레이스홀더를 지원하지 않아 겹쳐 그린다.
                // 위치 상수(top 8 / leading 5)는 TextEditor 내부 기본 인셋에 맞춘 값이다.
                if reviewText.isEmpty {
                    Text("어떤 점이 편했고 어떤 점이 아쉬웠는지 알려주세요.\n경사로·화장실·주차처럼 다음 방문자에게 도움이 될 내용이면 더 좋아요.")
                        .font(.notoSans(15))
                        .foregroundStyle(.iconGray)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $reviewText)
                    .font(.notoSans(15))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .focused($focusedField, equals: .review)
                    .onChange(of: reviewText) {
                        if reviewText.count > ReviewDraft.bodyLimit {
                            reviewText = String(reviewText.prefix(ReviewDraft.bodyLimit))
                        }
                    }
                    .accessibilityLabel("후기 내용")
                    .accessibilityHint("최대 \(ReviewDraft.bodyLimit)자까지 쓸 수 있어요")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

            Text("\(reviewText.count) / \(ReviewDraft.bodyLimit)")
                .font(.notoSans(13, .medium))
                .foregroundStyle(reviewText.count >= ReviewDraft.bodyLimit ? .deepGreen : .textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(reviewText.count)자 입력, 최대 \(ReviewDraft.bodyLimit)자")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 사진

    /// 카메라를 쓰지 않는다 — `PhotosPicker`는 사진 라이브러리 권한조차 요청하지 않고
    /// 사용자가 고른 사진만 앱에 전달한다. 후기 사진에 필요한 최소 권한이다.
    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최대 \(ReviewDraft.imageLimit)장까지 올릴 수 있어요")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photoThumbnail($0) }
                    }
                    .padding(.vertical, 2)
                }
            }

            if photos.count < ReviewDraft.imageLimit {
                PhotosPicker(
                    selection: $photoSelection,
                    maxSelectionCount: ReviewDraft.imageLimit - photos.count,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("사진 고르기")
                            .font(.notoSans(14, .bold))
                    }
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Color.moduwaGreen, lineWidth: 1))
                }
                .disabled(isPreparingPhotos || isSubmitting)
                .accessibilityLabel("사진 고르기")
                .accessibilityHint("남은 자리 \(ReviewDraft.imageLimit - photos.count)장")
            }

            if isPreparingPhotos {
                HStack(spacing: 8) {
                    ProgressView().tint(.deepGreen)
                    Text("사진을 준비하는 중이에요")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                }
                // 스피너만으로는 스크린리더에 아무것도 전달되지 않는다
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("사진을 준비하는 중이에요")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoThumbnail(_ photo: ComposePhoto) -> some View {
        // 상태(올리는 중·실패)를 사진 위에 겹쳐 보여 준다 — 어느 사진이 문제인지 바로 보이게.
        Image(uiImage: photo.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: Radius.badge))
            .overlay {
                if photo.isUploading {
                    RoundedRectangle(cornerRadius: Radius.badge)
                        .fill(.black.opacity(0.35))
                        .overlay { ProgressView().tint(.white) }
                } else if photo.errorMessage != nil {
                    RoundedRectangle(cornerRadius: Radius.badge)
                        .fill(.black.opacity(0.45))
                        .overlay {
                            VStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("실패")
                                    .font(.notoSans(11, .bold))
                            }
                            .foregroundStyle(.white)
                        }
                }
            }
            .overlay(alignment: .topTrailing) { removeButton(photo) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("후기 사진")
            .accessibilityValue(photoStatusText(photo))
            .accessibilityActions {
                Button("사진 삭제") { remove(photo) }
                if photo.errorMessage != nil {
                    Button("다시 올리기") { Task { await upload(photo.id) } }
                }
            }
    }

    private func removeButton(_ photo: ComposePhoto) -> some View {
        Button { remove(photo) } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.textPrimary.opacity(0.7))
                .padding(4)
        }
        .buttonStyle(.plain)
        // 썸네일이 사용자 지정 액션으로 같은 동작을 제공하므로 중복 정지점을 만들지 않는다
        .accessibilityHidden(true)
    }

    private func photoStatusText(_ photo: ComposePhoto) -> String {
        if photo.isUploading { return "올리는 중" }
        if let message = photo.errorMessage { return "실패, \(message)" }
        return "업로드 완료"
    }

    /// PhotosPicker가 준 항목을 디코딩 → 다운스케일 → 즉시 업로드까지 밀어 넣는다.
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        isPreparingPhotos = true
        defer { isPreparingPhotos = false }

        for item in items {
            guard photos.count < ReviewDraft.imageLimit else { break }
            guard let raw = try? await item.loadTransferable(type: Data.self) else {
                submitError = "사진을 읽지 못했어요. 다른 사진을 선택해 주세요."
                continue
            }
            // 디코딩·리샘플링은 메인 스레드에서 하면 큰 사진에서 화면이 멈춘다
            let prepared = await Task.detached(priority: .userInitiated) {
                ReviewPhotoEncoder.encode(raw).flatMap { data in
                    UIImage(data: data).map { (data: data, image: $0) }
                }
            }.value
            guard let prepared else {
                submitError = "사진을 처리하지 못했어요. 다른 사진을 선택해 주세요."
                continue
            }

            let photo = ComposePhoto(
                thumbnail: prepared.image, data: prepared.data, isUploading: true
            )
            photos.append(photo)
            await upload(photo.id)
        }
    }

    /// 장별로 한 번씩 올린다. 서버는 한 요청에 5장까지 받지만, 한 장이 실패했을 때
    /// 나머지까지 다시 올리지 않으려면 요청을 쪼개는 편이 낫다.
    private func upload(_ id: ComposePhoto.ID) async {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isUploading = true
        photos[index].errorMessage = nil

        let data = photos[index].data
        do {
            let urls = try await feedService.uploadReviewImages([data])
            guard let uploaded = urls.first else { throw FeedServiceError.imageUploadFailed }
            // await 사이에 사진이 지워졌을 수 있어 인덱스를 다시 찾는다
            guard let current = photos.firstIndex(where: { $0.id == id }) else { return }
            photos[current].uploadedURL = uploaded
            photos[current].isUploading = false
        } catch {
            guard let current = photos.firstIndex(where: { $0.id == id }) else { return }
            photos[current].isUploading = false
            photos[current].errorMessage = (error as? FeedServiceError)?.errorDescription
                ?? "사진을 올리지 못했어요. 네트워크 상태를 확인해 주세요."
            UIAccessibility.post(notification: .announcement, argument: "사진을 올리지 못했어요")
        }
    }

    private func remove(_ photo: ComposePhoto) {
        photos.removeAll { $0.id == photo.id }
    }

    // MARK: - 등록

    private var submitBar: some View {
        VStack(spacing: 8) {
            // 등록 실패 사유가 있으면 그것을 먼저 알린다. 없을 때만 "무엇이 비었는지" 안내를 띄운다
            // (비활성 상태를 회색이라는 색만으로 전달하지 않기 위한 문장이다).
            if let submitError {
                Text(submitError)
                    .font(.notoSans(13))
                    .foregroundStyle(.deepGreen)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let hint = missingHint {
                Text(hint)
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Task { await submit() }
            } label: {
                ZStack {
                    Text("등록하기")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(canSubmit ? .textPrimary : .textSecondary)
                        .opacity(isSubmitting ? 0 : 1)
                    if isSubmitting {
                        ProgressView().tint(.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Capsule().fill(canSubmit ? Color.moduwaGreen : Color.photoPlaceholder))
                // 라임 CTA 그림자는 HeroCard와 같은 값 (활성일 때만)
                .shadow(color: Color(hex: 0x9ACA10).opacity(canSubmit ? 0.3 : 0), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
            .accessibilityLabel(isSubmitting ? "후기 등록 중" : "후기 등록하기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private var trimmedReview: String {
        reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isUploadingPhotos: Bool {
        isPreparingPhotos || photos.contains(where: \.isUploading)
    }

    /// 업로드에 실패한 사진 — 그대로 등록하면 사용자 모르게 사진이 빠진다.
    private var hasFailedPhotos: Bool {
        photos.contains { $0.errorMessage != nil }
    }

    /// 서버도 rating을 1~5 정수로 요구한다 (`invalid_rating`) — 화면 조건과 같다.
    /// 표시 이름이 아직 정해지지 않았다면 입력을 받아야 등록할 수 있다.
    ///  기본 이름을 지어내 등록하면 작성자가 전부 같은 이름이 된다.
    private var needsNickname: Bool {
        savedNickname.isEmpty && nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        rating > 0 && !trimmedReview.isEmpty && !needsNickname && !isUploadingPhotos && !hasFailedPhotos
    }

    /// 등록 조건이 덜 채워졌을 때 보여줄 안내. 채워졌으면 nil.
    /// (비활성 상태를 회색이라는 색만으로 전달하지 않으려고 항상 문장으로 이유를 적는다)
    private var missingHint: String? {
        if isUploadingPhotos { return "사진을 올리는 중이에요" }
        if hasFailedPhotos { return "올리지 못한 사진을 지우거나 다시 올려 주세요" }
        if needsNickname { return "후기에 표시될 이름을 입력하면 등록할 수 있어요" }
        return switch (rating == 0, trimmedReview.isEmpty) {
        case (true, true): "별점과 후기 내용을 입력하면 등록할 수 있어요"
        case (true, false): "별점을 선택하면 등록할 수 있어요"
        case (false, true): "후기 내용을 입력하면 등록할 수 있어요"
        case (false, false): nil
        }
    }

    private func submit() async {
        guard canSubmit, !isSubmitting else { return }

        // 사용자가 정한 이름만 쓴다. 지어낸 기본 이름을 보내면 서버가 이 기기의 기존 닉네임을
        // 그 값으로 덮어쓴다(실제로 프로덕션에서 한 사용자의 닉네임이 이렇게 지워졌다).
        //  저장은 성공한 뒤에 한다 — 실패한 이름을 굳혀 두면 다시 물을 기회가 없다.
        let nickname = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNickname = nickname.isEmpty ? savedNickname : nickname

        let draft = ReviewDraft(
            contentId: contentId,
            placeName: placeName,
            rating: rating,
            body: trimmedReview,
            nickname: resolvedNickname,
            // 서버가 모르는 코드는 400이므로 받아 둔 사전 순서대로 걸러 보낸다.
            //  장소 평가와 방문 조건을 섞어 보낸다 — 서버가 `kind` 로 다시 가른다(상한 13).
            tags: availableTags.map(\.code).filter(selectedTagCodes.contains),
            // ⚠️ 미체크는 false가 아니라 nil이다 — 서버가 미응답으로 저장한다
            wouldRevisit: wantsRevisit ? true : nil,
            imageURLs: photos.compactMap(\.uploadedURL)
        )

        isSubmitting = true
        submitError = nil
        focusedField = nil

        do {
            try await feedService.submitReview(draft)
            // 성공한 뒤에만 기기에 남긴다 — 실패한 이름을 굳혀 두면 다시 물을 기회가 없다.
            savedNickname = resolvedNickname
            // 서버는 받은 이름으로 **계정 닉네임을 갱신한다.** 그 사실을 계정 화면에도 반영한다 —
            //  한 곳만 고치면 마이페이지에 옛 이름이 남는다.
            session.noteNicknameChanged(resolvedNickname)
            // 성공했을 때만 호출부에 알린다 — 실패한 후기를 목록에 끼워 넣으면 안 된다.
            onSubmit(draft)
            // 화면이 닫히면 포커스가 이전 화면으로 돌아가 등록 결과를 놓치므로 직접 알린다.
            UIAccessibility.post(notification: .announcement, argument: "후기를 등록했어요")
            dismiss()
        } catch {
            isSubmitting = false
            // URLError 등 시스템 오류의 영어 문구가 새지 않게, 서버가 준 한국어 사유만 그대로 쓴다.
            let message = (error as? FeedServiceError)?.errorDescription
                ?? "후기를 등록하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            submitError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // MARK: - 공통

    private func sectionTitle(_ text: String, isRequired: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.notoSans(18, .bold))
                .foregroundStyle(.textPrimary)
                .tracking(-0.4)

            // 필수 여부도 색이 아니라 "필수"라는 글자로 전달한다.
            if isRequired {
                Text("필수")
                    .font(.notoSans(12, .medium))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.moduwaGreen.opacity(0.3)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.cardStroke)
            .frame(height: 1)
            .padding(.vertical, 24)
            .accessibilityHidden(true)
    }
}

#Preview("후기 쓰기") {
    ReviewComposeView(
        placeName: "국립중앙박물관",
        placeAddress: "서울특별시 용산구 서빙고로 137",
        contentId: "126508"
    )
}

#Preview("큰 글자 (AX3)") {
    ReviewComposeView(
        placeName: "국립중앙박물관",
        placeAddress: "서울특별시 용산구 서빙고로 137",
        contentId: "126508"
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
