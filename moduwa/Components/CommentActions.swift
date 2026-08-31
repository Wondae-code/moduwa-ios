import SwiftUI

/// 내 댓글에 붙는 수정·삭제 동작. 게시글 댓글과 후기 댓글이 **같은 문법**을 쓰게 한 벌만 둔다.
///
/// **길게 누르기(컨텍스트 메뉴)로 두는 이유**: 댓글은 이름·시간·본문뿐인 짧은 항목이라, 줄마다
/// `⋯` 버튼을 두면 버튼이 본문보다 눈에 띄고 남의 댓글에는 띄울 것이 없어 자리만 빈다.
///
/// ⚠️ 길게 누르기는 **보이지 않는 동작**이다. 그래서 스크린리더에는 별도 동작으로 함께 싣는다
/// (`accessibilityAction`) — 그러지 않으면 VoiceOver 사용자에게는 이 기능이 아예 없는 것이 된다.
///
/// **내 댓글과 남의 댓글에 서로 다른 메뉴가 붙는다**: 내 것은 수정·삭제, 남의 것은 신고.
/// 자기 글에 신고를 두지 않는 이유는 서버가 자기 것 신고를 무시하기 때문이고(204), 보이는데
/// 아무 일도 없는 버튼을 두지 않으려는 것이다.
struct CommentActions: ViewModifier {
    let isMine: Bool
    let edit: () -> Void
    let delete: () -> Void
    /// 남의 댓글을 신고한다. nil 이면 신고 자체를 두지 않는다(번들·목 데이터).
    var report: (() -> Void)? = nil

    func body(content: Content) -> some View {
        if isMine {
            content
                .contextMenu {
                    Button("수정", systemImage: "pencil", action: edit)
                    Button("삭제", systemImage: "trash", role: .destructive, action: delete)
                }
                .accessibilityAction(named: "수정", edit)
                .accessibilityAction(named: "삭제", delete)
        } else if let report {
            content
                .contextMenu {
                    Button("신고", systemImage: "flag", action: report)
                }
                .accessibilityAction(named: "신고", report)
        } else {
            content
        }
    }
}
