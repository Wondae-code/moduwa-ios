import Foundation

/// 라이브 API(moduwa-backend) 연동 PlanService — `GET /v1/plans`, `GET /v1/plans/:id`, `PUT /v1/plans/:id`.
///
/// 베이스 URL·API 키는 `APIFeedService`와 같은 규칙으로 읽는다(`Secrets.plist` 또는 Info.plist).
/// 다만 피드와 달리 **번들 폴백이 없다** — 플랜은 내가 만든 데이터라 대체할 원본이 없고,
/// 목 데이터로 메우면 사용자가 만든 적 없는 여행이 자기 목록에 있는 것처럼 보인다.
/// 실패는 화면에서 오류+재시도로 알린다.
struct APIPlanService: PlanService {
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

    // MARK: - HTTP

    private struct ListResponse: Decodable { let items: [PlanDTO] }

    /// 서버가 실패 응답에 실어 주는 한국어 사유 — `{"error":"missing_authorNm","message":"…"}`
    private struct ErrorResponse: Decodable {
        let error: String?
        let message: String?
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlanServiceError.unavailable }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            // 플랜은 **개인 데이터**라 조회도 로그인 필수다. 401 의 두 뜻을 갈라 준다 —
            //  아직 로그인 안 했는지, 토큰이 낡았는지에 따라 화면이 다르게 움직인다.
            switch ModuwaAPI.authFailure(status: http.statusCode, code: failure?.error) {
            case .loginRequired: throw PlanServiceError.loginRequired
            case .expired: throw PlanServiceError.sessionExpired
            case nil: break
            }
            // 이 기기의 첫 저장이라 표시 이름을 요구하는 경우만 따로 구분한다 —
            // 호출부가 이름을 정해 한 번 더 시도할 수 있게.
            if failure?.error == "missing_authorNm" { throw PlanServiceError.nicknameRequired }
            // 서버가 무엇이 잘못됐는지 한국어로 알려 주면 그대로 쓴다. 상태 코드별 문구는 그게 없을 때의 폴백이다.
            if let message = failure?.message, !message.isEmpty {
                throw PlanServiceError.server(message: message)
            }
            switch http.statusCode {
            case 403: throw PlanServiceError.forbidden
            case 404: throw PlanServiceError.notFound
            default: throw PlanServiceError.unavailable
            }
        }
        return data
    }

    /// API 키 + **세션 토큰**. 플랜은 전 경로가 로그인 필수라 세션이 빠지면 전부 401 이다.
    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        ModuwaAPI.attachSession(to: &request)
        return request
    }

    private func url(_ path: String, _ query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }

    // MARK: - 조회

    func fetchPlans() async throws -> [Plan] {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        let data = try await data(for: authorized(url("/v1/plans")))
        return try JSONDecoder().decode(ListResponse.self, from: data).items.map(\.plan)
    }

    func fetchPlan(id: UUID) async throws -> Plan {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        let data = try await data(for: authorized(url("/v1/plans/\(id.uuidString)")))
        return try JSONDecoder().decode(PlanDTO.self, from: data).plan
    }

    /// 4/6 테마·5/6 예산 선택지. 응답이 `PlanOptions`와 같은 모양이라 DTO를 따로 두지 않는다 —
    /// 다만 `hint`는 예산에만 있어 옵셔널이다.
    func fetchPlanOptions() async throws -> PlanOptions {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        let data = try await data(for: authorized(url("/v1/plan-options")))
        return try JSONDecoder().decode(PlanOptions.self, from: data)
    }

    // MARK: - 저장 (생성·수정 공통)

    func savePlan(_ plan: Plan, authorNm: String?) async throws -> Plan {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        var request = authorized(url("/v1/plans/\(plan.id.uuidString)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PlanBody(plan: plan, authorNm: authorNm)
        )
        let data = try await data(for: request)
        return try JSONDecoder().decode(PlanDTO.self, from: data).plan
    }

    // MARK: - 추천 코스

    func recommendCourse(_ request: CourseRequest) async throws -> RecommendedCourse {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        var http = authorized(url("/v1/plans/recommend"))
        http.httpMethod = "POST"
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "region": request.regionSlug,
            "startDate": PlanWireDate.text(from: request.startDate),
            "endDate": PlanWireDate.text(from: request.endDate),
            "dayTripOnly": request.dayTripOnly,
        ]
        // 빈 배열은 보내지 않는다 — 서버는 "고르지 않음"과 "빈 목록"을 같게 다루지만,
        //  보내지 않는 편이 요청만 봐도 무엇을 고른 사람인지 분명하다.
        if !request.party.isEmpty { body["party"] = request.party }
        if !request.themes.isEmpty { body["themes"] = request.themes }
        if let budget = request.budget { body["budget"] = budget }
        http.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await data(for: http)
        return try JSONDecoder().decode(CourseDTO.self, from: data).course
    }

    // MARK: - 확정

    func setPlanConfirmed(id: UUID, _ confirmed: Bool) async throws -> Plan {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        var request = authorized(url("/v1/plans/\(id.uuidString)/confirm"))
        request.httpMethod = confirmed ? "POST" : "DELETE"
        let data = try await data(for: request)
        return try JSONDecoder().decode(PlanDTO.self, from: data).plan
    }

    // MARK: - 삭제

    func deletePlan(id: UUID) async throws {
        guard !apiKey.isEmpty else { throw PlanServiceError.unavailable }
        var request = authorized(url("/v1/plans/\(id.uuidString)"))
        request.httpMethod = "DELETE"
        // 204 라 본문이 없다. `data(for:)`를 그대로 쓰는 이유는 실패 시 서버가 주는 한국어 사유를
        // 여기서도 똑같이 살리기 위해서다 — 빈 Data 를 버리는 비용보다 그 일관성이 크다.
        _ = try await data(for: request)
    }

    // MARK: - DTO

    /// 추천 코스 응답. 저장된 플랜(`PlanDTO`)과 **다른 모양**이다 —
    /// 아직 플랜이 아니라 제안이라 id 도 제목도 없다.
    private struct CourseDTO: Decodable {
        let region: String?
        let stay: StayDTO?
        let days: [CourseDayDTO]?
        let notes: [String]?

        struct StayDTO: Decodable {
            let contentID: String?
            let name: String?
            let imageURL: String?
        }

        struct CourseDayDTO: Decodable {
            let date: String
            let items: [CourseItemDTO]?
            // congestion·busy 도 오지만 v1 화면에 그릴 자리가 없어 읽지 않는다.
        }

        struct CourseItemDTO: Decodable {
            let slot: String?
            let contentID: String?
            let name: String?
            let categoryLabel: String?
            let imageURL: String?
            let latitude: Double?
            let longitude: Double?
        }

        var course: RecommendedCourse {
            let regionLabel = region ?? ""
            let stayPlace = stay.flatMap { dto -> PlanPlace? in
                guard let name = dto.name, !name.isEmpty else { return nil }
                return PlanPlace(
                    contentID: dto.contentID, name: name, categoryLabel: "숙소",
                    region: regionLabel.isEmpty ? nil : regionLabel, category: .stay,
                    imageURL: URL(imageAddress: dto.imageURL),
                    latitude: nil, longitude: nil)
            }

            let planDays: [PlanDay] = (days ?? []).enumerated().map { index, day in
                var items: [PlanDayItem] = (day.items ?? []).compactMap { item in
                    guard let name = item.name, !name.isEmpty else { return nil }
                    return .stop(PlanStop(place: PlanPlace(
                        contentID: item.contentID,
                        name: name,
                        categoryLabel: item.categoryLabel ?? "장소",
                        region: regionLabel.isEmpty ? nil : regionLabel,
                        category: nil,
                        imageURL: URL(imageAddress: item.imageURL),
                        latitude: item.latitude,
                        longitude: item.longitude)))
                }
                // 숙소는 **묵는 날의 마지막**에 넣는다. 서버는 코스 전체에 하나로 주는데,
                //  하루 목록에 없으면 사용자는 "숙소는 어디로 갔지"가 된다.
                //  마지막 날에는 넣지 않는다 — 그날은 자고 나오는 날이다.
                if let stayPlace, index < (days ?? []).count - 1 {
                    items.append(.stop(PlanStop(place: stayPlace)))
                }
                return PlanDay(date: PlanWireDate.date(from: day.date) ?? .now, items: items)
            }

            return RecommendedCourse(
                regionLabel: regionLabel,
                stay: stayPlace,
                days: planDays,
                // 모르는 note 는 버린다 — 서버가 새 사유를 늘려도 앱이 깨지지 않는다.
                notes: (notes ?? []).compactMap(CourseNote.init(rawValue:)))
        }
    }

    /// 목록·상세·저장 응답이 모두 같은 모양이다 (목록에만 `days`가 빠진다).
    private struct PlanDTO: Decodable {
        let id: UUID
        let title: String
        /// `YYYY-MM-DD`
        let startDate: String
        let endDate: String
        let region: String?
        let party: PartyDTO?
        let coverImageURL: String?
        let themes: [String]?
        let budget: String?
        let dayTripOnly: Bool?
        /// 확정 시각(ISO8601 UTC). null 이면 초안이다. 구 서버에는 없어 옵셔널이다.
        let confirmedAt: String?
        /// ISO8601 UTC
        let createdAt: String?
        let updatedAt: String?
        /// **목록 응답에는 없다** — 없으면 "일정이 없다"가 아니라 "아직 안 받았다"는 뜻이다.
        let days: [DayDTO]?
        /// **목록 응답에만 있다.** 카드가 그릴 날짜별 장소 이름(서버 `9f8a752`).
        /// 구 서버와도 붙을 수 있게 옵셔널로 둔다 — 없으면 카드가 DAY 줄을 안 그릴 뿐이다.
        let daySummaries: [DaySummaryDTO]?
        let fallbackImageUrl: String?

        var plan: Plan {
            Plan(
                id: id,
                title: title,
                startDate: PlanWireDate.date(from: startDate) ?? .now,
                endDate: PlanWireDate.date(from: endDate) ?? .now,
                // 서버가 앱이 모르는 지역 키를 주면 지역 없음으로 둔다 — 지역은 표시에만 쓰여
                // 플랜 전체를 못 읽는 이유가 될 수 없다.
                region: region.flatMap(TravelRegion.init(rawValue:)),
                party: party?.party ?? TravelParty(),
                coverImageURL: URL(imageAddress: coverImageURL),
                themes: themes ?? [],
                budget: budget,
                dayTripOnly: dayTripOnly ?? false,
                days: (days ?? []).map(\.day),
                daySummaries: (daySummaries ?? []).map(\.summary),
                fallbackImageURL: URL(imageAddress: fallbackImageUrl),
                // ⚠️ `timestamp(from:)`이 아니다 — 그쪽은 못 읽으면 지금 시각으로 떨어져
                // 초안이 확정된 것으로 뒤바뀐다.
                confirmedAt: PlanWireDate.optionalTimestamp(from: confirmedAt),
                createdAt: PlanWireDate.timestamp(from: createdAt),
                updatedAt: PlanWireDate.timestamp(from: updatedAt)
            )
        }
    }

    /// 목록 카드용 하루 요약. 날짜를 못 읽으면 그 줄만 버린다 — 카드 한 줄 때문에
    /// 플랜 전체를 못 읽을 이유가 없다(`region`을 다루는 방식과 같다).
    private struct DaySummaryDTO: Decodable {
        let id: UUID
        /// `YYYY-MM-DD`
        let date: String
        let placeNames: [String]?

        var summary: PlanDaySummary {
            PlanDaySummary(
                id: id,
                date: PlanWireDate.date(from: date) ?? .now,
                placeNames: placeNames ?? []
            )
        }
    }

    /// 세 축 모두 서버 jsonb에 없을 수 있다 — 시안 1/6에서 한 축만 고르고 넘어갈 수 있어서다.
    /// (`TravelParty`를 그대로 디코딩하면 빠진 키에서 실패한다. 합성된 `init(from:)`은
    /// 프로퍼티 기본값을 쓰지 않는다.)
    private struct PartyDTO: Codable {
        let ageGroups: [String]?
        let companions: [String]?
        let mobilities: [String]?

        init(_ party: TravelParty) {
            ageGroups = party.ageGroups.map(\.rawValue)
            companions = party.companions.map(\.rawValue)
            mobilities = party.mobilities.map(\.rawValue)
        }

        /// 앱이 모르는 값은 버린다 — 동반자 정보 한 항목 때문에 플랜을 통째로 못 읽으면 안 된다.
        var party: TravelParty {
            TravelParty(
                ageGroups: Set((ageGroups ?? []).compactMap(AgeGroup.init(rawValue:))),
                companions: Set((companions ?? []).compactMap(CompanionType.init(rawValue:))),
                mobilities: Set((mobilities ?? []).compactMap(MobilityMode.init(rawValue:)))
            )
        }
    }

    private struct DayDTO: Decodable {
        let id: UUID
        /// `YYYY-MM-DD`
        let date: String
        let items: [ItemDTO]

        var day: PlanDay {
            PlanDay(id: id, date: PlanWireDate.date(from: date) ?? .now, items: items.map(\.item))
        }
    }

    /// `kind` 판별자로 갈라지는 합타입.
    ///
    /// `place`·`text`를 둘 다 옵셔널로 받아 두고 나중에 분기하는 방법도 있지만, 그러면
    /// `{"kind":"stop"}` 처럼 알맹이가 빠진 항목이 조용히 통과해 빈 장소가 목록에 남는다.
    /// 모르는 `kind`에서 던지는 것도 같은 이유다 — 조용히 건너뛰면 사용자에게는 항목이
    /// 사라진 것으로 보이고, 그 상태로 저장하면 서버에서도 진짜로 사라진다.
    private enum ItemDTO: Codable {
        case stop(id: UUID, place: PlaceDTO)
        case memo(id: UUID, text: String)

        private enum CodingKeys: String, CodingKey { case id, kind, place, text }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decode(UUID.self, forKey: .id)
            let kind = try container.decode(String.self, forKey: .kind)
            switch kind {
            case "stop":
                self = .stop(id: id, place: try container.decode(PlaceDTO.self, forKey: .place))
            case "memo":
                self = .memo(id: id, text: try container.decode(String.self, forKey: .text))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: container, debugDescription: "알 수 없는 일정 항목 종류: \(kind)")
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .stop(let id, let place):
                try container.encode(id, forKey: .id)
                try container.encode("stop", forKey: .kind)
                try container.encode(place, forKey: .place)
            case .memo(let id, let text):
                try container.encode(id, forKey: .id)
                try container.encode("memo", forKey: .kind)
                try container.encode(text, forKey: .text)
            }
        }

        init(_ item: PlanDayItem) {
            switch item {
            case .stop(let stop): self = .stop(id: stop.id, place: PlaceDTO(stop.place))
            case .memo(let memo): self = .memo(id: memo.id, text: memo.text)
            }
        }

        var item: PlanDayItem {
            switch self {
            case .stop(let id, let place): .stop(PlanStop(id: id, place: place.place))
            // 서버 스키마에 메모 작성 시각이 없다. 화면이 쓰지 않는 값이라 굳이 실어 보내지 않고,
            // 다시 받을 때는 지금 시각으로 채운다.
            case .memo(let id, let text): .memo(PlanMemo(id: id, text: text))
            }
        }
    }

    private struct PlaceDTO: Codable {
        /// 서버도 대문자 ID를 쓴다 (`contentId`가 아니다)
        let contentID: String?
        let name: String
        let categoryLabel: String
        let region: String?
        let category: String?
        let imageURL: String?
        let latitude: Double?
        let longitude: Double?

        init(_ place: PlanPlace) {
            contentID = place.contentID
            name = place.name
            categoryLabel = place.categoryLabel
            region = place.region
            category = place.category?.apiKey
            imageURL = place.imageURL?.absoluteString
            latitude = place.latitude
            longitude = place.longitude
        }

        var place: PlanPlace {
            PlanPlace(
                contentID: contentID,
                name: name,
                categoryLabel: categoryLabel,
                region: region,
                // 시안의 부제목은 `PlaceCategory` 4종을 벗어난다("쇼핑") — 매핑되지 않으면 nil이고
                // 표시에는 `categoryLabel`을 쓴다(`PlanPlace` 참고).
                category: PlaceCategory.allCases.first { $0.apiKey == category },
                imageURL: URL(imageAddress: imageURL),
                latitude: latitude,
                longitude: longitude
            )
        }
    }

    // MARK: - 저장 본문

    private struct PlanBody: Encodable {
        /// nil이면 키 자체가 빠지고(Optional은 encodeIfPresent로 인코딩된다) 서버가 기존 닉네임을 재사용한다
        let authorNm: String?
        let title: String
        let startDate: String
        let endDate: String
        let region: String?
        let party: PartyDTO
        let coverImageURL: String?
        /// ⚠️ 저장은 **통째 교체**다. 이 셋을 안 실어 보내면 서버 값이 기본값으로 되돌아간다 —
        ///  새 플랜 플로우가 채운 테마·예산이 상세에서 순서 한 번 바꿨다고 조용히 사라진다.
        let themes: [String]
        let budget: String?
        let dayTripOnly: Bool
        let days: [DayBody]

        init(plan: Plan, authorNm: String?) {
            self.authorNm = authorNm
            title = plan.title
            startDate = PlanWireDate.text(from: plan.startDate)
            endDate = PlanWireDate.text(from: plan.endDate)
            region = plan.region?.rawValue
            party = PartyDTO(plan.party)
            coverImageURL = plan.coverImageURL?.absoluteString
            themes = plan.themes
            budget = plan.budget
            dayTripOnly = plan.dayTripOnly
            days = plan.days.map(DayBody.init)
        }
    }

    private struct DayBody: Encodable {
        let id: UUID
        let date: String
        let items: [ItemDTO]

        init(_ day: PlanDay) {
            id = day.id
            date = PlanWireDate.text(from: day.date)
            items = day.items.map(ItemDTO.init)
        }
    }
}

