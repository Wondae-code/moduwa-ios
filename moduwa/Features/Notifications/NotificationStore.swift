import Foundation
import Observation

/// 앱 알림 항목 — 알림 API 도입 전까지 mock 전용
struct AppNotification: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let body: String
    let receivedAt: Date
    var isRead: Bool = false
}

/// 알림 상태 저장소 — 홈 헤더 벨 뱃지와 알림 화면이 공유한다.
/// 서버 알림이 생기면 이 스토어의 데이터 소스만 교체하면 된다.
@MainActor
@Observable
final class NotificationStore {
    private(set) var items: [AppNotification] = []

    /// 안 읽은 알림 존재 여부 — 홈 헤더 벨의 도트 표시 기준
    var hasUnread: Bool { items.contains { !$0.isRead } }

    /// 알림 화면 진입 시 호출 — 모두 읽음 처리해 뱃지를 끈다
    func markAllRead() {
        items = items.map { var n = $0; n.isRead = true; return n }
    }

    #if DEBUG
    private static let mockSamples: [(String, String)] = [
        ("새로운 무장애 코스", "휠체어로 이동하기 좋은 경주 코스가 추가됐어요"),
        ("리뷰 알림", "내가 저장한 불국사에 새 리뷰가 달렸어요"),
        ("일정 리마인드", "내일 예정된 여행 일정을 확인해보세요"),
    ]

    /// 디버그 전용 — mock 알림 추가
    func addMockNotification() {
        let sample = Self.mockSamples[items.count % Self.mockSamples.count]
        items.insert(AppNotification(title: sample.0, body: sample.1, receivedAt: .now), at: 0)
    }

    /// 디버그 전용 — 전체 비우기 (빈 상태 확인용)
    func removeAll() {
        items.removeAll()
    }
    #endif
}
