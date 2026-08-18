import SwiftUI

/// 저장한 장소를 앱 전체가 함께 보는 곳.
///
/// 서비스만으로는 부족하다 — **저장 버튼(장소 상세)과 저장 탭이 서로 다른 화면**인데 한쪽에서
/// 누른 결과가 다른 쪽에 곧바로 보여야 한다. 화면마다 목록을 따로 받으면 탭을 옮길 때마다
/// 왕복이 생기고, 그 사이 두 화면이 서로 다른 사실을 보여 준다.
///
/// 서버에 "이 장소를 저장했나"를 묻는 길이 따로 없는 것도 이유다. 목록을 한 번 받아 두면
/// 상세 화면은 그 집합만 확인하면 된다(저장 목록은 개인이 고른 것이라 크지 않다).
@Observable
final class SavedPlacesStore {
    /// 최근 저장한 순. 저장 탭이 이 순서를 그대로 쓴다.
    private(set) var places: [Place] = []
    /// 목록을 한 번이라도 받아 왔는지. 못 받은 상태와 "저장한 것이 없다"를 구분한다.
    private(set) var didLoad = false
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// 저장/해제 요청이 날아가는 중인 장소. 버튼이 그동안 눌리지 않게 한다.
    private(set) var pendingIDs: Set<String> = []

    private let service: any FeedService

    init(service: any FeedService) {
        self.service = service
    }

    func isSaved(_ contentId: String) -> Bool {
        places.contains { $0.id == contentId }
    }

    func isPending(_ contentId: String) -> Bool {
        pendingIDs.contains(contentId)
    }

    /// 목록을 받아 온다. 이미 받아 둔 뒤라도 다시 부르면 갱신한다(당겨서 새로고침 등).
    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false
        do {
            places = try await service.fetchSavedPlaces()
            didLoad = true
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    /// 저장/해제를 뒤집는다.
    ///
    /// **화면을 먼저 바꾸고 서버에 보낸다**(낙관적 갱신) — 북마크는 누른 즉시 반응해야 하는
    /// 동작이라 왕복을 기다리면 버튼이 멎은 것처럼 느껴진다. 실패하면 되돌린다.
    ///
    /// 되돌릴 때 **원래 자리로 넣지 않는다** — 목록 순서는 서버의 저장 시각이 정하므로 앱이
    /// 지어내면 다음 새로고침에서 자리가 바뀐다. 해제를 되돌리는 경우만 맨 앞에 다시 놓는다.
    @MainActor
    @discardableResult
    func toggle(_ place: Place) async -> Bool {
        let contentId = place.id
        guard !pendingIDs.contains(contentId) else { return isSaved(contentId) }

        let wasSaved = isSaved(contentId)
        let removed = places.first { $0.id == contentId }
        pendingIDs.insert(contentId)

        if wasSaved {
            places.removeAll { $0.id == contentId }
        } else {
            places.insert(place, at: 0)
        }

        do {
            try await service.setPlaceSaved(contentId: contentId, !wasSaved)
        } catch {
            // 되돌린다. 저장을 되돌리는 것은 그냥 빼면 되고, 해제를 되돌리는 것은 다시 넣는다.
            if wasSaved {
                places.insert(removed ?? place, at: 0)
            } else {
                places.removeAll { $0.id == contentId }
            }
            pendingIDs.remove(contentId)
            return wasSaved
        }

        pendingIDs.remove(contentId)
        return !wasSaved
    }
}
