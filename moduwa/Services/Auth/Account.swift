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
    /// 프로필 사진(서버 042). `nil` 이면 사진을 올리지 않은 계정 — 앱이 이니셜 원을 그린다.
    /// 서버는 **https 만** 저장한다(평문 http 는 ATS 가 막아 화면에 안 뜬다).
    var avatarURL: URL? = nil
    /// 무장애 항목은 있는데 **동의 기록이 없는** 계정인가(서버 050).
    ///
    /// 동의 기록이 생기기 전에 가입한 사람들이다. 법은 동의받은 사실을 처리자가 입증하도록
    /// 하므로, 기록이 없으면 "동의 없이 수집했다" 는 주장에 반증할 수단이 없다.
    /// 앱은 이 값이 참인 사람에게 **다시 묻는다**(`SensitiveConsentPrompt`) — 동의하면 기록을
    /// 남기고, 거부하면 항목을 지운다.
    var needsSensitiveConsent: Bool = false

    /// 이 계정의 무장애 항목이 **동의를 받아 저장된 상태**인가.
    /// 항목이 없으면 동의도 없다 — 새로 채울 때 물어야 한다.
    var hasSensitiveConsent: Bool { !accessFeatures.isEmpty && !needsSensitiveConsent }

    var id: String { uuid }
}

/// 프로필 사진을 어떻게 바꾸는지. **"건드리지 않음"과 "지우기"는 다른 뜻이다** —
/// 서버도 그렇게 가른다(키 없음 = 그대로, `null` = 지우기).
enum AvatarUpdate: Equatable, Sendable {
    case set(URL)
    case clear
}

/// 로그인·가입 실패 사유 중 **화면이 분기해야 하는** 것들.
///
/// 서버가 `{error, message}` 로 사유 코드와 한국어 문구를 함께 준다. 문구는 그대로 쓰고,
/// 코드는 화면이 다르게 움직여야 하는 경우에만 케이스로 만든다 —
/// 예: `emailTaken` 은 로그인 화면으로 보내야 하고, `sessionExpired` 는 토큰을 지워야 한다.
/// 문구는 **시안의 용어를 따른다** — 온보딩·로그인 시안(868:150)은 6자리 숫자를 한결같이
/// "인증코드"로 부른다. 앱이 "인증번호"라고 부르면 같은 것을 두 이름으로 배우게 된다.
enum AuthError: LocalizedError, Equatable {
    /// API 키가 없어 서버를 부를 수 없다(로컬 설정 문제).
    case notConfigured
    /// 연결 자체가 안 됐다. 사용자가 할 수 있는 일은 재시도뿐이다.
    case network

    case invalidEmail
    case invalidPassword(message: String)
    case invalidNickname
    /// 409 — 이미 가입된 이메일. 가입 화면이 로그인으로 안내한다.
    ///
    /// `providers` 는 그 주소가 **어떤 방법으로** 가입돼 있는지다(서버 2026-09-12):
    /// `["email"]`, `["google"]`, `["email", "google"]` 처럼 온다.
    ///
    /// ⚠️ `"email"` 이 없으면 **그 계정에는 비밀번호가 없다.** "로그인해 주세요" 라고만 하면
    /// 사용자는 이메일 로그인을 시도하고 반드시 실패한다 — 소셜 버튼을 가리켜야 한다.
    /// 옛 서버는 이 필드를 주지 않으므로 빈 배열이면 예전처럼 이메일 로그인으로 안내한다.
    case emailTaken(providers: [String])

    /// 409 `link_required` — **카카오 전용**(서버 2026-09-12). 카카오 이메일이 기존 계정의
    /// 주소와 같다. 서버는 아무것도 만들지 않고 앱이 묻게 한다.
    ///
    /// 구글·애플과 달리 카카오는 이메일을 검증해 주지 않아 자동으로 이어 붙일 수 없다.
    /// 말없이 별도 계정을 만들면 사용자는 **후기·플랜이 빈 계정**을 보게 된다.
    ///
    /// ⚠️ **오류 줄로 보여 주지 않는다.** 이건 실패가 아니라 갈림길이라 다이얼로그로 묻는다
    /// (`SessionStore.kakaoLink`). 여기 문구는 그 길이 막혔을 때의 대비다.
    case linkRequired(providers: [String])

    /// 409 `identity_in_use` — 그 소셜 계정이 **이미 다른 모두와 계정**에 붙어 있다.
    /// 두 계정을 합치지는 않는다(후기·플랜의 주인을 옮기는 일이라 별도 설계가 필요하다).
    case identityInUse

