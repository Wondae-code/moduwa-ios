import Foundation

/// 라이브 API(moduwa-backend)의 공통 접속 정보와 **인증 두 층**의 조립 규칙.
///
/// 서버 인증은 두 층이고 서로 다른 질문에 답한다(백엔드 `docs/API.md`):
/// - `Authorization: Bearer <API_KEY>` — "이 앱이 호출해도 되는가". 모든 `/v1/*` 에 필요하다.
/// - `X-Session-Token: <TOKEN>` — "이 요청이 누구인가". 로그인했을 때만 붙인다.
///
/// 헤더 이름과 401 처리를 여기 한 곳에 두는 이유: 서비스가 넷이라 어느 하나가 세션 헤더를
/// 빼먹으면 그 화면만 조용히 비로그인으로 동작한다(하트가 안 눌리고 내 플랜이 비어 보인다).
enum ModuwaAPI {
    /// 로컬 백엔드 테스트: 시뮬레이터 실행 시
    /// `SIMCTL_CHILD_MODUWA_API_BASE_URL=http://localhost:8080` 로 오버라이드
    static let baseURL = URL(
        string: ProcessInfo.processInfo.environment["MODUWA_API_BASE_URL"]
            ?? "https://moduwa-backend-production.up.railway.app"
    )!

    /// 번들 `Secrets.plist` 또는 Info.plist 의 `MODUWA_API_KEY`.
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? Secrets.moduwaAPIKey
            ?? ""
    }

    /// 세션 토큰 헤더 이름. `Authorization` 은 이미 API 키가 쓰고 있어 겹칠 수 없다.
    static let sessionHeader = "X-Session-Token"

    static func url(_ path: String, _ query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }

    /// 로그인했으면 세션 토큰을 붙인다. 비로그인 요청은 그대로 둔다 —
    /// 둘러보기(장소·후기 읽기)는 토큰 없이 되어야 한다.
    static func attachSession(to request: inout URLRequest) {
        guard let token = SessionTokenStore.shared.token else { return }
        request.setValue(token, forHTTPHeaderField: sessionHeader)
    }

    /// 401 의 두 가지 뜻. 서버가 코드로 구분해 준다.
    enum AuthFailure {
        /// `login_required` — 아직 로그인하지 않았다.
        case loginRequired
        /// `session_expired` — 토큰이 낡았다. 이미 지웠고 화면에도 알렸다.
        case expired
    }

    /// 401 을 만났을 때의 공통 처리.
    ///
    /// `session_expired` 면 **여기서 토큰을 버린다** — 각 서비스에 맡기면 한 곳이 빼먹고,
    /// 그 화면은 낡은 토큰으로 401 을 무한히 받는다. 호출부는 반환값을 자기 오류 타입으로 바꿔 던진다.
    static func authFailure(status: Int, code: String?) -> AuthFailure? {
        guard status == 401 else { return nil }
        if code == "session_expired" {
            SessionTokenStore.shared.markExpired()
            return .expired
        }
        return .loginRequired
    }
}
