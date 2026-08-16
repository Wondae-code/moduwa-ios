import SwiftUI

/// 일정에 무언가를 담을 때 "어느 날에" 를 고르는 목록. 메모 추가와 장소 추가가 함께 쓴다.
///
/// **접지 않고 늘 펼쳐 둔다**(2026-08-16 사용자 지시). 접고 펴는 UI 를 다 거쳐 온 자리다:
///  - 칩(`PlanCreateChip`)은 한 달짜리 여행에서 알약이 30개가 되어 아래 내용을 화면 밖으로 민다.
///  - 시스템 `Menu` 는 컨텍스트 메뉴 프레젠테이션이 라벨을 통째로 스냅숏 떠서 확대·부양시키고
///    뒤를 흐린다 — 화면 폭을 다 쓰는 줄에 붙으면 목록 하나 여는 동작치고 과하다.
///  - 직접 그린 펼침도 결국 "여는 동작" 이 남는다. 펼쳐 두면 그 동작 자체가 없다.
///
/// 대신 자리를 차지하므로 `visibleRowCount` 로 높이를 묶고 그 안에서 스크롤시킨다.
struct PlanDaySelectList: View {
    /// 고를 수 있는 날들. 호출부가 `Plan.dayCandidates()` 로 만들어 넘긴다 —
    /// 서버에 이미 있는 날과 아직 없는 날이 섞여 있고, 여기서는 구분하지 않는다.
    let days: [PlanDay]
    @Binding var selection: PlanDay.ID?
    /// 접지 않고 보여 줄 줄 수. 이보다 길면(한 달짜리 여행 등) 목록 안에서 스크롤된다.
    ///
    /// 화면마다 다르다 — 메모 작성은 이 목록 말고 입력란만 있어 넉넉히 두지만,
    /// 장소 담기는 검색 결과가 세로를 다투므로 더 줄인다.
    var visibleRowCount = 5

    private static let rowHeight: CGFloat = 44

    var body: some View {
        Group {
            if days.count > visibleRowCount {
                ScrollView { rows }
                    .frame(height: CGFloat(visibleRowCount) * Self.rowHeight)
            } else {
                rows
            }
        }
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                row(index: index, day: day)
            }
        }
    }

    private func row(index: Int, day: PlanDay) -> some View {
        let isSelected = selection == day.id
        return Button {
            // 고른 값을 물려받은 트랜잭션 안에서 쓰면 글자 굵기와 화면 다른 곳의 파생 문구가
            // 함께 스르륵 바뀌어 읽힌다(`withoutAnimation` 주석 참고). 즉시 반영한다.
            withoutAnimation { selection = day.id }
        } label: {
            HStack(spacing: 8) {
                Text(Self.label(index: index, day: day))
                    .font(.notoSans(15, isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 선택을 색·굵기만으로 전달하지 않는다 — 글리프가 형태로 함께 알린다.
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.deepGreen)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: Self.rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// "DAY 1 · 7/26 목". 목록 밖(고른 값을 되짚는 문구 등)에서도 같은 표기를 쓰도록 열어 둔다.
    static func label(index: Int, day: PlanDay) -> String {
        "DAY \(index + 1) · \(PlanDateText.shortWithWeekday(day.date))"
    }
}

#Preview("여러 날") {
    @Previewable @State var selection: PlanDay.ID?
    return PlanDaySelectList(days: MockData.upcomingGyeongju.days, selection: $selection)
        .padding(24)
}
