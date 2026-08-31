import PhotosUI
import SwiftUI

/// 프로필 편집 — 사진과 닉네임을 고친다. 설정 화면(977:662)의 **이름 옆 연필**에서 들어온다.
///
/// **시안이 없다.** 설정 화면의 값(좌우 36, 아바타 100, 이름 Bold 20)과 로그인 계열 폼
/// (`AuthField`·`AuthPrimaryButton`)을 그대로 써서 두 화면이 이어지게 만들었다.
///
/// 저장은 **한 번의 `PATCH /v1/auth/me`** 다(부분 갱신) — 사진과 닉네임을 따로 저장하면
/// 한쪽만 성공한 상태가 생기고, 사용자는 무엇이 저장됐는지 알 수 없다.
/// 사진은 후기·게시글과 **같은 경로**로 올린다(`ReviewPhotoEncoder` 로 장변 1280·q0.8 로 줄여
/// `POST /v1/reviews/images`) — 서버가 파일명을 내용의 sha256 으로 정해 경로 접두사가 뜻을
/// 갖지 않으므로, 아바타 전용 업로드를 한 벌 더 두는 것보다 재사용이 낫다.
///
/// 로그아웃·이메일 인증·비밀번호 변경은 계정을 다루는 일이라 **여기 아래 줄**에서 이어진다
/// (`AccountInfoView`). 설정 시안의 다섯 줄에는 그 자리가 없고, 빼면 로그아웃할 길이 사라진다.
struct ProfileEditView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss

    /// 회원정보 수정으로 들어간 뒤 그 안에서 이어지는 화면들.
    private enum SubRoute: Hashable, Identifiable {
        case accountInfo, verifyEmail, resetPassword

        var id: Self { self }
    }

    @State private var route: SubRoute?
    @State private var nickname: String = ""
    /// 고른 사진. 미리보기(썸네일)와 올릴 바이트를 함께 든다 — 작성 화면의 `ComposePhoto` 와 같은 방식.
    @State private var picked: (thumbnail: UIImage, data: Data)?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isPreparingPhoto = false
    /// 사진을 지우기로 했다. **"고르지 않음"과 다른 뜻이다** — 서버도 그렇게 가른다(`AvatarUpdate`).
    @State private var clearsPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let inset: CGFloat = 36
    /// 서버 상한과 같다(`MAX_NICKNAME_LENGTH`).
    private static let nicknameLimit = 40

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 저장할 것이 있는지. 사진과 닉네임 어느 쪽이든 바뀌면 저장이 열린다.
    private var hasChanges: Bool {
        picked != nil || clearsPhoto || trimmedNickname != (session.account?.nickname ?? "")
    }

    private var isNicknameValid: Bool {
        !trimmedNickname.isEmpty && trimmedNickname.count <= Self.nicknameLimit
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    photoBlock
                    nicknameBlock
                    AuthErrorLine(message: errorMessage)
                    accountInfoRow
                }
                .padding(.horizontal, Self.inset)
                .padding(.top, 28)
                .padding(.bottom, Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationDestination(item: $route) { destination($0) }
        // 화면에 들어올 때 지금 값으로 채운다. 계정이 늦게 도착해도(부팅 확인 중) 따라오게
        //  `task(id:)` 로 둔다 — `onAppear` 한 번이면 빈 칸으로 남는다.
        .task(id: session.account?.nickname) {
            if trimmedNickname.isEmpty { nickname = session.account?.nickname ?? "" }
        }
        .onChange(of: photoSelection) { _, items in
            guard let item = items.first else { return }
            photoSelection = []
            Task { await prepare(item) }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.textPrimary)
            }
            .accessibilityLabel("뒤로 가기")

            Text("프로필 편집")
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 사진

    private var photoBlock: some View {
        VStack(spacing: Spacing.m) {
            avatar

            HStack(spacing: Spacing.s) {
                PhotosPicker(
                    selection: $photoSelection,
                    maxSelectionCount: 1,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    pill(isPreparingPhoto ? "불러오는 중…" : "사진 변경")
                }
                .disabled(isPreparingPhoto || isSaving)

                // 올릴 사진도, 계정에 있는 사진도 없으면 지울 것이 없다.
                if picked != nil || (session.account?.avatarURL != nil && !clearsPhoto) {
                    Button {
                        picked = nil
                        clearsPhoto = session.account?.avatarURL != nil
                    } label: {
                        pill("사진 삭제")
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
            }

            Text("정사각형으로 보여드려요. 올린 사진은 내 게시글·후기에서 다른 사람에게도 보여요.")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// 지금 보여 줄 아바타 — 고른 사진 > 계정 사진 > 라임 원(무장애 뱃지).
    /// 설정 화면과 **같은 지름 100**이라 두 화면 사이에서 크기가 튀지 않는다.
    private var avatar: some View {
        let feature = session.accessFeatures.first ?? .wheelchairAccessible
        let size = feature.iconSize(height: 19)
        return Group {
            if let picked {
                Image(uiImage: picked.thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if let url = session.account?.avatarURL, !clearsPhoto {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.photoPlaceholder
                }
            } else {
                Color.moduwaGreen.opacity(0.3)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.deepGreen)
                .frame(width: 37, height: 37)
                .overlay {
                    Image(feature.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .foregroundStyle(.white)
                }
        }
        .accessibilityElement()
        .accessibilityLabel(hasPhoto ? "프로필 사진" : "프로필 사진 없음")
    }

    private var hasPhoto: Bool {
        picked != nil || (session.account?.avatarURL != nil && !clearsPhoto)
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.notoSans(14, .medium, relativeTo: .subheadline))
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(Capsule().fill(Color.photoPlaceholder))
    }

    // MARK: - 닉네임

    private var nicknameBlock: some View {
        AuthField(
            title: "닉네임",
            placeholder: "글에 보일 이름",
            text: $nickname,
            submitLabel: .done,
            // 비어 있는 칸을 처음부터 빨갛게 두지 않는다 — 지웠을 때만 알린다.
            hasError: !nickname.isEmpty && !isNicknameValid
        )
    }

    // MARK: - 계정

    /// 로그아웃·이메일 인증·비밀번호 변경으로 가는 줄. 설정 시안에 자리가 없어 여기 둔다.
    private var accountInfoRow: some View {
        Button { route = .accountInfo } label: {
            HStack {
                Text("회원정보 수정")
                    .font(.notoSans(16, .medium, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.textSecondary)
            }
            .frame(minHeight: 65)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.photoPlaceholder).frame(height: 1)
        }
    }

    private var saveBar: some View {
        AuthPrimaryButton(
            title: "저장",
            isEnabled: hasChanges && isNicknameValid && !isPreparingPhoto,
            isBusy: isSaving
        ) {
            Task { await save() }
        }
        .padding(.horizontal, Self.inset)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 목적지

    @ViewBuilder
    private func destination(_ route: SubRoute) -> some View {
        switch route {
        case .accountInfo:
            AccountInfoView(
                // 로그아웃했으면 프로필을 고칠 계정이 없다 — 이 화면도 함께 닫는다.
                onSignedOut: { self.route = nil; dismiss() },
                onVerifyEmail: { self.route = .verifyEmail },
                onChangePassword: { self.route = .resetPassword }
            )
        case .verifyEmail:
            EmailVerifyCodeView { self.route = .accountInfo }
        case .resetPassword:
            PasswordResetView { _ in
                // 서버가 모든 세션을 끊었다 — 이 기기도 로그아웃 상태다.
                self.route = nil
                dismiss()
            }
        }
    }

    // MARK: - 동작

    /// 고른 사진을 올릴 수 있는 모양으로 만든다(디코딩 → 장변 1280·q0.8 JPEG).
    /// **여기서 올리지는 않는다** — 저장을 누르지 않고 나가면 서버에 쓰레기가 남는다.
    private func prepare(_ item: PhotosPickerItem) async {
        isPreparingPhoto = true
        errorMessage = nil
        defer { isPreparingPhoto = false }

        guard let raw = try? await item.loadTransferable(type: Data.self),
              let encoded = ReviewPhotoEncoder.encode(raw),
              let thumbnail = UIImage(data: encoded)
        else {
            errorMessage = "사진을 불러오지 못했어요. 다른 사진을 골라 주세요."
            return
        }
        picked = (thumbnail, encoded)
        clearsPhoto = false
    }

    private func save() async {
        guard hasChanges, isNicknameValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            // 사진을 새로 골랐으면 먼저 올려 URL 을 얻는다. 실패하면 닉네임도 저장하지 않는다 —
            //  절반만 저장되면 사용자는 무엇이 반영됐는지 알 수 없다.
            var avatar: AvatarUpdate?
            if let picked {
                let urls = try await feedService.uploadReviewImages([picked.data])
                guard let url = urls.first else {
                    errorMessage = "사진을 올리지 못했어요. 잠시 후 다시 시도해 주세요."
                    return
                }
                avatar = .set(url)
            } else if clearsPhoto {
                avatar = .clear
            }

            let newNickname = trimmedNickname == (session.account?.nickname ?? "")
                ? nil : trimmedNickname
            try await session.updateProfile(nickname: newNickname, avatar: avatar)
            UIAccessibility.post(notification: .announcement, argument: "저장했어요")
            dismiss()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "저장하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview("프로필 편집") {
    NavigationStack {
        ProfileEditView()
    }
    .environment(SessionStore(service: MockAuthService()))
}
