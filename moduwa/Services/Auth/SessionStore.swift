import SwiftUI

/// 로그인 상태를 앱 전체가 함께 보는 곳.
///
/// 토큰 자체는 `SessionTokenStore`(키체인)에 있고 여기서는 **화면이 그리는 사실**을 쥔다 —
/// 지금 누구인지, 로그인 창을 띄워야 하는지, 부팅 확인이 끝났는지.
///
/// `SavedPlacesStore` 와 같은 이유로 한 개만 둔다: 로그인·로그아웃은 한 화면의 사건이 아니라
/// **앱 전체가 따라야 하는 사건**이다. 화면마다 상태를 따로 들면 로그아웃 직후 어떤 탭은
/// 이전 계정 데이터를 계속 보여 준다.
@MainActor
@Observable
final class SessionStore {
    /// 부팅 확인 단계. `.checking` 동안은 로그인·비로그인을 단정하지 않는다 —
    /// 단정하면 앱을 켤 때마다 로그인 화면이 한 번 번쩍인다.
    enum Phase: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .checking
    private(set) var account: Account?

    /// 로그인 시트를 띄울 이유. 쓰기 진입점이 비로그인일 때 채운다.
    /// `nil` 이면 시트를 닫는다.
    var prompt: AuthPrompt?

    /// 이메일 인증을 아직 안 마쳤는지. 가입 직후 인증 화면으로 이어 줄 때 쓴다.
    var needsEmailVerification: Bool {
        guard let account else { return false }
        return account.email != nil && !account.emailVerified
    }

    private let service: any AuthService

    init(service: any AuthService) {
        self.service = service
        observeExpiry()
    }

    // MARK: - 부팅

    /// 저장된 토큰이 아직 쓸 수 있는지 확인한다. 앱 기동 시 한 번.
    ///
    /// 실패를 로그아웃으로 단정하지 않는다 — 네트워크가 죽은 것과 토큰이 폐기된 것은 다르고,
    /// 비행기에서 앱을 켰다고 로그아웃시키면 안 된다. 서버가 만료를 명확히 알려 준
    /// 경우(`sessionExpired`)에만 지운다.
    func bootstrap() async {
        guard SessionTokenStore.shared.hasToken else {
            phase = .signedOut
            return
        }
        do {
            let fetched = try await service.currentAccount()
            account = fetched
            phase = .signedIn
            mirrorNickname(fetched.nickname)
            // 저장된 토큰으로 돌아온 것도 "로그인" 이다 — 기기 토큰을 다시 등록해 둔다.
            PushRegistrar.shared.registerAfterSignIn()
        } catch AuthError.sessionExpired, AuthError.loginRequired {
            SessionTokenStore.shared.clear()
            account = nil
            phase = .signedOut
        } catch {
            // 토큰은 남아 있다. 다음 요청이 다시 확인한다.
            phase = SessionTokenStore.shared.hasToken ? .signedIn : .signedOut
        }
    }

    // MARK: - 가입 · 로그인 · 로그아웃

    /// 가입. 무장애 항목을 계정으로 옮겼으면 기기에 있던 온보딩 값을 지운다.
    ///
    /// - Parameter sensitiveConsent: 무장애 항목을 계정에 저장해도 되는지(`AuthConsent.sensitive`).
    ///   **동의가 없으면 요청에 싣지 않는다** — 무장애 항목은 건강·장애 상태를 드러내는
    ///   민감정보라서 개인정보 동의로 갈음할 수 없고, 별도 동의가 있어야 보낼 수 있다.
    ///   거부한 값은 기기에 남아 있다가 나중에 동의를 받으면 올라간다
    ///   (`AccessibilityProfileEditView` 의 `SensitiveConsentGate`).
    @discardableResult
    func signUp(email: String, password: String, nickname: String?,
                sensitiveConsent: Bool) async throws -> AuthSession {
        // 동의는 이 화면에서 방금 받은 것이다 — 기기에 적어 두지 않고 요청에 그대로 싣는다.
        //  기록은 서버가 남긴다(`sensitive_consent_at`, 050).
        //  ⚠️ 온보딩을 하지 않았으면 nil 이다 — 빈 배열을 보내면 서버가 "온보딩을 마쳤고
        //   아무것도 고르지 않았다"로 기록한다(`AuthService` 주석).
        let features = sensitiveConsent ? OnboardingProfileStore.shared.selectionForSignUp : nil
        let result = try await service.signUp(
            email: email, password: password, nickname: nickname, accessFeatures: features)
        adopt(result)
        if features != nil { OnboardingProfileStore.shared.markHandedToAccount() }
        return result
    }

