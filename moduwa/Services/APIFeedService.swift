import Foundation

/// 라이브 API(moduwa-backend) 연동 FeedService.
///
/// - 장소: `GET /v1/barrier-free` (무장애 28속성) → 번들 생성 스크립트와 동일한 가공 규칙으로 Place 매핑
/// - 리뷰: `GET /v1/reviews`
/// - 히어로 카드: 서버 소스가 없어 번들 값 사용
///
/// **API 키**: 번들의 `Secrets.plist`(gitignore 대상, `Secrets.plist.example` 참고) 또는
/// Info.plist의 `MODUWA_API_KEY` 에서 읽는다. 키는 moduwa-backend의
/// `scripts/gen-api-key.mjs`로 발급해 배포 서버(Railway)의 `API_KEYS` 환경변수에 등록해야 한다.
/// 키가 없거나 네트워크/디코딩이 실패하면 `BundledFeedService`(번들 JSON)로 **자동 폴백**하므로,
/// 키 미설정 상태에서도 앱은 기존 번들 데이터로 정상 동작한다.
struct APIFeedService: FeedService {
    /// 로컬 백엔드 테스트: 시뮬레이터 실행 시 `SIMCTL_CHILD_MODUWA_API_BASE_URL=http://localhost:8080` 로 오버라이드
    private let baseURL = URL(
        string: ProcessInfo.processInfo.environment["MODUWA_API_BASE_URL"]
            ?? "https://moduwa-backend-production.up.railway.app"
    )!
    private let apiKey: String
    private let session: URLSession
    private let fallback = BundledFeedService()

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? Secrets.moduwaAPIKey
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

    /// 서버가 실패 응답에 실어 주는 한국어 사유 — `{"error":"missing_body","message":"…"}`
    private struct ErrorResponse: Decodable {
        /// 기계가 분기할 수 있는 사유 코드(`missing_authorNm` 등)
        let error: String?
        let message: String?
    }

