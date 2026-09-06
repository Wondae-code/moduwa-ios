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

    /// 보는 사람의 무장애 축을 싣는 헤더(서버 052).
    ///
    /// ⚠️ **쿼리스트링에 실으면 안 된다.** 서버 접속 로그에는 남지 않는 것을 서버팀이 프로브로
    /// 확인했지만(쿼리는 버려지고 `srcIp` 만 남는다), URL 은 로그 말고도 새는 곳이 많다 —
    /// 이슈에 붙는 curl 한 줄, 화면 캡처, 채팅에 붙여넣는 재현 절차. 전부 사람 손으로 옮겨진다.
    /// 누가 디버깅하다 URL 을 티켓에 붙이면 **그 순간 한 사람의 장애 축이 트래커에 들어간다.**
    /// 나중에 로거나 에러 추적 SDK 를 붙이는 날 조용히 새기 시작하는 것도 헤더가 막아 준다.
    static let visitorTagsHeader = "x-visitor-tags"

    /// 무장애 축을 헤더에 싣는다. 두 곳이 같은 헤더를 쓴다 —
    /// 후기 추천 정렬(`GET /v1/reviews?sort=recommended`)과 장소 목록 좁히기
    /// (`GET /v1/barrier-free`, 서버가 `visit_` 접두어를 떼고 본다).
    ///
    /// ⚠️ 서버는 **다섯 개까지만** 보고 그 뒤는 조용히 버린다(`slice(0, 5)`, 앞에서 자른다).
    /// 축이 다섯뿐이라 지금은 걸릴 일이 없지만, 순서에 뜻을 담지 않는다.
    static func attach(visitorTags features: [AccessibilityFeature], to request: inout URLRequest) {
        // `flatPath`·`barrierFreeRoom` 은 방문 조건 태그가 없다 — 조용히 빠진다.
        let codes = features.compactMap(\.visitorTagCode)
        guard !codes.isEmpty else { return }
        request.setValue(codes.joined(separator: ","), forHTTPHeaderField: visitorTagsHeader)
    }

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
