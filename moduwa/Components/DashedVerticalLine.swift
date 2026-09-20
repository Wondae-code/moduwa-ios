import SwiftUI

/// 번호 뱃지들을 세로로 잇는 점선(시안 Line 3).
///
/// **두 화면이 같은 선을 쓴다** — 플랜 상세(`PlanDetailView.dayTimeline`)와 일정 편집
/// (`PlanEditView`). 편집에서 순서를 바꾸다 보면 상세와 같은 그림이어야 "같은 일정"으로
/// 읽히는데, 편집에만 선이 없어 두 화면이 달라 보였다(2026-09-20 피드백).
///
/// 모양은 한 곳에서만 정한다 — 굵기 1, `dash: [3, 3]`, 색 `cardStroke`.
/// 한쪽만 고치면 두 화면이 또 갈라진다.
struct DashedVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

extension DashedVerticalLine {
    /// 뱃지 중심에 맞춰 깔아 두는 표준 모양. `leadingInset` 은 **뱃지 중심까지의 거리**다
    /// (상세는 뱃지 23 → 11.5, 편집은 행 들여쓰기 36 + 뱃지 24의 절반 12 → 48).
    @ViewBuilder
    static func track(leadingInset: CGFloat) -> some View {
        DashedVerticalLine()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(Color.cardStroke)
            .frame(width: 1)
            .padding(.leading, leadingInset)
    }
}