    /// 구글 로그인. 브라우저 시트를 띄워 `id_token` 을 받고 서버에 넘긴다.
    ///
    /// 가입·로그인이 한 길이라 결과의 `created` 로 갈린다 — 새 계정일 때만 온보딩 값을
    /// 계정으로 넘긴 것으로 처리한다(기존 계정이면 서버가 그 값을 무시했다).
    ///
    /// ⚠️ **소셜 로그인은 동의 화면을 지나지 않으므로 무장애 항목을 싣지 않는다.**
    /// 여기서 실어 보내면 동의 없이 민감정보를 수집하는 것이 된다(서버도 400 으로 막는다).
    /// 항목은 기기에 남았다가 설정에서 동의를 받은 뒤 올라간다(`AccessibilityProfileEditView`).
    @discardableResult
    func signInWithGoogle() async throws -> AuthSession {
        let idToken = try await GoogleSignInFlow().idToken()
        let result = try await service.signInWithGoogle(
            idToken: idToken, accessFeatures: nil)
        adopt(result)
        return result
    }

    /// 애플 로그인. 창을 띄우는 일은 버튼(`SignInWithAppleButton`)이 하고, 여기는 그 결과만 받는다.
    /// - Parameter credential: `AppleSignInFlow.credential(from:)` 이 파싱한 값.
    @discardableResult
    func signInWithApple(_ credential: AppleSignInFlow.Credential) async throws -> AuthSession {
        let result = try await service.signInWithApple(
            idToken: credential.idToken, nickname: credential.nickname,
            authorizationCode: credential.authorizationCode,
            accessFeatures: nil)
        adopt(result)
        return result
    }

    /// 카카오 로그인. 카카오톡이 깔려 있으면 앱으로 전환된다(`KakaoSignInFlow`).
    @discardableResult
    func signInWithKakao() async throws -> AuthSession {
        let idToken = try await KakaoSignInFlow.idToken()
        let result = try await service.signInWithKakao(
            idToken: idToken, accessFeatures: nil)
        adopt(result)
        return result
    }

    /// - Parameter keepSignedIn: 시안 868:773 "로그인 상태 유지". 껐으면 토큰을 키체인에
    ///   남기지 않아 앱을 다시 켜면 비로그인이다(`SessionTokenStore.save(_:persist:)`).
    ///   **가입·소셜은 이 선택을 묻지 않는다** — 시안에도 그 자리에 체크박스가 없고,
    ///   방금 계정을 만든 사람을 다음 실행에서 로그아웃시킬 이유가 없다.
    @discardableResult
    func signIn(email: String, password: String, keepSignedIn: Bool = true) async throws -> AuthSession {
        let result = try await service.signIn(email: email, password: password)
        adopt(result, persist: keepSignedIn)
        return result
    }

    /// 로그아웃. **서버 요청이 실패해도 기기에서는 나간다** —
    /// 남기면 사용자는 로그아웃을 눌렀는데 계정 데이터가 계속 보인다.
    func signOut() async {
        // ⚠️ **기기 토큰을 먼저 지운다.** 세션 토큰이 사라진 뒤에는 401 이라 지울 수 없고,
        //  남겨 두면 로그아웃한 사람의 기기로 알림이 계속 간다(서버가 토큰에 계정을 묶는다).
        await PushRegistrar.shared.unregisterBeforeSignOut()
        try? await service.signOut()
        SessionTokenStore.shared.clear()
        account = nil
        phase = .signedOut
        mirrorNickname(nil)
        onSignedOut?()
    }

    /// 계정 삭제. **되돌릴 수 없다** — 부르기 전에 사용자에게 물어야 한다(`AccountDeleteView`).
    ///
    /// 로그아웃과 달리 기기 토큰을 먼저 지우지 않는다 — 서버가 삭제 트랜잭션에서 지운다.
    /// 성공하면 로그아웃과 **같은 뒷정리**를 한다(토큰·계정·화면 상태).
    func deleteAccount() async throws {
        try await service.deleteAccount()
        SessionTokenStore.shared.clear()
        account = nil
        phase = .signedOut
        mirrorNickname(nil)
        onSignedOut?()
    }

    /// 로그아웃 직후 앱이 비워야 하는 것들(저장 탭·플랜 탭 등)을 여기에 등록한다.
    /// `RootView` 가 한 번 꽂아 둔다 — 세션이 화면을 직접 알면 의존이 거꾸로 흐른다.
    var onSignedOut: (() -> Void)?

