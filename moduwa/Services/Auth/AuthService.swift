import SwiftUI

/// 계정 창구 (`/v1/auth/*`).
///
/// 소셜은 프로바이더마다 "토큰을 받아 오는 방법"만 다르고, 서버에 넘긴 뒤는 전부 같다.
/// 애플·카카오·네이버를 붙일 때도 메서드 하나가 늘어날 뿐이다.
/// (애플은 서버 라우트가 이미 있지만 앱에는 없다 — Sign in with Apple 은 유료 멤버십이
/// 있어야 켤 수 있는 기능이라, 멤버십이 생기면 여기에 `signInWithApple` 이 붙는다.)
protocol AuthService: Sendable {
    /// 이메일 가입. 성공하면 **인증 코드 메일이 자동으로 한 번 발송된다** —
    /// 호출부는 인증코드 입력 화면으로 이어 준다.
    /// - Parameter accessFeatures: 온보딩에서 고른 무장애 항목. **가입할 때만 반영된다**
    ///   (로그인에서도 덮으면 앱을 지웠다 깐 기기로 로그인하는 것만으로 사용자가 직접
    ///   고친 프로필이 온보딩 기본값으로 되돌아간다). 온보딩을 하지 않았으면 `nil` —
    ///   빈 배열은 "아무것도 고르지 않았다"는 다른 뜻이다.
    func signUp(
        email: String, password: String, nickname: String?, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession

    func signIn(email: String, password: String) async throws -> AuthSession

    /// 구글 로그인 — 앱이 받아 온 `id_token` 을 서버에 넘긴다(`POST /v1/auth/google`).
    ///
    /// **가입과 로그인이 한 길이다.** 처음 온 신원이면 서버가 계정을 만들고 `created == true`
    /// 로 답한다 — 소셜은 계정이 있는지를 사용자가 알 필요가 없고, 묻는 화면을 두면 이미
    /// 가입한 사람이 가입 버튼을 눌러 실패하는 길만 생긴다.
    /// - Parameter accessFeatures: 이메일 가입과 같은 규칙 — **계정을 만들 때만** 반영된다.
    ///   온보딩을 하지 않았으면 `nil`(빈 배열과 다른 뜻이다).
    func signInWithGoogle(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession

    /// 로그아웃. 서버에서 토큰을 폐기하고 이 기기의 계정 바인딩을 끊는다.
    /// 요청이 실패해도 호출부는 기기에서 토큰을 지운다 — 남기면 로그아웃이 되지 않는다.
    func signOut() async throws

    /// 카카오 로그인 — 앱이 받아 온 **OIDC ID 토큰**을 넘긴다(`POST /v1/auth/kakao`).
    ///
    /// 구글과 같은 규칙이다(가입·로그인이 한 길, `accessFeatures` 는 계정을 만들 때만).
    /// 닉네임은 토큰에 들어 있어 따로 보내지 않는다.
    ///
    /// ⚠️ 카카오는 이메일을 **인증된 것으로 표시하지 않는다** — 토큰에 `email_verified` 에
    /// 해당하는 클레임이 없고 카카오계정에는 미인증 주소가 있을 수 있다. 그래서 카카오로
    /// 가입해도 앱은 이메일 인증(6자리 코드)을 권한다.
    func signInWithKakao(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession

    /// 무장애 프로필을 바꾼다(`PATCH /v1/auth/me`).
    ///
    /// 가입 때 한 번 정하고 끝낼 값이 아니다 — 다치거나 회복하거나 아이가 크면 필요한 것이
    /// 바뀐다. **빈 배열도 유효한 선택이다**("지금은 필요한 것이 없다").
    /// - Returns: 갱신된 계정. 화면이 다시 조회하지 않아도 되게 서버가 그대로 돌려준다.
    func updateAccessFeatures(_ features: [AccessibilityFeature]) async throws -> Account

    /// 프로필 부분 갱신 (`PATCH /v1/auth/me`).
    ///
    /// **온 키만 바뀐다** — `nil` 을 넘긴 값은 서버가 건드리지 않는다. 그래서 닉네임만 바꾸는
    /// 요청은 무장애 항목도, 온보딩 상태도 손대지 않는다(서버는 `accessFeatures` 가 올 때만
    /// `onboarded` 를 켠다).
    /// - Parameters:
    ///   - nickname: 앞뒤 공백은 서버가 턴다. **빈 문자열은 오류**(400 `invalid_nickname`) —
    ///     "지우기"가 아니다. 40자 초과도 같은 오류다.
    ///   - avatar: `.set` 은 사진 지정, `.clear` 는 사진 제거. `nil` 이면 사진을 건드리지 않는다.
    ///     URL 은 **https** 여야 한다(서버가 http 를 400 으로 막는다 — ATS 때문에 저장돼도 안 보인다).
    /// - Returns: 갱신된 계정. 앱은 이 값으로 화면을 갈아 끼운다(재조회하지 않는다).
    func updateProfile(nickname: String?, avatar: AvatarUpdate?) async throws -> Account

    /// 저장해 둔 토큰이 아직 쓸 수 있는지 확인하며 계정을 받아 온다(앱 기동 시).
    /// 만료·폐기된 토큰이면 `.sessionExpired` 를 던진다.
    func currentAccount() async throws -> Account

    /// 인증 코드 재발송. 가입 시 자동으로 한 번 가지만 못 받았을 때 쓴다.
    /// - Returns: 이미 인증된 계정이면 `true`(메일을 보내지 않았다).
    func resendVerificationCode() async throws -> Bool

    /// 이메일 인증 — 메일로 받은 6자리 숫자.
    func verifyEmail(code: String) async throws

    /// 비밀번호 찾기. **가입 여부를 알려주지 않는다** — 없는 주소도 성공으로 응답한다
    /// (응답이 갈리면 그것만으로 가입된 이메일 목록을 만들 수 있다).
    func requestPasswordReset(email: String) async throws

    /// 비밀번호 재설정. 성공하면 **그 계정의 모든 세션이 끊긴다** — 호출부는 로그인 화면으로 보낸다.
    func resetPassword(email: String, code: String, newPassword: String) async throws
}

extension EnvironmentValues {
    @Entry var authService: any AuthService = MockAuthService()
}

/// 프리뷰 전용 — 서버를 부르지 않는다.
struct MockAuthService: AuthService {
    /// 프리뷰가 로그인 성공/실패를 둘 다 그려 볼 수 있게.
    var failure: AuthError?

    private func account(_ email: String) -> Account {
        Account(uuid: UUID().uuidString, nickname: "여행자", email: email,
                emailVerified: false, accessFeatures: [], onboarded: true)
    }

    func signUp(
        email: String, password: String, nickname: String?, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        if let failure { throw failure }
        return AuthSession(token: "preview", expiresAt: nil, account: account(email), created: true)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        if let failure { throw failure }
        return AuthSession(token: "preview", expiresAt: nil, account: account(email), created: false)
    }

    func signInWithGoogle(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        if let failure { throw failure }
        return AuthSession(token: "preview", expiresAt: nil,
                           account: account("preview@gmail.com"), created: true)
    }

    func signInWithKakao(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        if let failure { throw failure }
        return AuthSession(token: "preview", expiresAt: nil,
                           account: account("preview@kakao.com"), created: true)
    }

    func signOut() async throws {}

    func currentAccount() async throws -> Account {
        if let failure { throw failure }
        return account("preview@moduwa.app")
    }

    func updateAccessFeatures(_ features: [AccessibilityFeature]) async throws -> Account {
        if let failure { throw failure }
        var updated = account("preview@moduwa.app")
        updated.accessFeatures = features
        updated.onboarded = true
        return updated
    }

    func updateProfile(nickname: String?, avatar: AvatarUpdate?) async throws -> Account {
        if let failure { throw failure }
        // 프리뷰는 상태를 들지 않는다 — 넘어온 값이 반영된 모습만 돌려준다.
        var updated = account("preview@moduwa.app")
        if let nickname { updated.nickname = nickname }
        switch avatar {
        case .set(let url): updated.avatarURL = url
        case .clear: updated.avatarURL = nil
        case nil: break
        }
        return updated
    }

    func resendVerificationCode() async throws -> Bool { false }
    func verifyEmail(code: String) async throws { if let failure { throw failure } }
    func requestPasswordReset(email: String) async throws {}
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        if let failure { throw failure }
    }
}