    /// 409 `provider_already_linked` — 이 계정에 그 방식이 이미 붙어 있다.
    /// 정상 흐름에서는 나오지 않는다.
    case providerAlreadyLinked
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
        case .invalidNickname: "이름은 1자 이상 40자 이하로 입력해 주세요."
        case .emailTaken(let providers): Self.emailTakenMessage(providers: providers)
        case .linkRequired: "이 이메일로 가입된 계정이 있어요. 다시 시도해 주세요."
        case .identityInUse: "이 카카오 계정은 이미 다른 계정에 연결돼 있어요. 그 계정으로 로그인해 주세요."
        case .providerAlreadyLinked: "이 계정에는 카카오가 이미 연결돼 있어요."
        case .invalidCredentials: "이메일 또는 비밀번호가 올바르지 않아요."
        case .tooManyAttempts: "시도가 많았어요. 잠시 후 다시 시도해 주세요."
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .invalidCode: "인증코드가 일치하지 않습니다."
        case .codeExpired: "인증코드가 만료됐어요. 다시 받아 주세요."
        case .codeAttemptsExceeded: "인증코드를 여러 번 틀렸어요. 다시 받아 주세요."
        case .resendTooSoon(let seconds): "\(seconds)초 후에 다시 받을 수 있어요."
        case .server(let message): message
        }
    }

    /// 가입된 방법을 사람이 읽는 말로. `"email"` 이 함께 있으면 비밀번호가 있다는 뜻이라
    /// 예전처럼 이메일 로그인으로 보낸다. 소셜만 있으면 **그 버튼**을 가리켜야 한다.
    ///
    /// 모르는 코드가 와도 이름을 만들어 낸다(`naver` → `Naver`) — 서버가 로그인 방법을
    /// 늘려도 앱이 "이미 가입된 이메일이에요" 로 얼버무리지 않게 한다.
    private static func emailTakenMessage(providers: [String]) -> String {
        let social = providers.filter { $0 != "email" }
        guard !providers.contains("email"), !social.isEmpty else {
            return "이미 가입된 이메일이에요. 로그인해 주세요."
        }
        let names = social.map { code -> String in
            switch code {
            case "google": "Google"
            case "apple": "Apple"
            case "kakao": "카카오"
            default: code.prefix(1).uppercased() + code.dropFirst()
            }
        }.joined(separator: " · ")
        return "\(names) 로그인으로 가입된 이메일이에요. 그 버튼으로 로그인해 주세요."
    }

    /// 서버 응답의 사유 코드를 케이스로 바꾼다. 모르는 코드는 서버 문구를 그대로 살린다 —
    /// 앱이 서버보다 늦게 배포되어도 사용자는 최소한 무엇이 잘못됐는지 읽을 수 있다.
    static func from(
        code: String?, message: String?, status: Int, providers: [String] = []
    ) -> AuthError {
        let text = (message?.isEmpty == false) ? message! : nil
        switch code {
        case "invalid_email": return .invalidEmail
        case "invalid_password": return .invalidPassword(message: text ?? "비밀번호는 8자 이상이어야 해요.")
        case "invalid_nickname": return .invalidNickname
        case "email_taken": return .emailTaken(providers: providers)
        case "link_required": return .linkRequired(providers: providers)
        case "identity_in_use": return .identityInUse
        case "provider_already_linked": return .providerAlreadyLinked
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

    /// 소셜 로그인이 **기존 계정에 이어 붙었다**(서버 2026-09-12). 이메일로 가입한 주소와
    /// 같은 주소로 소셜 로그인했을 때다 — 후기·플랜·프로필이 그대로 따라온다.
    ///
    /// `created` 와 **동시에 참이 되지 않는다**: 만들었거나, 이어 붙였거나, 그냥 로그인이다.
    /// 요청에 실은 닉네임·무장애 항목은 서버가 무시하고 기존 계정 값을 지킨다.
    ///
    /// 카카오와 애플 "이메일 가리기" 는 주소를 검증받지 못하거나 릴레이 주소라 **이어 붙지
    /// 않는다** — 같은 주소로 보여도 별개 계정이 된다.
    var linked: Bool = false

    /// 이어 붙이면서 서버가 **이메일 비밀번호를 지웠다**(서버 2026-09-12). 기존 이메일 계정이
    /// 인증코드를 넣지 않은 상태였을 때만 일어난다 — 남의 주소로 선점 가입해 둔 계정이
    /// 진짜 주인의 소셜 로그인을 가로채지 못하게 하는 안전장치다.
    ///
    /// 소셜 로그인은 그대로 되지만 **이메일 로그인은 이제 안 된다.** 비밀번호 찾기로 다시
    /// 만들어야 한다는 것을 알려 주지 않으면, 다음에 이메일로 로그인하려다 막힌다.
    var passwordReset: Bool = false
}
