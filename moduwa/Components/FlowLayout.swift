import SwiftUI

/// 폭이 차면 다음 줄로 넘기는 배치 (검색 인기 키워드, 후기 태그 칩 2~3줄, 후기 뱃지 줄).
///
/// `SearchView`에 있던 파일 전용 구현을 여기로 올렸다 — 태그 칩이 같은 배치를 필요로 하고,
/// 같은 이름의 top-level 타입은 `private`이어도 모듈 안에서 충돌한다.
///
/// `HStack`으로는 칩이 잘리고, `LazyVGrid`는 칩마다 폭이 달라 열 규격을 정할 수 없다.
/// Dynamic Type 최대 크기에서 칩 하나가 한 줄을 다 쓰는 경우까지 그대로 흘려야 하므로
/// 줄바꿈을 직접 계산한다.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        // proposal.width가 nil(고유 크기 질의)일 때 .infinity를 그대로 돌려주면 레이아웃이 깨진다
        return CGSize(width: maxWidth.isFinite ? maxWidth : width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .init(width: size.width, height: size.height)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            // 칩 하나가 폭보다 넓으면 그 줄을 혼자 쓰게 둔다 (제안 폭을 넘기지 않게 폭을 제한해 질의)
            let size = subviews[index].sizeThatFits(.init(width: maxWidth, height: nil))
            let needed = current.indices.isEmpty ? size.width : current.width + horizontalSpacing + size.width
            if !current.indices.isEmpty, needed > maxWidth {
                rows.append(current)
                current = Row()
            }
            if current.indices.isEmpty {
                current.width = size.width
            } else {
                current.width += horizontalSpacing + size.width
            }
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
