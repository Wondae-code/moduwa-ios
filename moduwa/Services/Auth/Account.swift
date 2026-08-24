import Foundation

/// 로그인한 계정. 서버 `/v1/auth/*` 응답의 `author` 와 같은 모양이다.
///
/// ⚠️ 토큰은 여기 없다 — 자격증명은 `SessionTokenStore`(키체인)에만 둔다. 계정 정보는 화면이
/// 그리는 값이라 메모리에 두고 앱을 켤 때 `GET /v1/auth/me` 로 다시 받는다.
struct Account: Identifiable, Hashable, Sendable {
    /// 서버가 외부에 노출하는 유일한 식별자(authors.id 는 나오지 않는다).
    let uuid: String
    var nickname: String
    var email: String?
    /// 이메일 인증을 마쳤는지. 가입 직후에는 `false` 다 — 앱이 인증 코드 화면으로 이어 준다.
    var emailVerified: Bool
    /// 온보딩에서 고른 무장애 항목. **앱이 모르는 코드는 버린다** —
    /// 서버가 값을 검증하지 않으므로(앱이 항목을 늘리면 서버 배포 없이 따라간다) 옛 앱에
    /// 모르는 코드가 내려올 수 있다.
    var accessFeatures: [AccessibilityFeature]
    /// 온보딩을 마쳤는지. **빈 `accessFeatures` 와 다른 뜻이다** —
    /// "아무것도 고르지 않았다"와 "온보딩을 안 했다"를 구분해야 온보딩을 다시 띄울지 알 수 있다.
    var onboarded: Bool

    var id: String { uuid }
}

/// 로그인·가입 실패 사유 중 **화면이 분기해야 하는** 것들.
///
/// 서버가 `{error, message}` 로 사유 코드와 한국어 문구를 함께 준다. 문구는 그대로 쓰고,
/// 코드는 화면이 다르게 움직여야 하는 경우에만 케이스로 만든다 —
/// 예: `emailTaken` 은 로그인 화면으로 보내야 하고, `sessionExpired` 는 토큰을 지워야 한다.
enum AuthError: LocalizedError, Equatable {
    /// API 키가 없어 서버를 부를 수 없다(로컬 설정 문제).
    case notConfigured
    /// 연결 자체가 안 됐다. 사용자가 할 수 있는 일은 재시도뿐이다.
    case network

    case invalidEmail
    case invalidPassword(message: String)
    case invalidNickname
    /// 409 — 이미 가입된 이메일. 가입 화면이 로그인으로 안내한다.
    case emailTaken
    /// 401 — 이메일이 없는지 비밀번호가 틀린지 **서버가 구분해 주지 않는다**(가입 여부 유출 방지).
    case invalidCredentials
    /// 429 — 같은 IP 에서 시도가 잦다. 10분 창.
    case tooManyAttempts

    /// 401 `login_required` — 아직 로그인하지 않았다. 로그인 창을 띄운다.
    case loginRequired
    /// 401 `session_expired` — 토큰이 낡았다. 지우고 로그인 창을 띄운다.
    case sessionExpired

    case invalidCode
    case codeExpired
    case codeAttemptsExceeded
    /// 429 — 재발송 간격(60초) 안에 다시 눌렀다. 남은 초를 버튼에 보여 준다.
    case resendTooSoon(seconds: Int)

    /// 위에 해당하지 않는 실패. 서버가 준 한국어 문구를 그대로 보여 준다.
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "지금은 로그인할 수 없어요. 앱을 다시 실행해 주세요."
        case .network: "연결에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        case .invalidEmail: "이메일 형식이 올바르지 않아요."
        case .invalidPassword(let message): message
        case .invalidNickname: "이름은 40자 이하로 입력해 주세요."
        case .emailTaken: "이미 가입된 이메일이에요. 로그인해 주세요."
        case .invalidCredentials: "이메일 또는 비밀번호가 올바르지 않아요."
        case .tooManyAttempts: "시도가 많았어요. 잠시 후 다시 시도해 주세요."
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .invalidCode: "인증번호가 올바르지 않아요."
        case .codeExpired: "인증번호가 만료됐어요. 다시 받아 주세요."
        case .codeAttemptsExceeded: "인증번호를 여러 번 틀렸어요. 다시 받아 주세요."
        case .resendTooSoon(let seconds): "\(seconds)초 후에 다시 받을 수 있어요."
        case .server(let message): message
        }
    }

    /// 서버 응답의 사유 코드를 케이스로 바꾼다. 모르는 코드는 서버 문구를 그대로 살린다 —
    /// 앱이 서버보다 늦게 배포되어도 사용자는 최소한 무엇이 잘못됐는지 읽을 수 있다.
    static func from(code: String?, message: String?, status: Int) -> AuthError {
        let text = (message?.isEmpty == false) ? message! : nil
        switch code {
        case "invalid_email": return .invalidEmail
        case "invalid_password": return .invalidPassword(message: text ?? "비밀번호는 8자 이상이어야 해요.")
        case "invalid_nickname": return .invalidNickname
        case "email_taken": return .emailTaken
        case "invalid_credentials": return .invalidCredentials
        case "too_many_attempts": return .tooManyAttempts
        case "login_required", "unauthenticated": return .loginRequired
        case "session_expired": return .sessionExpired
        case "invalid_code": return .invalidCode
        case "code_expired": return .codeExpired
        case "code_attempts_exceeded": return .codeAttemptsExceeded
        case "resend_too_soon": return .resendTooSoon(seconds: 60)
        default:
            if let text { return .server(message: text) }
            // 문구도 코드도 없는 실패. 401 은 로그인 문제로 보는 편이 안전하다 —
            // 그래야 앱이 최소한 로그인 창을 띄운다.
            return status == 401 ? .loginRequired : .network
        }
    }
}

/// 가입·로그인 성공 결과. 토큰은 호출부가 곧바로 `SessionTokenStore` 에 넘긴다.
struct AuthSession: Sendable {
    let token: String
    let expiresAt: Date?
    let account: Account
    /// 가입이었는지(`true`) 로그인이었는지. 환영 화면·온보딩 완료 처리 분기에 쓴다.
    let created: Bool
}
