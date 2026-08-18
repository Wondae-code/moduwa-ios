import Foundation
import Observation

/// 장소 검색의 상태와 페이지를 함께 들고 있는 것. 검색 화면(`SearchView`)·플랜 담기
/// (`PlanPlaceAddView`)·게시글 장소 붙이기(`PostPlacePickerView`)가 **같은 것을 쓴다**.
///
/// 세 화면이 각자 `SearchState` enum 과 `loadSearchResults()` 를 똑같이 베껴 갖고 있었고,
/// 그래서 세 곳 모두 `offset: 0` 에 멈춰 첫 20개만 보여 주면서 머리글에는 전체 수를
/// 적고 있었다("검색 결과 137" 아래 20줄, 2026-08-18 확인). 한 곳으로 모아 고친다.
///
/// `@Observable` 클래스인 이유: 더 불러오기는 화면을 다시 그리는 사이에도 이어져야 해서
/// 누적된 목록·오프셋·진행 상태가 뷰 바깥에 남아 있어야 한다.
@MainActor
@Observable
final class PlaceSearchPaginator {
    /// 화면이 보고 그리는 큰 갈래. `results` 는 `places` 를 함께 읽는다.
    enum Phase: Equatable {
        case idle, loading, results, empty, failed
    }

    /// 서버 `paging()` 기본값과 같다.
    static let pageSize = 20

    private(set) var phase: Phase = .idle
    /// 지금까지 받아 쌓은 결과. `loadMore()` 가 뒤에 이어 붙인다.
    private(set) var places: [Place] = []
    /// 서버가 센 전체 일치 수. 머리글의 "검색 결과 N".
    private(set) var total = 0
    private(set) var isLoadingMore = false
    /// 이어 받기만 실패한 상태. 이미 받은 목록은 그대로 두고 버튼 문구만 바꾼다 —
    /// 첫 페이지 실패(`.failed`)처럼 화면을 비우면 보고 있던 결과가 사라진다.
    private(set) var loadMoreFailed = false

    /// 지금 검색어. 이어 받기가 같은 말로 다음 페이지를 물어야 한다.
    private var term = ""
    /// 새 검색이 시작될 때마다 올린다. 늦게 도착한 이어 받기 응답이 **다른 검색어의 목록에
    /// 섞이는 것**을 막는다(`Task.isCancelled` 만으로는 막히지 않는다 — 버튼으로 띄운
    /// 이어 받기 태스크는 새 검색이 취소해 주지 않는다).
    private var generation = 0

    var hasMore: Bool { !places.isEmpty && places.count < total }

    /// 입력을 지웠을 때 처음 상태로.
    func reset() {
        generation += 1
        phase = .idle
        places = []
        total = 0
        isLoadingMore = false
        loadMoreFailed = false
        term = ""
    }

    /// 첫 페이지. `.task(id:)` 안에서 부르면 새 검색어가 들어올 때 자동으로 취소된다.
    func search(_ query: String, using service: any PlaceSearchService) async {
        generation += 1
        let mine = generation
        term = query
        places = []
        total = 0
        loadMoreFailed = false
        phase = .loading

        do {
            let page = try await service.searchPlaces(
                query: query, limit: Self.pageSize, offset: 0)
            guard !Task.isCancelled, mine == generation else { return }
            places = page.items
            total = page.total
            phase = page.items.isEmpty ? .empty : .results
        } catch is CancellationError {
            // 새 검색어가 들어오면 이전 요청은 자동으로 취소된다.
        } catch {
            guard !Task.isCancelled, mine == generation else { return }
            phase = .failed
        }
    }

    /// 다음 페이지를 뒤에 이어 붙인다.
    func loadMore(using service: any PlaceSearchService) async {
        guard phase == .results, hasMore, !isLoadingMore else { return }
        let mine = generation
        isLoadingMore = true
        loadMoreFailed = false
        defer { if mine == generation { isLoadingMore = false } }

        do {
            let page = try await service.searchPlaces(
                query: term, limit: Self.pageSize, offset: places.count)
            guard mine == generation else { return }
            // 이미 가진 것은 걸러 낸다. 서버 정렬은 `contentid` 로 끝나 결정적이지만,
            // push-data.sh 가 `barrier_free` 를 통째로 갈아치우는 동안 페이지를 넘기면
            // 행이 밀려 같은 장소가 두 번 올 수 있다 — `ForEach` 의 id 가 겹치면 터진다.
            let known = Set(places.map(\.id))
            places += page.items.filter { !known.contains($0.id) }
            // 전체 수도 갱신한다 — 데이터가 갈렸다면 낡은 수를 계속 보여 줄 이유가 없다.
            total = page.total
            // 서버가 더 있다고 세어 놓고 빈 페이지를 주면 버튼이 영원히 남는다.
            if page.items.isEmpty { total = places.count }
        } catch {
            guard mine == generation else { return }
            loadMoreFailed = true
        }
    }
}
