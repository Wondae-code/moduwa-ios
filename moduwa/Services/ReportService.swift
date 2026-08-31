import SwiftUI

enum ReportServiceError: LocalizedError {
    /// 보낼 곳이 없다(API 키 없음 — 번들 폴백 기기).
    case unavailable
    /// 서버가 한국어 사유를 준 경우 그대로 보여 준다.
    case server(message: String)
    case loginRequired
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .unavailable: "지금은 신고를 보낼 수 없어요. 네트워크 상태를 확인해 주세요."
        case .server(let message): message
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        }
    }
}

/// 신고 (`POST /v1/reports`, 서버 2026-08-31).
///
/// **후기 전용이던 것을 대상 넷으로 넓혔다.** 서버가 라우트 하나로 받으므로 앱도 서비스 하나만
/// 둔다 — 게시글·후기·양쪽 댓글이 같은 표의 같은 행 규칙을 쓴다(`unique (대상, 신고자)`).
///
/// `FeedService.reportReview` 를 대신한다. 기존 후기 라우트도 서버에 남아 있지만 같은 표에
/// 쌓이므로 앱은 **한 길만** 쓴다 — 두 길을 두면 어느 화면이 어느 길로 갔는지 추적하게 된다.
protocol ReportService: Sendable {
    /// 사유를 골라 보낸다. 성공은 204 라 돌려줄 값이 없다.
    ///
    /// **같은 사람의 재신고는 멱등**이고, **자기 것 신고는 204 로 무시된다**(서버 판단) —
    /// 둘 다 오류가 아니므로 호출부는 성공으로 다룬다. 앱은 자기 콘텐츠에 신고 버튼을 아예
    /// 두지 않아 후자에는 도달하지 않는다.
    func submit(target: ReportTarget, reason: ReportReason, detail: String?) async throws
}

struct APIReportService: ReportService {
    private let session: URLSession = .shared

    func submit(target: ReportTarget, reason: ReportReason, detail: String?) async throws {
        guard !ModuwaAPI.apiKey.isEmpty else { throw ReportServiceError.unavailable }
        var request = URLRequest(url: ModuwaAPI.url("/v1/reports"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(ModuwaAPI.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ModuwaAPI.attachSession(to: &request)

        var body: [String: Any] = [
            "targetType": target.type,
            "targetId": target.targetId,
            "reason": reason.rawValue,
        ]
        // 빈 문자열을 보내지 않는다 — "설명 없음"과 "빈 설명"을 서버가 구분할 이유가 없다.
        if let detail, !detail.isEmpty { body["detail"] = detail }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let failure = try? JSONDecoder().decode(ErrorBody.self, from: data)
            switch ModuwaAPI.authFailure(status: status, code: failure?.error) {
            case .loginRequired: throw ReportServiceError.loginRequired
            case .expired: throw ReportServiceError.sessionExpired
            case nil: break
            }
            if let message = failure?.message, !message.isEmpty {
                throw ReportServiceError.server(message: message)
            }
            throw ReportServiceError.unavailable
        }
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let message: String?
    }
}

/// 프리뷰·번들 폴백 — 보낼 곳이 없다.
struct UnavailableReportService: ReportService {
    func submit(target: ReportTarget, reason: ReportReason, detail: String?) async throws {
        throw ReportServiceError.unavailable
    }
}

extension EnvironmentValues {
    @Entry var reportService: any ReportService = APIReportService()
}