// MARK: - 날짜 표기

/// 서버가 쓰는 **두 가지** 날짜 표기를 오간다.
///
/// `startDate`/`endDate`/`days[].date`는 날짜만(`2026-09-01`)이고 `createdAt`/`updatedAt`은
/// ISO8601 UTC(`2026-08-09T12:34:56Z`)다. `JSONDecoder.dateDecodingStrategy` 하나로는 둘 다 읽을 수
/// 없어 문자열로 받아 여기서 바꾼다.
///
/// 날짜만 오는 값은 **현지 자정**으로 읽고 쓴다. 화면의 `Plan.isPast()`와 "7/26 목" 표기가 전부
/// `Calendar.current` 기준이라, UTC 자정으로 만들면 한국에서 하루가 밀려 보인다.
private enum PlanWireDate {
    static func date(from text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func text(from date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 생성·수정 시각. 화면에 쓰이지 않는 값이라 못 읽어도 실패로 다루지 않는다.
    static func timestamp(from text: String?) -> Date {
        optionalTimestamp(from: text) ?? Date()
    }

    /// 확정 시각처럼 **없음이 뜻을 가지는** 값. `timestamp(from:)`은 못 읽으면 지금 시각으로
    /// 떨어지는데, 여기서 그러면 초안이 확정된 것으로 뒤바뀐다.
    static func optionalTimestamp(from text: String?) -> Date? {
        text.flatMap { try? Date($0, strategy: .iso8601) }
    }
}