    /// API 키 + **로그인했으면 세션 토큰**을 붙인 요청.
    ///
    /// 두 헤더는 서로 다른 질문에 답한다 — 키는 "이 앱이 호출해도 되는가", 세션은
    /// "이 요청이 누구인가"다(`ModuwaAPI`). 세션을 빼먹으면 쓰기는 401 이고, 목록은 성공하지만
    /// 하트가 누른 글에서도 빈 상태로 그려진다.
    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        ModuwaAPI.attachSession(to: &request)
        return request
    }

    /// 실패 응답을 사용자에게 보여 줄 오류로 바꾼다.
    ///
    /// 401 은 두 뜻이라 갈라야 한다 — 아직 로그인하지 않았는지(`login_required`),
    /// 토큰이 낡았는지(`session_expired`). 후자는 `ModuwaAPI` 가 토큰을 버리고 화면에 알린다.
    private func failure(status: Int, data: Data) -> FeedServiceError {
        let body = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        switch ModuwaAPI.authFailure(status: status, code: body?.error) {
        case .loginRequired: return .loginRequired
        case .expired: return .sessionExpired
        case nil: break
        }
        if let message = body?.message, !message.isEmpty { return .server(message: message) }
        return .writeUnsupported
    }

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem] = []) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.notConfigured }
        var comps = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        let (data, resp) = try await session.data(for: authorized(comps.url!))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            // 로그인 문제는 그대로 알려야 한다. 개인 데이터 조회(`/v1/saved-places`)가 401 인데
            //  일반 실패로 뭉개면 화면이 "불러오지 못했어요"를 띄우고, 사용자는 로그인하면
            //  된다는 것을 알 수 없다.
            if status == 401 { throw failure(status: status, data: data) }
            throw APIError.badStatus(status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func getItems<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> [T] {
        let list: ListResponse<T> = try await get(path, query)
        return list.items
    }


    // MARK: - Places

    private struct BarrierFreeDTO: Decodable {
        let contentid: String?
        let title: String?
        let addr1: String?
        let firstimage: String?
        // 이동 그룹
        let wheelchair: String?
        let room: String?
        let route: String?
        let elevator: String?
        let restroom: String?
        // 시각·청각·영유아 그룹. 서버는 목록 응답에도 28속성을 전부 싣는데 앱이 이동 계열만
        //  읽고 있었다 — 그래서 무엇을 고르든 카드가 휠체어 뱃지와 휠체어 문구만 보여 줬다.
        var braileblock: String? = nil
        var audioguide: String? = nil
        var guidehuman: String? = nil
        var brailepromotion: String? = nil
        var bigprint: String? = nil
        var guidesystem: String? = nil
        var blindhandicapetc: String? = nil
        var signguide: String? = nil
        var videoguide: String? = nil
        var hearingroom: String? = nil
        var hearinghandicapetc: String? = nil
        var stroller: String? = nil
        var lactationroom: String? = nil
        var babysparechair: String? = nil
        var infantsfamilyetc: String? = nil
        /// 저장 목록에서만 쓴다 — 홈 피드는 어느 카테고리를 요청했는지 알고 부르지만
        /// 저장 목록은 종류가 섞여 오므로 응답의 타입으로 판단해야 섹션을 나눌 수 있다.
        var contenttypeid: String? = nil
        /// 저장 목록에서만 온다. barrier_free 에 없는 값이라 서버가 후기에서 집계해 얹어 준다.
        var avgRating: Double? = nil
        // 2026-08-24 추가. 고령자 판정 결과(평면). boolean 이라 문구는 판정 근거 속성
        //  (승강기·주차)에서 뽑는다(note(for:.elderlyFriendly) 참고).
        var parking: String? = nil
    }

    /// contentTypeId → 앱 카테고리. `typeId(_:)`의 역이다.
    /// 모르는 타입은 nil — 관광공사 타입은 앱이 쓰는 4종보다 많다.
    private static func category(forTypeId id: String?) -> PlaceCategory? {
        switch id {
        case "32": .stay
        case "39": .food
        case "12": .attraction
        case "15": .festival
        default: nil
        }
    }

    // MARK: - 저장한 장소

    /// 서버가 무장애 목록과 **같은 모양**(`BF_COLS`)으로 돌려주므로 같은 DTO 로 읽는다.
    /// 다른 것은 카테고리와 평점뿐이다.
    ///
    /// ⚠️ 폴백이 없다. 저장한 장소는 사용자가 만든 데이터라 번들에 대신할 원본이 없다 —
    /// 실패는 화면이 오류+재시도로 알린다(`APIPlanService` 와 같은 규칙).
    func fetchSavedPlaces(accessFeatures: [AccessibilityFeature]) async throws -> [Place] {
        // 소유자는 **세션의 계정**이다. deviceId 를 싣던 자리인데, 그 값은 이제 신원이 아니다
        //  (아는 사람이 남의 저장 목록을 볼 수 있던 경로였다 — 백엔드 030).
        let dtos: [BarrierFreeDTO] = try await getItems("/v1/saved-places", [])
        return dtos.compactMap { dto in
            guard let id = dto.contentid,
                  let name = dto.title?.trimmingCharacters(in: .whitespaces), !name.isEmpty
            else { return nil }
            let category = Self.category(forTypeId: dto.contenttypeid) ?? .attraction
            let img = (dto.firstimage ?? "").replacingOccurrences(of: "http://", with: "https://")
            // 접근성 한 줄을 못 고르면 카드 마지막 줄이 빌 뿐이다 — 홈 피드처럼 장소를 버리지
            // 않는다. 사용자가 직접 저장한 것이라 앱이 임의로 감출 수 없다.
            // 홈과 같은 기준으로 뱃지·문구를 고른다 — 같은 장소가 탭마다 다른 뱃지로
            //  보이면, 어느 쪽이 그 장소에 대한 사실인지 알 수 없다.
            let picked = Self.pickFeature(dto, category, preferring: accessFeatures)
            return Place(
                id: id,
                name: name,
                region: Self.shortRegion(dto.addr1),
                rating: dto.avgRating,
                accessibilityNote: picked?.note ?? "",
                feature: picked?.feature ?? .wheelchairAccessible,
                category: category,
                imageURL: URL(string: img)
            )
        }
    }

    func setPlaceSaved(contentId: String, _ saved: Bool) async throws {
        guard !apiKey.isEmpty else { throw FeedServiceError.writeUnsupported }
        var req = authorized(baseURL.appending(path: "/v1/saved-places/\(contentId)"))
        req.httpMethod = saved ? "PUT" : "DELETE"

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw failure(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }
    }

    private struct ReviewLikeDTO: Decodable { let likeCount: Int; let likedByMe: Bool }

    func setReviewLiked(reviewId: Int, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool) {
        guard !apiKey.isEmpty else { throw FeedServiceError.writeUnsupported }
        var req = authorized(baseURL.appending(path: "/v1/reviews/\(reviewId)/like"))
        req.httpMethod = liked ? "PUT" : "DELETE"
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw failure(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }
        let result = try JSONDecoder().decode(ReviewLikeDTO.self, from: data)
        return (likeCount: result.likeCount, likedByMe: result.likedByMe)
    }

    func fetchRecommendedPlaces(
        category: PlaceCategory, page: Int, accessFeatures: [AccessibilityFeature]
    ) async throws -> [Place] {
        do {
            // ⚠️ `hasImage`를 걸지 않는다. 걸면 무장애 장소 5곳 중 1곳(2,045/10,262)이 홈에서
            //  통째로 빠진다 — 그런데 사진 유무로 접근성 정보량이 갈리지 않는다(2026-08-16 측정:
            //  무사진 평균 4.0 / 유사진 4.4, 최대 둘 다 18). 사진이 없다는 건 관광공사가 사진을
            //  안 올렸다는 뜻일 뿐이라, 무장애 여행 앱에서 그걸로 후보를 지울 이유가 없다.
            //  대신 서버의 `access` 정렬이 감점 3으로 뒤로 민다(백엔드 a153987).
            var query: [URLQueryItem] = [
                .init(name: "type", value: typeId(category)),
                .init(name: "hasAccess", value: "true"),
                .init(name: "limit", value: "\(FeedPage.placeSize)"),
                .init(name: "offset", value: "\(page * FeedPage.placeSize)"),
            ]
            // 고른 무장애 요소로 좁힌다. 서버가 모르는 축(고령자 친화)은 여기서 빠진다 —
            //  보내 봐야 서버가 무시하고, 무엇으로 좁혔는지 화면과 어긋나게 된다.
            let groups = accessFeatures.compactMap(\.serverAccessGroup)
            if !groups.isEmpty {
                query.append(.init(name: "access", value: groups.joined(separator: ",")))
            }
            let dtos: [BarrierFreeDTO] = try await getItems("/v1/barrier-free", query)
            let places: [Place] = dtos.compactMap { dto in
                guard let id = dto.contentid, let name = dto.title?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
                      // 목록을 좁힌 것과 **같은 기준**으로 뱃지·문구를 고른다.
                      let picked = Self.pickFeature(dto, category, preferring: accessFeatures)
                else { return nil }
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
            return places
        } catch {
            // 번들 폴백에는 무장애 요소별 목록이 없다 — 좁히지 못한 채로라도 보여 준다.
            return try await fallback.fetchRecommendedPlaces(
                category: category, page: page, accessFeatures: [])
        }
    }

    // MARK: - Place Detail

    /// 무장애 28속성 상세 DTO — 카테고리 매핑에 쓰는 필드만 디코딩
    private struct BarrierFreeDetailDTO: Decodable {
        struct BasicInfo: Decodable {
            let usetime: String?
            let restdate: String?
            let parking: String?
            let fee: String?
        }

        let contentid: String?
        let title: String?
        let addr1: String?
        let addr2: String?
        let firstimage: String?
        let mapx: Double?
        let mapy: Double?
        /// 서버가 kakao_place 매칭으로 준 카카오맵 장소 상세 링크(M6). 매칭 안 되면 null.
        var kakaoPlaceUrl: String? = nil
        // kor_detail enrich (구 서버 호환을 위해 전부 옵셔널)
        let overview: String?
        let homepage: String?
        let tel: String?
        let basicInfo: BasicInfo?

        // 지체장애인(이동) 계열
        let wheelchair: String?
        let exit: String?
        let elevator: String?
        let route: String?
        let parking: String?
        let restroom: String?
        let publictransport: String?
        let ticketoffice: String?
        let promotion: String?
        let auditorium: String?
        let room: String?
        let handicapetc: String?
        // 시각장애인 계열
        let braileblock: String?
        let helpdog: String?
        let guidehuman: String?
        let audioguide: String?
        let bigprint: String?
        let brailepromotion: String?
        let guidesystem: String?
        let blindhandicapetc: String?
        // 청각장애인 계열
        let signguide: String?
        let videoguide: String?
        let hearingroom: String?
        let hearinghandicapetc: String?
        // 유아동반 계열
        let stroller: String?
        let lactationroom: String?
        let babysparechair: String?
        let infantsfamilyetc: String?
    }

    func fetchPlaceDetail(contentId: String) async throws -> PlaceDetail {
        do {
            guard !apiKey.isEmpty else { throw APIError.notConfigured }
            let (data, resp) = try await session.data(
                for: authorized(baseURL.appending(path: "/v1/barrier-free/\(contentId)")))
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let dto = try JSONDecoder().decode(BarrierFreeDetailDTO.self, from: data)

            // 접근성 유형별 속성 그룹 → 뱃지 + bullet 문장
            let groups: [(AccessibilityFeature, [String?])] = [
                (.wheelchairAccessible, [dto.wheelchair, dto.exit, dto.elevator, dto.route, dto.parking,
                                         dto.restroom, dto.publictransport, dto.ticketoffice, dto.promotion,
                                         dto.auditorium, dto.room, dto.handicapetc]),
                (.visuallyImpairedFriendly, [dto.braileblock, dto.helpdog, dto.guidehuman, dto.audioguide,
                                             dto.bigprint, dto.brailepromotion, dto.guidesystem, dto.blindhandicapetc]),
                (.hearingFriendly, [dto.signguide, dto.videoguide, dto.hearingroom, dto.hearinghandicapetc]),
                (.childFriendly, [dto.stroller, dto.lactationroom, dto.babysparechair, dto.infantsfamilyetc]),
            ]
            let accessibilityGroups: [PlaceDetail.AccessibilityGroup] = groups.compactMap { feature, values in
                let cleaned = values.compactMap { Self.cleanNote($0) }
                return cleaned.isEmpty ? nil : .init(feature: feature, notes: cleaned)
            }

            let img = (dto.firstimage ?? "").replacingOccurrences(of: "http://", with: "https://")
            let address = [dto.addr1, dto.addr2]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            // 기본정보 — 값이 있는 행만 (Figma 기본정보 섹션 순서)
            var info: [PlaceDetail.InfoRow] = []
            if let v = dto.basicInfo?.usetime { info.append(.init(label: "운영시간", value: v)) }
            if let v = dto.basicInfo?.restdate { info.append(.init(label: "휴무일", value: v)) }
            if let v = dto.basicInfo?.parking { info.append(.init(label: "주차정보", value: v)) }
            if let v = dto.basicInfo?.fee { info.append(.init(label: "이용요금", value: v)) }
            if let v = dto.tel { info.append(.init(label: "전화번호", value: v)) }
            if let v = dto.homepage { info.append(.init(label: "홈페이지", value: v, isLink: true)) }

            return PlaceDetail(
                id: dto.contentid ?? contentId,
                name: dto.title?.trimmingCharacters(in: .whitespaces) ?? "",
                address: address,
                imageURL: URL(string: img),
                rating: nil,      // 평점·리뷰수 데이터 소스 없음
                reviewCount: nil,
                overview: dto.overview.map {
                    Self.htmlToPlainText($0)
                        .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                },
                info: info,
                accessibilityGroups: accessibilityGroups,
                cautionTags: [],
                latitude: dto.mapy,
                longitude: dto.mapx,
                // 서버가 이미 https 로 정규화해 주지만(A14), 기존 규칙과 일관되게 한 번 더 올려도 무해하다.
                kakaoPlaceURL: URL(imageAddress: dto.kakaoPlaceUrl)
            )
        } catch {
            return try await fallback.fetchPlaceDetail(contentId: contentId)
        }
    }

    // MARK: - Reviews

    private struct ReviewDTO: Decodable {
        /// 서버 리뷰 id — 댓글 API(`/v1/reviews/:reviewId/comments`)의 경로 키다.
        let id: Int
        /// ⚠️ 최상위 `author`는 예전부터 **String**이다. 작성자 상세는 객체로 바뀐 게 아니라
        /// `authorInfo`가 따로 덧붙은 형태라 이 필드를 객체로 바꾸면 안 된다.
        let author: String
        let location: String
        let body: String
        let likeCount: Int
        let commentCount: Int
        /// 로그인 요청에서만 true 가능. 서버가 보는 사람 기준으로 준다(비로그인·구버전 응답은 없음 → false).
        var likedByMe: Bool? = nil
        let createdAt: String
        let isAccessibilityVerified: Bool
        /// 구 서버 호환을 위해 옵셔널 (필드 없으면 사진 없음으로 처리)
        let imageURLs: [String]?
        /// 방문한 장소 contentId — 자유 방문지면 null
        let contentId: String?
        /// 별점 없이 본문만 남긴 후기가 있어 null 가능
        let rating: Int?
        let authorInfo: AuthorInfoDTO?
        /// 작성자가 고른 태그. 구 서버 호환을 위해 옵셔널.
        let tags: [ReviewTagDTO]?
        /// true / false / 미응답(null) 세 상태
        let wouldRevisit: Bool?

        struct AuthorInfoDTO: Decodable {
            let nickname: String?
            let reviewCount: Int?
            let level: Int?
            /// 프로필 사진(042). 서버가 https 로만 내려준다.
            let avatarUrl: String?
        }
    }

    /// `/v1/review-tags`, 후기 항목의 `tags[]`, 집계의 `tags[]`가 같은 모양이다
    /// (집계에만 `count`가 더 붙는다).
    private struct ReviewTagDTO: Decodable {
        let code: String
        let label: String
        let shortLabel: String?
        let icon: String?
        let count: Int?

        var tag: ReviewTag {
            ReviewTag(code: code, label: label, shortLabel: shortLabel ?? label, icon: icon)
        }
    }

    /// 홈 피드·장소별 목록이 같은 DTO를 쓰므로 매핑을 한 곳에 둔다.
    /// (`ISO8601DateFormatter`는 Sendable이 아니라 static으로 캐시하지 않고 값 타입 파서를 쓴다)
    private static func travelReview(_ dto: ReviewDTO) -> TravelReview {
        TravelReview(
            serverId: dto.id,
            author: dto.author,
            location: dto.location,
            body: dto.body,
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            likedByMe: dto.likedByMe ?? false,
            createdAt: (try? Date(dto.createdAt, strategy: .iso8601)) ?? Date(),
            isAccessibilityVerified: dto.isAccessibilityVerified,
            imageURLs: (dto.imageURLs ?? []).compactMap {
                URL(string: $0.replacingOccurrences(of: "http://", with: "https://"))
            },
            contentId: dto.contentId,
            rating: dto.rating,
            authorLevel: dto.authorInfo?.level,
            authorReviewCount: dto.authorInfo?.reviewCount,
            authorAvatarURL: URL(imageAddress: dto.authorInfo?.avatarUrl),
            tags: (dto.tags ?? []).map(\.tag),
            wouldRevisit: dto.wouldRevisit
        )
    }

    // MARK: - 후기 태그 사전

    func fetchReviewTags() async throws -> [ReviewTag] {
        let dtos: [ReviewTagDTO] = try await getItems("/v1/review-tags", [])
        return dtos.map(\.tag)
    }

    func fetchReviews(sort: ReviewSort, page: Int) async throws -> [TravelReview] {
        do {
            let dtos: [ReviewDTO] = try await getItems("/v1/reviews", [
                .init(name: "sort", value: sort == .recommended ? "recommended" : "latest"),
                .init(name: "limit", value: "\(FeedPage.reviewSize)"),
                .init(name: "offset", value: "\(page * FeedPage.reviewSize)"),
            ])
            return dtos.map(Self.travelReview)
        } catch {
            return try await fallback.fetchReviews(sort: sort, page: page)
        }
    }

    // MARK: - 장소별 후기 (집계 · 목록 · 등록)

    private struct ReviewSummaryDTO: Decodable {
        let contentId: String
        /// 별점이 하나도 없으면 null
        let avgRating: Double?
        let reviewCount: Int
        let ratedCount: Int
        /// 구 서버 호환을 위해 옵셔널
        let tags: [ReviewTagDTO]?
    }

    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary {
        let dto: ReviewSummaryDTO = try await get("/v1/reviews/summary", [
            .init(name: "contentId", value: contentId),
        ])
        return PlaceReviewSummary(
            contentId: dto.contentId,
            averageRating: dto.avgRating,
            reviewCount: dto.reviewCount,
            ratedCount: dto.ratedCount,
            // count가 없는 항목은 집계로 쓸 수 없다 (막대 길이를 정할 수 없다)
            tags: (dto.tags ?? []).compactMap { dto in
                dto.count.map { ReviewTagCount(tag: dto.tag, count: $0) }
            }
        )
    }

    /// 여기는 `fallback`으로 넘기지 않는다. 번들·목 후기는 **다른 장소**의 후기라서
    /// 폴백하면 이 장소가 남긴 적 없는 후기를 보여 주게 된다. 실패는 화면에서 에러로 알린다.
    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool, page: Int, pageSize: Int
    ) async throws -> [TravelReview] {
        var query: [URLQueryItem] = [
            .init(name: "contentId", value: contentId),
            .init(name: "sort", value: sort.apiValue),
            .init(name: "limit", value: "\(pageSize)"),
            .init(name: "offset", value: "\(page * pageSize)"),
        ]
        // false를 보내지 않는다 — 필터가 꺼진 상태는 "조건 없음"이다
        if hasImage { query.append(.init(name: "hasImage", value: "true")) }
        let dtos: [ReviewDTO] = try await getItems("/v1/reviews", query)
        return dtos.map(Self.travelReview)
    }

    // MARK: - 사진 업로드

    private struct UploadedImageDTO: Decodable {
        let url: String
    }

    /// multipart/form-data. 필드명은 서버 규약대로 **`files`** 고정이고 여러 장을 같은 이름으로 반복한다.
    /// (장당 2MB · 요청 전체 10MB · 최대 5장 — 초과분은 서버가 한국어 사유로 400을 준다)
    func uploadReviewImages(_ images: [Data]) async throws -> [URL] {
        guard !images.isEmpty else { return [] }
        guard !apiKey.isEmpty else { throw FeedServiceError.writeUnsupported }

        let boundary = "moduwa-\(UUID().uuidString)"
        var body = Data()
        for (index, image) in images.enumerated() {
            body.append("--\(boundary)\r\n")
            body.append(
                "Content-Disposition: form-data; name=\"files\"; filename=\"review-\(index).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(image)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")

        var req = authorized(baseURL.appending(path: "/v1/reviews/images"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
            throw message.map { FeedServiceError.server(message: $0) } ?? .imageUploadFailed
        }
        let list = try JSONDecoder().decode(ListResponse<UploadedImageDTO>.self, from: data)
        // 반환 URL은 인증 없이 열리므로 AsyncImage에 그대로 쓸 수 있다.
        return list.items.compactMap { URL(string: $0.url) }
    }

    private struct ReviewCreateBody: Encodable {
        let contentId: String?
        let locationNm: String
        let rating: Int
        let body: String
        /// 계정 닉네임을 갱신한다. 사용자가 직접 정한 이름만 담고, 아니면 nil —
        /// 서버는 nil 이면 계정에 이미 있는 닉네임을 그대로 쓴다.
        let authorNm: String?
        let tags: [String]
        /// **nil이면 키 자체가 빠진다**(`JSONEncoder`의 기본 동작) — 서버는 그때 `null`로 저장하고
        /// 별점으로 추측하지 않는다. 미응답을 false로 바꿔 보내면 "다시 오지 않겠다"가 되어 버린다.
        let wouldRevisit: Bool?
        let imageURLs: [String]
    }

    /// **로그인 필수**다(백엔드 030). 작성자는 세션의 계정이고, 비로그인 요청은 401 이다.
    func submitReview(_ draft: ReviewDraft) async throws {
        guard !apiKey.isEmpty else { throw FeedServiceError.writeUnsupported }
        var req = authorized(baseURL.appending(path: "/v1/reviews"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            ReviewCreateBody(
                contentId: draft.contentId,
                locationNm: draft.placeName,
                rating: draft.rating,
                body: draft.body,
                authorNm: draft.nickname.isEmpty ? nil : draft.nickname,
                tags: draft.tags,
                wouldRevisit: draft.wouldRevisit,
                imageURLs: draft.imageURLs.map(\.absoluteString)
            )
        )
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // 400대는 서버가 무엇이 잘못됐는지 한국어로 알려 준다 — 그대로 사용자에게 보여 준다.
            throw failure(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }
    }

    // MARK: - 리뷰 댓글

    /// 댓글 목록 응답은 `items` 말고 `total`도 필요해서 `ListResponse`를 쓰지 않는다
    /// (화면의 댓글 수를 이 `total` 하나로 정한다 — `ReviewCommentPage` 참고).
    private struct CommentListResponse: Decodable {
        let total: Int
        let items: [CommentDTO]
    }

    private struct CommentDTO: Decodable {
        let id: Int
        let author: String
        let body: String
        let createdAt: String
        /// 후기의 `authorInfo`와 같은 모양이라 DTO를 재사용한다
        let authorInfo: ReviewDTO.AuthorInfoDTO?

        var comment: ReviewComment {
            ReviewComment(
                id: id,
                author: author,
                body: body,
                createdAt: (try? Date(createdAt, strategy: .iso8601)) ?? Date(),
                authorLevel: authorInfo?.level,
                authorReviewCount: authorInfo?.reviewCount,
                authorAvatarURL: URL(imageAddress: authorInfo?.avatarUrl)
            )
        }
    }

    /// `fallback`으로 넘기지 않는다 — 번들에는 댓글이 아예 없고, 있었다 해도 **다른 리뷰**의
    /// 댓글이 이 리뷰 밑에 붙게 된다. 실패는 화면에서 에러+재시도로 알린다.
    func fetchReviewComments(
        reviewId: Int, page: Int, pageSize: Int
    ) async throws -> ReviewCommentPage {
        let response: CommentListResponse = try await get("/v1/reviews/\(reviewId)/comments", [
            .init(name: "limit", value: "\(pageSize)"),
            .init(name: "offset", value: "\(page * pageSize)"),
        ])
        return ReviewCommentPage(total: response.total, items: response.items.map(\.comment))
    }

    private struct CommentCreateBody: Encodable {
        let body: String
        /// 사용자가 실제로 정한 이름만 담는다. nil 이면 키 자체가 빠지고(Optional 은 encodeIfPresent 로
        /// 인코딩된다) 서버가 이 기기의 기존 닉네임을 그대로 재사용한다.
        let authorNm: String?
    }

    /// **로그인 필수**다. 작성자는 세션의 계정이라 `deviceId` 를 싣지 않는다.
    func submitReviewComment(reviewId: Int, body: String, authorNm: String?) async throws {
        guard !apiKey.isEmpty else { throw FeedServiceError.writeUnsupported }
        var req = authorized(baseURL.appending(path: "/v1/reviews/\(reviewId)/comments"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            CommentCreateBody(body: body, authorNm: authorNm)
        )

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // 빈 본문·1000자 초과 등은 서버가 한국어 사유로 400을 준다 — 그대로 보여 준다.
            throw failure(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }
        // 생성된 댓글 본문은 쓰지 않는다. 호출부가 목록을 다시 받아 `total`까지 함께 맞춘다.
    }

    // MARK: - 함께 가볼만한 곳

    private struct RelatedPlaceDTO: Decodable {
        struct Access: Decodable {
            let wheelchair: Bool?
            let visual: Bool?
            let hearing: Bool?
            let infant: Bool?
            var elderly: Bool? = nil   // 2026-08-24 추가
        }

        let contentId: String
        let title: String
        /// 서버가 "경북 경주시" 형태로 축약해 준다
        let region: String?
        let addr1: String?
        let imageURL: String?
        let access: Access?
    }

    func fetchRelatedPlaces(contentId: String, limit: Int) async throws -> [RelatedPlace] {
        let dtos: [RelatedPlaceDTO] = try await getItems("/v1/barrier-free/\(contentId)/related", [
            .init(name: "limit", value: "\(limit)"),
        ])
        return dtos.compactMap { dto in
            let name = dto.title.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            let img = (dto.imageURL ?? "").replacingOccurrences(of: "http://", with: "https://")
            let region = dto.region?.trimmingCharacters(in: .whitespaces) ?? ""
            return RelatedPlace(
                id: dto.contentId,
                name: name,
                // `region`이 비어 있는 예외 응답에서만 주소로 축약을 대신한다
                region: region.isEmpty ? Self.shortRegion(dto.addr1) : Self.normalizedRegion(region),
                imageURL: URL(string: img),
                features: Self.features(dto.access)
            )
        }
    }

    /// 서버 `region`은 대체로 "강원 강릉시"처럼 축약돼 오지만 통합 시도명은 그대로 온다
    /// ("전남광주통합특별시 장흥군" — 시안 카드 폭에서 두 줄로 넘친다).
    /// 앞 토큰이 축약 대상일 때만 앱의 규칙으로 바꾸고 나머지 토큰("경북 경주시 인왕동"의 동 이름)은 보존한다.
    static func normalizedRegion(_ region: String) -> String {
        let parts = region.split(separator: " ").map(String.init)
        guard let province = parts.first,
              let short = shortRegion(region).split(separator: " ").first.map(String.init),
              short != province
        else { return region }
        return ([short] + parts.dropFirst()).joined(separator: " ")
    }

    /// 유형별 boolean → 뱃지 유형. 순서는 `fetchPlaceDetail`의 속성 그룹 순서와 맞춘다.
    private static func features(_ access: RelatedPlaceDTO.Access?) -> [AccessibilityFeature] {
        guard let access else { return [] }
        var result: [AccessibilityFeature] = []
        if access.wheelchair == true { result.append(.wheelchairAccessible) }
        if access.visual == true { result.append(.visuallyImpairedFriendly) }
        if access.hearing == true { result.append(.hearingFriendly) }
        if access.infant == true { result.append(.childFriendly) }
        if access.elderly == true { result.append(.elderlyFriendly) }
        return result
    }

    // MARK: - 가공 규칙 (scripts/compose-home-feed.mjs 와 동일)

    /// 접근성 원문 정리: HTML(`<br>` 등) 정리 → 첫 줄만, "_…편의시설" 꼬리표 제거, 공백 정리, 40자 컷.
    static func cleanNote(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        // 원문에 `<br/>` 같은 HTML이 섞여 있다 — 줄바꿈으로 바꿔 첫 문장만 남긴다.
        var t = htmlToPlainText(text).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
        t = t.replacingOccurrences(of: "_[^_]*편의시설\\s*$", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if t.count > 40 { t = String(t.prefix(39)) + "…" }
        return t.isEmpty ? nil : t
    }

    /// 관광공사 원문에 섞인 HTML을 평문으로: `<br>` 계열은 줄바꿈, 나머지 태그는 제거, 주요 엔티티 복원.
    static func htmlToPlainText(_ text: String) -> String {
        var t = text.replacingOccurrences(
            of: "<\\s*br\\s*/?\\s*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        // 실제 HTML 태그(문자로 시작)만 제거 — "폭 < 90 > 안전" 같은 부등호 텍스트는 보존
        t = t.replacingOccurrences(of: "</?[a-zA-Z][^>]*>", with: "", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
                        "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (key, value) in entities {
            t = t.replacingOccurrences(of: key, with: value)
        }
        return t
    }

    /// 카드에 그릴 뱃지와 한 줄 설명.
    ///
    /// **고른 무장애 요소가 있으면 그 축을 먼저 본다.** 시각 지원을 고른 사람에게 "휠체어 대여
    /// 가능"을 보여 주면, 목록은 시각 기준으로 걸러 놓고 카드는 다른 이야기를 하는 셈이다 —
    /// 무엇을 보고 고른 목록인지 알 수 없게 된다(2026-08-23 지적).
    ///
    /// 고른 축에 쓸 문구가 없으면 기존 우선순위로 떨어진다:
    /// 휠체어 > (숙소)무장애 객실 > 평탄 동선(접근로/엘리베이터/화장실) > 객실.
    /// 고령자 친화는 대응 속성이 서버에 없어(`serverAccessGroup` 참고) 여기서도 건너뛴다.
    private static func pickFeature(
        _ dto: BarrierFreeDTO, _ category: PlaceCategory,
        preferring features: [AccessibilityFeature] = []
    ) -> (feature: AccessibilityFeature, note: String)? {
        for feature in features {
            if let picked = note(for: feature, dto) { return (feature, picked) }
        }
        return defaultFeature(dto, category)
    }

    /// 고른 축의 속성 중 **먼저 쓸 만한 것**을 한 줄로. 순서는 카드에서 읽었을 때 쓸모 있는 순이다.
    ///
    /// 각 속성에 사람이 읽을 이름을 함께 둔다 — 원문이 "대여가능"이나 "Y" 처럼 주어 없이
    /// 오는 경우가 많아, 그것만 보여 주면 무엇에 대한 말인지 알 수 없다.
    private static func note(for feature: AccessibilityFeature, _ dto: BarrierFreeDTO) -> String? {
        // (원문, 이름, 이름을 앞에 붙일지). 마지막 값이 false 인 것은 "기타" 칸이다 —
        //  거기에는 이미 완성된 문장이 들어와("시각경보기 있음") 이름을 붙이면 오히려 읽기 나쁘다.
        let candidates: [(String?, String, Bool)]
        switch feature {
        case .wheelchairAccessible, .flatPath, .barrierFreeRoom:
            candidates = [(dto.wheelchair, "휠체어", true), (dto.route, "접근로", true),
                          (dto.elevator, "엘리베이터", true), (dto.restroom, "장애인 화장실", true),
                          (dto.room, "장애인 객실", true)]
        case .visuallyImpairedFriendly:
            candidates = [(dto.audioguide, "음성 안내", true), (dto.braileblock, "점자블록", true),
                          (dto.guidehuman, "안내 요원", true), (dto.brailepromotion, "점자 안내판", true),
                          (dto.bigprint, "큰 활자 안내물", true), (dto.guidesystem, "유도·안내 설비", true),
                          (dto.blindhandicapetc, "시각 편의", false)]
        case .hearingFriendly:
            candidates = [(dto.signguide, "수어 안내", true), (dto.videoguide, "자막 영상 안내", true),
                          (dto.hearingroom, "청각장애인 객실", true),
                          (dto.hearinghandicapetc, "청각 편의", false)]
        case .childFriendly:
            candidates = [(dto.stroller, "유모차", true), (dto.lactationroom, "수유실", true),
                          (dto.babysparechair, "아기 의자", true),
                          (dto.infantsfamilyetc, "영유아 편의", false)]
        case .elderlyFriendly:
            // 서버는 boolean 으로만 판정을 주므로(휠체어 대여·이동보조·승강기·주차 중 하나),
            //  판정 근거가 되는 속성의 원문을 문구로 쓴다. 하나도 없으면 축을 켤 수 없다.
            candidates = [(dto.elevator, "승강기", true), (dto.parking, "주차", true)]
        }
        return candidates.lazy.compactMap { describe($0.0, label: $0.1, prefixes: $0.2) }.first
    }

    /// 원문 한 칸을 카드 한 줄로.
    ///
    /// 세 가지 모양이 섞여 온다:
    /// - 서술("자막 비디오 가이드 있음") → 그대로. 주어가 빠졌으면(`"대여가능"`) 이름을 붙인다.
    /// - 플래그 `Y`(예: `hearingroom` 은 Y/N 만 들어 있다) → `"청각장애인 객실 있음"` 으로 만든다.
    /// - 플래그 `N` → ⚠️ **없다는 뜻이라 건너뛴다.** 서버는 값이 채워졌는지(`is not null`)만 보고
    ///   세므로, 여기서 거르지 않으면 "없음"을 장점처럼 카드에 띄우게 된다.
    private static func describe(_ raw: String?, label: String, prefixes: Bool = true) -> String? {
        guard let text = cleanNote(raw) else { return nil }
        let compact = text.replacingOccurrences(of: " ", with: "")
        switch compact.uppercased() {
        case "N", "NO", "없음", "불가", "불가능": return nil
        case "Y", "YES", "있음", "가능", "O": return "\(label) 있음"
        default: break
        }
        // 이미 그 이름이 들어 있으면 그대로 둔다("유모차 대여 가능함").
        guard prefixes, !compact.contains(label.replacingOccurrences(of: " ", with: "")) else { return text }
        // 주어가 빠진 값이 흔하다("대여가능(무료)", "위치 : 관리사무소 옆") — 무엇에 대한
        //  말인지 앞에 붙여야 카드 한 줄만 읽고도 뜻이 통한다.
        return "\(label) \(text)"
    }

    /// 고른 축이 없거나 그 축에 쓸 값이 없을 때. 뱃지 우선순위는 예전과 같다.
    private static func defaultFeature(
        _ dto: BarrierFreeDTO, _ category: PlaceCategory
    ) -> (feature: AccessibilityFeature, note: String)? {
        if let note = describe(dto.wheelchair, label: "휠체어") {
            return (.wheelchairAccessible, note)
        }
        if category == .stay, let note = describe(dto.room, label: "장애인 객실") {
            return (.barrierFreeRoom, note)
        }
        if let note = describe(dto.route, label: "접근로") { return (.flatPath, note) }
        if let note = describe(dto.elevator, label: "엘리베이터") { return (.flatPath, note) }
        if let note = describe(dto.restroom, label: "장애인 화장실") { return (.flatPath, note) }
        if let note = describe(dto.room, label: "장애인 객실") { return (.barrierFreeRoom, note) }
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

/// multipart 본문 조립용. 경계선·헤더는 ASCII라 UTF-8 인코딩이 실패할 수 없다.
private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
