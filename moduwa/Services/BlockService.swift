import Observation
import SwiftUI

/// 차단한 사람 한 명.
struct BlockedUser: Identifiable, Hashable, Sendable {
    /// `authors.uuid` — 차단·해제가 가리키는 값.
    let uuid: String
    var nickname: String
    var avatarURL: URL?

    var id: String { uuid }
}

enum BlockServiceError: LocalizedError {
    case unavailable
    case server(message: String)
    case loginRequired
    case sessionExpired
    /// 400 `invalid_target` — 자기 자신은 차단할 수 없다. 앱이 자기 글에 차단을 두지 않아
    /// 도달하지 않지만, 도달하면 사용자가 할 수 있는 일이 없어 문구를 따로 둔다.
    case cannotBlockSelf

    var errorDescription: String? {
        switch self {
        case .unavailable: "지금은 차단할 수 없어요. 네트워크 상태를 확인해 주세요."
        case .server(let message): message
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .cannotBlockSelf: "자신은 차단할 수 없어요."
        }
    }
}

/// 사용자 차단 (`/v1/blocks`, 서버 2026-09-02).
///
/// **앱스토어 심사 필수**다 — 사용자 생성 콘텐츠가 있는 앱은 신고·차단·필터·연락처를 모두
/// 갖춰야 한다(1.2). 신고는 운영자에게 알리는 것이고, 차단은 **보는 사람이 스스로** 안 보이게
/// 하는 것이라 둘 다 필요하다.
///
/// 목록에서 빼는 일은 **서버가 한다**(`app.ts:738` — 차단한 사람의 글이 응답에서 제외된다).
/// 그래서 앱은 차단한 뒤 목록을 **다시 받으면** 된다(`BlockStore.revision`).
protocol BlockService: Sendable {
    func blocked() async throws -> [BlockedUser]
    /// 차단. 재차단은 멱등이다(204).
    func block(uuid: String) async throws
    /// 해제. 없는 것도 204 다(멱등).
    func unblock(uuid: String) async throws
}

struct APIBlockService: BlockService {
    private let session: URLSession = .shared

    func blocked() async throws -> [BlockedUser] {
        let data = try await send("GET", "/v1/blocks")
        return try JSONDecoder().decode(ListDTO.self, from: data).items.map(\.user)
    }

    func block(uuid: String) async throws {
        _ = try await send("POST", "/v1/blocks", body: ["uuid": uuid])
    }

    func unblock(uuid: String) async throws {
        // 경로에 들어가는 값이라 인코딩한다 — uuid 는 안전한 문자만 쓰지만, 서버가 형식을
        //  넓히면 여기서 조용히 깨진다.
        let escaped = uuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? uuid
        _ = try await send("DELETE", "/v1/blocks/\(escaped)")
    }

    private func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        guard !ModuwaAPI.apiKey.isEmpty else { throw BlockServiceError.unavailable }
        var request = URLRequest(url: ModuwaAPI.url(path))
        request.httpMethod = method
        request.setValue("Bearer \(ModuwaAPI.apiKey)", forHTTPHeaderField: "Authorization")
        ModuwaAPI.attachSession(to: &request)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let failure = try? JSONDecoder().decode(ErrorBody.self, from: data)
            switch ModuwaAPI.authFailure(status: status, code: failure?.error) {
            case .loginRequired: throw BlockServiceError.loginRequired
            case .expired: throw BlockServiceError.sessionExpired
            case nil: break
            }
            if failure?.error == "invalid_target" { throw BlockServiceError.cannotBlockSelf }
            if let message = failure?.message, !message.isEmpty {
                throw BlockServiceError.server(message: message)
            }
            throw BlockServiceError.unavailable
        }
        return data
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let message: String?
    }

    private struct ListDTO: Decodable {
        let items: [UserDTO]

        struct UserDTO: Decodable {
            let uuid: String
            let nickname: String?
            let avatarUrl: String?

            var user: BlockedUser {
                BlockedUser(uuid: uuid, nickname: nickname ?? "",
                            avatarURL: URL(imageAddress: avatarUrl))
            }
        }
    }
}

/// 프리뷰·번들 폴백.
struct UnavailableBlockService: BlockService {
    func blocked() async throws -> [BlockedUser] { [] }
    func block(uuid: String) async throws { throw BlockServiceError.unavailable }
    func unblock(uuid: String) async throws { throw BlockServiceError.unavailable }
}

/// 차단이 일어났다는 앱 전역 신호.
///
/// 차단한 사람의 글을 목록에서 빼는 일은 서버가 하므로, 앱은 **목록을 다시 받기만** 하면 된다.
/// 그 신호를 여기서 방송하고 목록을 든 화면이 `task(id:)` 로 지켜본다
/// (`PostInteractionSignal.likeRevision` 과 같은 구조).
@Observable
final class BlockSignal {
    /// 차단·해제가 일어날 때마다 오른다. 값 자체에는 뜻이 없다.
    private(set) var revision = 0

    func changed() { revision += 1 }
}

extension EnvironmentValues {
    @Entry var blockService: any BlockService = APIBlockService()
    @Entry var blockSignal = BlockSignal()
}
