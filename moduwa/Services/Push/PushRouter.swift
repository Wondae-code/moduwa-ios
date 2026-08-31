import OSLog
import SwiftUI

/// 알림을 눌렀을 때 갈 곳을 담아 두는 우편함(초대 링크의 `InviteCoordinator` 와 같은 구조).
///
/// 알림은 앱이 아직 화면을 그리기도 전에 도착할 수 있고(종료 상태에서 눌러 실행), 갈 곳은
/// 탭 안쪽이다. `AppDelegate` 가 여기에 담고 `RootView` 가 탭을 옮기며, 실제로 미는 일은
/// 목적지를 아는 탭(홈·플랜)이 한다.
///
/// `@MainActor` 를 붙이지 않는다 — `EnvironmentValues` 기본값이 액터 바깥에서 만들어지기
/// 때문이다(`InviteCoordinator` 와 같은 판단).
@Observable
final class PushRouter {
    static let shared = PushRouter()

    /// 열어야 할 게시글(좋아요·댓글 알림). 홈 탭이 받아 상세로 민다.
    var pendingPostID: String?
    /// 열어야 할 플랜(합류 알림). 플랜 탭이 받아 상세로 민다.
    var pendingPlanID: UUID?

    /// APNs 페이로드에서 갈 곳을 읽는다.
    ///
    /// 서버는 `data` 를 `aps` 와 **같은 층**에 펼쳐 보낸다(`{ aps, type, postId }`) — 그래서
    /// `userInfo` 의 최상위에서 바로 읽는다. 값은 전부 문자열이다(`postId: "12"`).
    ///
    /// 모르는 `type` 은 조용히 무시한다 — 서버가 알림을 늘렸을 때 구 버전 앱이 엉뚱한 화면을
    /// 열지 않는 편이 낫다(알림 자체는 이미 보였다).
    func route(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else {
            PushRegistrar.log.error("알림에 type 이 없다: \(userInfo.keys.map(String.init(describing:)), privacy: .public)")
            return
        }
        PushRegistrar.log.notice("알림 탭: \(type, privacy: .public)")
        switch type {
        case "post_like", "post_comment":
            guard let postID = userInfo["postId"] as? String, !postID.isEmpty else { return }
            pendingPostID = postID
        case "plan_member_joined":
            guard let raw = userInfo["planId"] as? String, let planID = UUID(uuidString: raw) else { return }
            pendingPlanID = planID
        default:
            break
        }
    }
}

extension EnvironmentValues {
    @Entry var pushRouter = PushRouter.shared
}
