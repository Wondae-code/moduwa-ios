import Foundation

/// 라이브 API 연동 AuthService — `/v1/auth/*`.
///
/// 폴백이 없다. 로그인은 서버만이 답할 수 있는 질문이고, 실패를 성공으로 메우면
/// 사용자는 로그인된 줄 알고 쓰기를 시도해 전부 401 을 받는다.
struct APIAuthService: AuthService {
    private let apiKey: String
    private let session: URLSession
    /// 기기 기록용. **신원이 아니다** — 서버는 "이 계정이 이 기기를 쓴다"는 기록만 남긴다
    /// (`author_devices`). 후기·플랜과 같은 값을 보내 같은 기기로 인식되게 한다.
    private let deviceId: String

    init(apiKey: String? = nil, session: URLSession = .shared, deviceId: String? = nil) {
        self.apiKey = apiKey ?? ModuwaAPI.apiKey
        self.session = session
        self.deviceId = deviceId ?? ReviewAuthorStore.deviceId
    }

    // MARK: - HTTP

    private struct ErrorResponse: Decodable {
        let error: String?
        let message: String?
        /// `resend_too_soon` 에만 온다 — 버튼에 남은 초를 보여 준다.
        let retryAfter: Int?
    }

    /// 요청 한 건. 실패는 전부 `AuthError` 로 바꿔 던진다.
    private func send<Response: Decodable>(
        _ method: String, _ path: String, body: [String: Any]? = nil
    ) async throws -> Response {
        let data = try await sendRaw(method, path, body: body)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            // 200 인데 읽을 수 없는 응답. 서버가 바뀐 것이므로 사용자에게는 일반 실패로 보인다.
            throw AuthError.network
        }
    }

    @discardableResult
    private func sendRaw(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        guard !apiKey.isEmpty else { throw AuthError.notConfigured }

        var request = URLRequest(url: ModuwaAPI.url(path))
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // 로그인·가입에도 붙는다. 서버는 이 두 경로에서 **낡은 토큰을 통과시킨다** —
        //  그러지 않으면 만료된 토큰을 못 지운 앱이 재로그인조차 못 한다.
        ModuwaAPI.attachSession(to: &request)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network
        }
        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            // 401 은 여기서도 공통 처리를 태운다 — session_expired 면 토큰을 버려야 한다.
            //  (예: /me 로 부팅 확인하는 순간 만료를 발견하는 경로)
            _ = ModuwaAPI.authFailure(status: http.statusCode, code: failure?.error)
            if let seconds = failure?.retryAfter, failure?.error == "resend_too_soon" {
                throw AuthError.resendTooSoon(seconds: seconds)
            }
            throw AuthError.from(code: failure?.error, message: failure?.message, status: http.statusCode)
        }
        return data
    }

    // MARK: - 가입 · 로그인

    func signUp(
        email: String, password: String, nickname: String?, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        var body: [String: Any] = [
            "email": email,
            "password": password,
            "deviceId": deviceId,
        ]
        if let nickname, !nickname.isEmpty { body["nickname"] = nickname }
        // ⚠️ 온보딩을 하지 않았으면 **키를 아예 넣지 않는다.** 빈 배열을 보내면 서버가
        //  "온보딩을 마쳤고 아무것도 고르지 않았다"로 기록해 온보딩을 다시 띄울 수 없게 된다.
        if let accessFeatures { body["accessFeatures"] = accessFeatures.map(\.rawValue) }

        let dto: SessionDTO = try await send("POST", "/v1/auth/email/sign-up", body: body)
        return dto.session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let dto: SessionDTO = try await send("POST", "/v1/auth/email/sign-in", body: [
            "email": email,
            "password": password,
            "deviceId": deviceId,
        ])
        return dto.session
    }

    func signInWithGoogle(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        try await social("/v1/auth/google", idToken: idToken, accessFeatures: accessFeatures)
    }

    func signInWithKakao(
        idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        try await social("/v1/auth/kakao", idToken: idToken, accessFeatures: accessFeatures)
    }

    /// 소셜 로그인은 프로바이더마다 **경로만 다르고 본문은 같다**(서버가 그렇게 맞춰 뒀다).
    /// 애플·네이버가 붙어도 여기 한 줄이 늘어날 뿐이다.
    private func social(
        _ path: String, idToken: String, accessFeatures: [AccessibilityFeature]?
    ) async throws -> AuthSession {
        var body: [String: Any] = [
            "idToken": idToken,
            "deviceId": deviceId,
        ]
        // 이메일 가입과 같은 규칙 — 온보딩을 안 했으면 키를 아예 넣지 않는다.
        if let accessFeatures { body["accessFeatures"] = accessFeatures.map(\.rawValue) }

        // 서버는 새 계정이면 201, 기존 계정이면 200 을 준다. 응답 모양은 같다.
        let dto: SessionDTO = try await send("POST", path, body: body)
        return dto.session
    }

    func signOut() async throws {
        // 본문은 없다. 끊을 기기는 서버가 세션 기록에서 직접 읽는다 —
        //  예전에는 본문의 deviceId 를 믿어서, 세션 하나만 있으면 남의 기기를 로그아웃시킬 수 있었다.
        try await sendRaw("POST", "/v1/auth/sign-out")
    }

    func updateAccessFeatures(_ features: [AccessibilityFeature]) async throws -> Account {
        // 빈 배열도 보낸다 — "아무것도 필요 없다"는 선택이고, 서버는 키가 없을 때만
        //  "바꿀 것이 없다"로 본다(400 nothing_to_update).
        let dto: AuthorDTO = try await send("PATCH", "/v1/auth/me", body: [
            "accessFeatures": features.map(\.rawValue),
        ])
        return dto.account
    }

    func currentAccount() async throws -> Account {
        let dto: AuthorDTO = try await send("GET", "/v1/auth/me")
        return dto.account
    }

    // MARK: - 이메일 인증

    private struct VerifyRequestResponse: Decodable {
        let ok: Bool
        let alreadyVerified: Bool?
    }

    func resendVerificationCode() async throws -> Bool {
        let response: VerifyRequestResponse = try await send("POST", "/v1/auth/email/verify/request")
        return response.alreadyVerified ?? false
    }

    func verifyEmail(code: String) async throws {
        try await sendRaw("POST", "/v1/auth/email/verify", body: ["code": code])
    }

    // MARK: - 비밀번호 찾기

    func requestPasswordReset(email: String) async throws {
        try await sendRaw("POST", "/v1/auth/email/forgot", body: ["email": email])
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        // 서버 필드명은 `password` 다(새 비밀번호).
        try await sendRaw("POST", "/v1/auth/email/reset", body: [
            "email": email, "code": code, "password": newPassword,
        ])
    }

    // MARK: - DTO

    /// 가입·로그인 응답. `author` 는 `/me` 와 같은 모양이다.
    private struct SessionDTO: Decodable {
        let token: String
        let expiresAt: String?
        let author: AuthorDTO
        let created: Bool?

        var session: AuthSession {
            AuthSession(
                token: token,
                expiresAt: expiresAt.flatMap(APIAuthService.date(fromISO8601:)),
                account: author.account,
                created: created ?? false
            )
        }
    }

    private struct AuthorDTO: Decodable {
        let uuid: String
        let nickname: String?
        let email: String?
        let emailVerified: Bool?
        /// 서버가 값을 검증하지 않으므로 **모르는 코드가 올 수 있다** — 문자열로 받고 걸러 낸다.
        let accessFeatures: [String]?
        let onboarded: Bool?

        var account: Account {
            Account(
                uuid: uuid,
                nickname: nickname ?? "여행자",
                email: email,
                emailVerified: emailVerified ?? false,
                accessFeatures: (accessFeatures ?? []).compactMap(AccessibilityFeature.init(rawValue:)),
                onboarded: onboarded ?? false
            )
        }
    }

    /// `2026-11-18T07:23:47.935Z` — 소수점이 있는 형태로 오지만 없는 경우도 받아 둔다.
    private static func date(fromISO8601 text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}
