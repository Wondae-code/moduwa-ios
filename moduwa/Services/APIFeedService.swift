import Foundation

/// 라이브 API(moduwa-backend) 연동 FeedService.
///
/// - 장소: `GET /v1/barrier-free` (무장애 28속성) → 번들 생성 스크립트와 동일한 가공 규칙으로 Place 매핑
/// - 리뷰: `GET /v1/reviews`
/// - 히어로 카드: 서버 소스가 없어 번들 값 사용
///
/// **API 키**: Info.plist(또는 빌드 설정)의 `MODUWA_API_KEY` 에서 읽는다.
/// 키가 없거나 네트워크/디코딩이 실패하면 `BundledFeedService`(번들 JSON)로 **자동 폴백**하므로,
/// 키 미설정 상태에서도 앱은 기존 번들 데이터로 정상 동작한다.
struct APIFeedService: FeedService {
    private let baseURL = URL(string: "https://moduwa-backend-production.up.railway.app")!
    private let apiKey: String
    private let session: URLSession
    private let fallback = BundledFeedService()

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? ""
        self.session = session
    }

    // 앱 카테고리 → 관광공사 contentTypeId
    private func typeId(_ c: PlaceCategory) -> String {
        switch c {
        case .stay: "32"
        case .food: "39"
        case .attraction: "12"
        case .festival: "15"
        }
    }

    // MARK: - HTTP

    private enum APIError: Error { case notConfigured, badStatus(Int) }

    private struct ListResponse<T: Decodable>: Decodable { let items: [T] }

    private func getItems<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> [T] {
        guard !apiKey.isEmpty else { throw APIError.notConfigured }
        var comps = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(ListResponse<T>.self, from: data).items
    }

    // MARK: - Hero (서버 소스 없음 → 번들)

    func fetchHeroRecommendation() async throws -> HeroRecommendation {
        try await fallback.fetchHeroRecommendation()
    }

    // MARK: - Places

    private struct BarrierFreeDTO: Decodable {
        let contentid: String?
        let title: String?
        let addr1: String?
        let firstimage: String?
        let wheelchair: String?
        let room: String?
        let route: String?
        let elevator: String?
        let restroom: String?
    }

    func fetchRecommendedPlaces(category: PlaceCategory) async throws -> [Place] {
        do {
            let dtos: [BarrierFreeDTO] = try await getItems("/v1/barrier-free", [
                .init(name: "type", value: typeId(category)),
                .init(name: "hasImage", value: "true"),
                .init(name: "hasAccess", value: "true"),
                .init(name: "limit", value: "30"),
            ])
            let places: [Place] = dtos.compactMap { dto in
                guard let id = dto.contentid, let name = dto.title?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
                      let picked = Self.pickFeature(dto, category) else { return nil }
                let img = (dto.firstimage ?? "").replacingOccurrences(of: "http://", with: "https://")
                return Place(
                    id: id,
                    name: name,
                    region: Self.shortRegion(dto.addr1),
                    rating: nil,
                    accessibilityNote: picked.note,
                    feature: picked.feature,
                    category: category,
                    imageURL: URL(string: img)
                )
            }
            return Array(places.prefix(6))
        } catch {
            return try await fallback.fetchRecommendedPlaces(category: category)
        }
    }

    // MARK: - Reviews

    private struct ReviewDTO: Decodable {
        let author: String
        let location: String
        let body: String
        let likeCount: Int
        let commentCount: Int
        let createdAt: String
        let isAccessibilityVerified: Bool
    }

    func fetchReviews(sort: ReviewSort) async throws -> [TravelReview] {
        do {
            let dtos: [ReviewDTO] = try await getItems("/v1/reviews", [
                .init(name: "sort", value: sort == .recommended ? "recommended" : "latest"),
                .init(name: "limit", value: "20"),
            ])
            let iso = ISO8601DateFormatter()
            return dtos.map { dto in
                TravelReview(
                    author: dto.author,
                    location: dto.location,
                    body: dto.body,
                    likeCount: dto.likeCount,
                    commentCount: dto.commentCount,
                    createdAt: iso.date(from: dto.createdAt) ?? Date(),
                    isAccessibilityVerified: dto.isAccessibilityVerified
                )
            }
        } catch {
            return try await fallback.fetchReviews(sort: sort)
        }
    }

    // MARK: - 가공 규칙 (scripts/compose-home-feed.mjs 와 동일)

    /// 접근성 원문 정리: 첫 줄만, "_…편의시설" 꼬리표 제거, 공백 정리, 40자 컷.
    static func cleanNote(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        var t = text.components(separatedBy: .newlines).first ?? text
        t = t.replacingOccurrences(of: "_[^_]*편의시설\\s*$", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if t.count > 40 { t = String(t.prefix(39)) + "…" }
        return t.isEmpty ? nil : t
    }

    /// 뱃지 우선순위: 휠체어 > (숙소)무장애 객실 > 평탄 동선(접근로/엘리베이터/화장실) > 객실
    static func pickFeature(_ dto: BarrierFreeDTO, _ category: PlaceCategory) -> (feature: AccessibilityFeature, note: String)? {
        let wheelchair = cleanNote(dto.wheelchair)
        let room = cleanNote(dto.room)
        let route = cleanNote(dto.route)
        let elevator = cleanNote(dto.elevator)
        let restroom = cleanNote(dto.restroom)

        if let wheelchair {
            let note = wheelchair.contains("휠체어") ? wheelchair : "휠체어 \(wheelchair)"
            return (.wheelchairAccessible, note)
        }
        if category == .stay, let room { return (.barrierFreeRoom, room) }
        if let route { return (.flatPath, route) }
        if let elevator { return (.flatPath, elevator.contains("엘리베이터") ? elevator : "엘리베이터 \(elevator)") }
        if let restroom { return (.flatPath, restroom) }
        if let room { return (.barrierFreeRoom, room) }
        return nil
    }

    /// 시도명 축약 ("제주특별자치도 서귀포시" → "제주 서귀포시").
    static func shortRegion(_ addr1: String?) -> String {
        let parts = (addr1 ?? "").trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1).map(String.init)
        let province = parts.first ?? ""
        let district = parts.count > 1 ? parts[1].split(separator: " ").first.map(String.init) ?? "" : ""
        var short = provinceShort[province]
        if short == nil, province == "전남광주통합특별시" {
            short = gwangjuDistricts.contains(district) ? "광주" : "전남"
        }
        return [short ?? province, district].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static let provinceShort: [String: String] = [
        "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천",
        "광주광역시": "광주", "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종",
        "경기도": "경기", "강원특별자치도": "강원", "충청북도": "충북", "충청남도": "충남",
        "전북특별자치도": "전북", "전라남도": "전남", "경상북도": "경북", "경상남도": "경남",
        "제주특별자치도": "제주",
    ]
    private static let gwangjuDistricts: Set<String> = ["동구", "서구", "남구", "북구", "광산구"]
}
