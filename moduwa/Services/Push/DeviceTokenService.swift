import Foundation

/// 기기 토큰 등록·해제(`/v1/devices`, 서버 2026-08-31).
///
/// 실패를 사용자에게 보여 주지 않는다 — 알림 등록은 사용자가 시작한 일이지만 그 결과가
/// 화면의 무엇도 바꾸지 않고, 다음 실행·다음 로그인에 다시 시도된다. 그래서 오류 타입도 없다.
protocol DeviceTokenService: Sendable {
    /// 권한을 받은 직후, 그리고 **로그인할 때마다** 부른다.
    /// 토큰이 PK 라 재등록은 upsert 이고 서버가 `author_id` 까지 갱신한다 — 한 기기를 다른
    /// 계정으로 로그인하면 소유자가 바뀌어야 하기 때문이다(안 그러면 로그아웃한 사람에게 계속 간다).
    func register(token: String, environment: PushEnvironment) async throws

    /// 로그아웃·알림 끄기에서 부른다. 없는 토큰도 204 다(멱등).
    /// ⚠️ **로그아웃보다 먼저** 불려야 한다 — 세션 토큰이 지워진 뒤에는 401 이다.
    func unregister(token: String) async throws
}

struct APIDeviceTokenService: DeviceTokenService {
    private let session: URLSession = .shared

    func register(token: String, environment: PushEnvironment) async throws {
        var request = authorized(ModuwaAPI.url("/v1/devices"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "token": token,
            "environment": environment.rawValue,
            "platform": "ios",
            // 진단용 — 서버가 어느 앱의 토큰인지 알 수 있게 한다.
            "bundleId": Bundle.main.bundleIdentifier ?? "",
        ])
        _ = try await send(request)
    }

    func unregister(token: String) async throws {
        var request = authorized(ModuwaAPI.url("/v1/devices/\(token)"))
        request.httpMethod = "DELETE"
        _ = try await send(request)
    }

    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(ModuwaAPI.apiKey)", forHTTPHeaderField: "Authorization")
        ModuwaAPI.attachSession(to: &request)
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw NSError(domain: "moduwa.devices", code: status, userInfo: [
                NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "",
            ])
        }
        return data
    }
}
