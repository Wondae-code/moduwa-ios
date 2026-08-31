import SwiftUI

/// 내 댓글에 붙는 수정·삭제 동작. 게시글 댓글과 후기 댓글이 **같은 문법**을 쓰게 한 벌만 둔다.
///
/// **길게 누르기(컨텍스트 메뉴)로 두는 이유**: 댓글은 이름·시간·본문뿐인 짧은 항목이라, 줄마다
/// `⋯` 버튼을 두면 버튼이 본문보다 눈에 띄고 남의 댓글에는 띄울 것이 없어 자리만 빈다.
///
/// ⚠️ 길게 누르기는 **보이지 않는 동작**이다. 그래서 스크린리더에는 별도 동작으로 함께 싣는다
/// (`accessibilityAction`) — 그러지 않으면 VoiceOver 사용자에게는 수정·삭제가 아예 없는 기능이 된다.
struct CommentActions: ViewModifier {
    let isMine: Bool
    let edit: () -> Void
    let delete: () -> Void

    func body(content: Content) -> some View {
        if isMine {
            content
                .contextMenu {
                    Button("수정", systemImage: "pencil", action: edit)
                    Button("삭제", systemImage: "trash", role: .destructive, action: delete)
                }
                .accessibilityAction(named: "수정", edit)
                .accessibilityAction(named: "삭제", delete)
        } else {
            content
        }
    }
}
