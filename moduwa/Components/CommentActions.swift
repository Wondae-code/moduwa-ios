import SwiftUI

/// 댓글 한 줄에 붙는 동작 — **내 것이면 수정·삭제, 남의 것이면 신고**.
///
/// 자기 글에 신고를 두지 않는 이유: 서버가 자기 것 신고를 무시하므로(204) 보이는데 아무 일도
/// 없는 버튼이 된다.
struct CommentMenuItems: View {
    let isMine: Bool
    let edit: () -> Void
    let delete: () -> Void
    /// 남의 댓글을 신고한다. nil 이면 신고를 두지 않는다(번들·목 데이터).
    var report: (() -> Void)? = nil
    /// 남의 댓글 작성자를 차단한다. 작성자 식별자(`authorUUID`)가 없으면 nil 이다 —
    /// 닉네임으로는 차단할 수 없다(동명이인).
    var block: (() -> Void)? = nil

    /// 띄울 것이 하나라도 있는지. 없으면 호출부가 `⋯` 자체를 두지 않는다.
    var hasAny: Bool { isMine || report != nil || block != nil }

    var body: some View {
        if isMine {
            Button("수정", systemImage: "pencil", action: edit)
            Button("삭제", systemImage: "trash", role: .destructive, action: delete)
        } else {
            if let report { Button("신고", systemImage: "flag", action: report) }
            // 신고는 운영자에게 알리는 것이고, 차단은 **내 화면에서 안 보이게** 하는 것이다.
            //  둘은 다른 일이라 함께 둔다(심사 1.2 도 둘 다 요구한다).
            if let block { Button("차단", systemImage: "hand.raised", action: block) }
        }
    }
}

/// 댓글 줄 오른쪽의 `⋯`.
///
/// **처음에는 길게 누르기만 두었다가 버튼을 추가했다**(사용자 지시). 길게 누르기는 보이지 않는
/// 동작이라, 남의 댓글을 신고하려는 사람이 그런 동작이 있다는 것을 알 방법이 없었다.
/// 길게 누르기도 그대로 둔다(`CommentActions`) — 이미 아는 사람의 손을 막을 이유가 없다.
struct CommentMenuButton: View {
    let items: CommentMenuItems

    var body: some View {
        if items.hasAny {
            Menu {
                items
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.iconGray)
                    // 14pt 글리프는 44pt 터치 영역에 못 미친다 — 영역만 넓힌다.
                    .frame(width: 32, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(items.isMine ? "이 댓글 관리" : "이 댓글 신고")
        }
    }
}

/// 같은 동작을 **길게 누르기와 스크린리더**로도 닿게 한다.
///
/// ⚠️ 댓글 줄은 한 단위로 읽히도록 `accessibilityElement(children:)` 로 묶여 있어서, 줄 안의
/// `⋯` 버튼이 VoiceOver 에 **개별 요소로 노출되지 않는다.** 그래서 동작을 줄 자체에 실어 둔다 —
/// 이것을 빼면 스크린리더 사용자에게는 수정·삭제·신고가 없는 기능이 된다.
struct CommentActions: ViewModifier {
    let items: CommentMenuItems

    func body(content: Content) -> some View {
        if items.hasAny {
            content
                .contextMenu { items }
                .accessibilityActions {
                    if items.isMine {
                        Button("수정", action: items.edit)
                        Button("삭제", action: items.delete)
                    } else {
                        if let report = items.report { Button("신고", action: report) }
                        if let block = items.block { Button("차단", action: block) }
                    }
                }
        } else {
            content
        }
    }
}