    /// 사용자가 **글을 쓰면서 표시 이름을 바꿨다.** 서버는 `authorNm` 을 받으면 계정 닉네임을
    /// 갱신하므로, 그 사실을 앱의 두 곳(메모리의 계정, 입력칸 기본값)에 함께 반영한다.
    ///
    /// 한 곳만 고치면 어긋난다 — 후기에서 이름을 바꿨는데 마이페이지에는 옛 이름이 남는다.
    func noteNicknameChanged(_ nickname: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        account?.nickname = trimmed
        UserDefaults.standard.set(trimmed, forKey: ReviewAuthorStore.nicknameKey)
    }

    // MARK: - 무장애 프로필

    /// **지금 유효한 무장애 요소.** 앱 전체가 이 하나를 본다.
    ///
    /// 로그인했으면 계정 값이고, 아니면 기기에 있는 온보딩 값이다. 규칙을 여기 한 곳에 두는
    /// 이유: 화면마다 `account?.accessFeatures ?? []` 를 쓰면 비로그인 사용자가 온보딩에서 고른
    /// 것이 **아무 데도 반영되지 않는다** — 실제로 그랬다. 고르라고 해 놓고 쓰지 않는 것은
    /// 무장애 앱에서 특히 나쁜 배신이다.
    /// ⚠️ 계정이 **빈 값**일 때도 기기 값을 본다. 소셜 로그인으로 만든 계정에는 무장애 항목이
    /// 올라가지 않으므로(민감정보 동의 전), 계정 값만 보면 온보딩에서 고른 것이 로그인하는
    /// 순간 사라진다. 계정에 저장에 성공하면 기기 값을 비우니(`updateAccessFeatures`)
    /// "다 해제했는데 옛 값이 돌아온다"는 일은 생기지 않는다.
    var accessFeatures: [AccessibilityFeature] {
        if let mine = account?.accessFeatures, !mine.isEmpty { return mine }
        return OnboardingProfileStore.shared.features
    }

    /// 무장애 요소를 바꾼다. **로그인하지 않아도 된다.**
    ///
    /// 로그인 상태면 계정에 저장하고(기기를 바꿔도 따라온다), 아니면 기기에 남긴다 —
    /// 그 값은 나중에 가입할 때 계정으로 올라간다(`OnboardingProfileStore`).
    /// 어느 쪽이든 이 값을 보는 화면(홈 히어로 카드·추천 목록)이 곧바로 따라 바뀐다.
    func updateAccessFeatures(_ features: [AccessibilityFeature]) async throws {
        guard account != nil else {
            OnboardingProfileStore.shared.finish(features)
            return
        }
        account = try await service.updateAccessFeatures(features)
        // 계정이 정본이 됐다 — 기기에 남은 온보딩 값은 지운다(`accessFeatures` 주석).
        OnboardingProfileStore.shared.markHandedToAccount()
    }

    // MARK: - 프로필

    /// 닉네임·프로필 사진을 고친다 (`PATCH /v1/auth/me` 부분 갱신).
    ///
    /// 로그인 상태에서만 부른다 — 계정이 없으면 저장할 곳이 없다(온보딩 값과 달리 기기에
    /// 남겨 둘 자리가 없고, 남에게 보이는 값이라 계정에 있어야 뜻이 있다).
    ///
    /// 닉네임이 바뀌면 작성 화면의 표시 이름(`ReviewAuthorStore`)까지 함께 맞춘다 —
    /// 한 곳만 고치면 프로필에서 바꾼 이름과 글에 붙는 이름이 갈린다.
    func updateProfile(nickname: String? = nil, avatar: AvatarUpdate? = nil) async throws {
        guard account != nil else { throw AuthError.loginRequired }
        let updated = try await service.updateProfile(nickname: nickname, avatar: avatar)
        account = updated
        mirrorNickname(updated.nickname)
    }

    // MARK: - 이메일 인증

    /// - Returns: 이미 인증된 계정이면 `true`.
    func resendVerificationCode() async throws -> Bool {
        let already = try await service.resendVerificationCode()
        if already { markEmailVerified() }
        return already
    }

    func verifyEmail(code: String) async throws {
        try await service.verifyEmail(code: code)
        markEmailVerified()
    }

    private func markEmailVerified() {
        account?.emailVerified = true
    }

    // MARK: - 비밀번호 찾기

    func requestPasswordReset(email: String) async throws {
        try await service.requestPasswordReset(email: email)
    }

