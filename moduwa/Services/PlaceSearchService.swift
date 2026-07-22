import Foundation
import SwiftUI

/// 검색 결과 페이지. `total`은 서버가 반환한 전체 일치 수다.
struct PlaceSearchPage: Sendable {
    let items: [Place]
    let total: Int
}

/// 장소 이름·지역 통합 검색 데이터 소스.
protocol PlaceSearchService: Sendable {
    func searchPlaces(query: String, limit: Int, offset: Int) async throws -> PlaceSearchPage
}

/// moduwa-backend의 `GET /v1/search` 구현.
///
/// 홈 피드와 같은 `MODUWA_API_BASE_URL` / `MODUWA_API_KEY` 설정을 사용한다.
/// API 키는 번들의 `Secrets.plist` 또는 Info.plist에 넣는다.
struct APISearchService: PlaceSearchService {
    private let baseURL = URL(
        string: ProcessInfo.processInfo.environment["MODUWA_API_BASE_URL"]
            ?? "https://moduwa-backend-production.up.railway.app"
    )!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? Secrets.moduwaAPIKey
            ?? ""
        self.session = session
    }

    enum SearchError: Error {
        case notConfigured
        case badStatus(Int)
    }

    private struct Response: Decodable {
        let total: Int
        let items: [PlaceDTO]
    }

    private struct PlaceDTO: Decodable {
        struct AccessDTO: Decodable {
            let wheelchair: Bool
            let visual: Bool
            let hearing: Bool
            let infant: Bool
        }

        let contentid: String
        let title: String?
        let contenttypeid: String?
        let category: String?
        let region: String?
        let firstimage: String?
        let access: AccessDTO
    }

    func searchPlaces(query: String, limit: Int = 20, offset: Int = 0) async throws -> PlaceSearchPage {
        guard !apiKey.isEmpty else { throw SearchError.notConfigured }

        var components = URLComponents(url: baseURL.appending(path: "/v1/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SearchError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return PlaceSearchPage(
            items: decoded.items.compactMap(Self.makePlace),
            total: decoded.total
        )
    }

    private static func makePlace(_ dto: PlaceDTO) -> Place? {
        guard let name = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let access = accessibility(from: dto.access)
        let category = category(for: dto.contenttypeid)
        return Place(
            id: dto.contentid,
            name: name,
            region: dto.region?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "지역 정보 없음",
            rating: nil,
            accessibilityNote: access.note,
            feature: access.feature,
            category: category,
            categoryLabel: categoryLabel(for: dto, fallback: category),
            imageURL: URL(string: (dto.firstimage ?? "").replacingOccurrences(of: "http://", with: "https://"))
        )
    }

    private static func category(for contentTypeID: String?) -> PlaceCategory {
        switch contentTypeID {
        case "32": .stay
        case "39": .food
        case "15": .festival
        default: .attraction
        }
    }

    /// 앱에서 쓰는 카테고리명은 Figma 시안의 문구(숙소·맛집 등)를 우선한다.
    /// 그 외 TourAPI 타입은 서버가 제공한 원문 라벨을 표시한다.
    private static func categoryLabel(for dto: PlaceDTO, fallback: PlaceCategory) -> String {
        switch dto.contenttypeid {
        case "12", "15", "32", "39":
            return fallback.rawValue
        default:
            if let label = dto.category?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
                return label
            }
            return fallback.rawValue
        }
    }

    private static func accessibility(from access: PlaceDTO.AccessDTO) -> (feature: AccessibilityFeature, note: String) {
        let features: [AccessibilityFeature] = [
            access.wheelchair ? .wheelchairAccessible : nil,
            access.visual ? .visuallyImpairedFriendly : nil,
            access.hearing ? .hearingFriendly : nil,
            access.infant ? .childFriendly : nil,
        ].compactMap { $0 }

        guard let primary = features.first else {
            // 검색 데이터는 무장애 장소를 대상으로 하지만, 기존 데이터에 플래그가 비어 있을 수 있다.
            return (.wheelchairAccessible, "접근성 정보 확인 필요")
        }
        return (primary, features.map(\.label).joined(separator: " · ") + " 정보 제공")
    }
}

extension EnvironmentValues {
    @Entry var placeSearchService: any PlaceSearchService = APISearchService()
}