    /// 재설정 성공. 서버가 **모든 세션을 끊었으므로** 이 기기도 로그아웃 상태가 된다.
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        try await service.resetPassword(email: email, code: code, newPassword: newPassword)
        SessionTokenStore.shared.clear()
        account = nil
        phase = .signedOut
        mirrorNickname(nil)
        onSignedOut?()
    }

    // MARK: - 로그인 게이트

    /// 쓰기 진입점이 부르는 관문. 로그인돼 있으면 `true`, 아니면 **로그인 시트를 띄우고** `false`.
    ///
    /// 서버 401 을 기다리지 않고 앱에서 먼저 막는 이유: 사용자가 글을 다 쓴 뒤에 로그인 창을
    /// 만나면 쓴 것을 잃을까 불안해진다. 들어가는 문에서 묻는 편이 낫다.
    /// (그래도 서버 401 처리는 남겨 둔다 — 토큰이 요청 도중 만료될 수 있다.)
    func requireSignIn(_ reason: AuthPrompt) -> Bool {
        if phase == .signedIn, account != nil { return true }
        prompt = reason
        return false
    }

    // MARK: - 내부

    /// 로그인·가입 성공을 받아들인다.
    ///
    /// ⚠️ 여기서 `prompt` 를 비우지 않는다 — 비우면 시트가 즉시 닫혀서, 가입 직후에 이어야 하는
    /// **인증코드 화면으로 갈 자리가 없어진다.** 닫는 시점은 화면이 정한다.
    private func adopt(_ result: AuthSession, persist: Bool = true) {
        SessionTokenStore.shared.save(result.token, persist: persist)
        account = result.account
        phase = .signedIn
        mirrorNickname(result.account.nickname)
        // **로그인할 때마다** 기기 토큰을 다시 등록한다(서버 요청). 한 기기를 다른 계정으로
        //  로그인하면 소유자가 바뀌어야 하고, 안 그러면 앞사람에게 알림이 계속 간다.
        //  저장된 토큰으로 돌아오는 길(`bootstrap`)에도 같은 호출이 있다.
        PushRegistrar.shared.registerAfterSignIn()
    }

    /// 계정 닉네임을 작성 화면의 입력칸 기본값(`@AppStorage`)에 비춘다.
    ///
    /// 작성 화면들은 이 값이 비어 있으면 "표시될 이름을 입력해 주세요"를 강제하는데, 로그인
    /// 계정에는 가입 때 정해진 닉네임이 **항상** 있으므로 다시 물을 이유가 없다.
    /// 로그아웃하면 지운다 — 다음 사람의 입력칸에 남의 이름이 미리 채워져 있으면 안 된다.
    private func mirrorNickname(_ nickname: String?) {
        if let nickname, !nickname.isEmpty {
            UserDefaults.standard.set(nickname, forKey: ReviewAuthorStore.nicknameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ReviewAuthorStore.nicknameKey)
        }
    }

    /// 서버가 만료를 알려 온 순간(어느 서비스의 요청이든) 화면을 로그아웃 상태로 되돌린다.
    private func observeExpiry() {
        let expiry = NotificationCenter.default
            .notifications(named: SessionTokenStore.didExpireNotification)
            .map { _ in () } // Notification 을 경계 밖으로 넘기지 않는다
        Task { [weak self] in
            for await _ in expiry {
                guard let self else { return }
                self.account = nil
                self.phase = .signedOut
                self.prompt = .sessionExpired
                self.mirrorNickname(nil)
                self.onSignedOut?()
            }
        }
    }
}

/// 로그인 시트를 띄운 이유. 시트 상단 문구가 이 값을 그린다 —
/// "로그인이 필요해요"만 띄우면 사용자는 자기가 무엇을 하려던 중인지 다시 떠올려야 한다.
enum AuthPrompt: Identifiable, Hashable {
    /// 계정 화면에서 직접 들어온 경우(이유 문구 없음)
    case direct
    case writePost
    case writeReview
    case comment
    case like
    case save
    case plan
    /// 홈 카드에서 "로그인하기"를 직접 누른 경우
    case recommendation
    /// 토큰이 만료돼 쫓겨난 경우
    case sessionExpired

    var id: Self { self }

    var message: String? {
        switch self {
        case .direct: nil
        case .writePost: "게시글을 쓰려면 로그인이 필요해요."
        case .writeReview: "후기를 남기려면 로그인이 필요해요."
        case .comment: "댓글을 쓰려면 로그인이 필요해요."
        case .like: "좋아요를 누르려면 로그인이 필요해요."
        case .save: "장소를 저장하려면 로그인이 필요해요."
        case .plan: "플랜을 만들려면 로그인이 필요해요."
        case .recommendation: "로그인하면 나에게 맞는 여행을 추천해 드려요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        }
    }
}
