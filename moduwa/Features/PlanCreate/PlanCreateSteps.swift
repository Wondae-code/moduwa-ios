import SwiftUI

// 새 플랜 플로우의 단계별 본문. 상단(진행 바)·하단(완료/건너뛰기)은 `PlanCreateFlowView`가 그린다.
//  1/6·2/6·3/6 은 실제 시안(372:409 · 391:96 · 519:1219 · 519:1343),
//  4/6~6/6 은 손그림 스케치(532:169)를 1~3단계 톤으로 옮긴 것이다.

// MARK: - 1/6 누구와

/// 연령·목적·이동 세 축을 각각 다중 선택한다 (시안 391:96 은 20대+30대가 동시에 켜져 있다).
struct PlanPartyStep: View {
    @Binding var party: TravelParty

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            group("연령", AgeGroup.allCases, selection: $party.ageGroups)
            group("목적", CompanionType.allCases, selection: $party.companions)
            group("이동", MobilityMode.allCases, selection: $party.mobilities)
        }
        .padding(.horizontal, 24)
    }

    /// 시안은 그룹 이름(18 Medium)을 칩 첫 줄 **왼쪽에** 두고 두 번째 줄부터는 같은 자리에서 들여쓴다.
    ///  접근성 글자 크기에서는 이름이 50pt 칸을 넘겨 칩을 밀어내므로 이름을 위로 올린다.
    @ViewBuilder
    private func group<Item: Identifiable & Hashable>(
        _ title: String,
        _ items: [Item],
        selection: Binding<Set<Item>>
    ) -> some View where Item.ID == String {
        let name = Text(title)
            .font(.notoSans(18, .medium, relativeTo: .headline))
            .tracking(-0.4)
            .foregroundStyle(Color.textPrimary)

        let chips = FlowLayout(horizontalSpacing: 6, verticalSpacing: 0) {
            ForEach(items) { item in
                PlanCreateChip(label: label(of: item), isSelected: selection.wrappedValue.contains(item)) {
                    // 글자 굵기가 바뀌며 칩 폭이 달라진다 — 애니메이션되면 줄 전체가 흔들린다
                    withoutAnimation { selection.wrappedValue.toggle(item) }
                }
            }
        }
        // 어느 칩이 켜졌는지는 칩마다 실리지만, 이 축에서 몇 개를 골랐는지는 어디에도 없다
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), 여러 개 선택 가능")
        .accessibilityValue(
            selection.wrappedValue.isEmpty ? "고르지 않음" : "\(selection.wrappedValue.count)개 선택")

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                name
                chips
            }
        } else {
            HStack(alignment: .top, spacing: 6) {
                name
                    .frame(width: 50, alignment: .leading)
                    // 칩이 위아래 5pt 여백을 품고 있어(=탭 영역) 이름이 첫 줄과 어긋난다
                    .padding(.top, 7)
                chips
            }
        }
    }

    /// `AgeGroup`·`CompanionType`·`MobilityMode` 는 프로토콜을 공유하지 않지만
    /// 셋 다 `label`을 갖는다. 표시 문구는 하드코딩하지 않고 그 값을 쓴다.
    private func label<Item>(of item: Item) -> String {
        switch item {
        case let value as AgeGroup: value.label
        case let value as CompanionType: value.label
        case let value as MobilityMode: value.label
        default: ""
        }
    }
}

// MARK: - 2/6 어디로

/// 지역 12개 중 **하나만** 고른다 (시안 519:1219 는 경주 하나만 켜져 있다).
struct PlanRegionStep: View {
    @Binding var region: TravelRegion?

    var body: some View {
        PlanChipGrid(
            items: TravelRegion.allCases.map { ($0.rawValue, $0.label) },
            isSelected: { region?.rawValue == $0 },
            allowsMultiple: false,
            groupLabel: "여행 지역, 하나만 선택",
            groupValue: region?.label ?? "고르지 않음"
        ) { code in
            // 같은 칩을 다시 누르면 선택이 풀린다 — 단일 선택에서 되돌릴 방법이 이것뿐이다.
            withoutAnimation { region = region?.rawValue == code ? nil : TravelRegion(rawValue: code) }
        }
    }
}

// MARK: - 4/6 테마

/// 테마 12개 다중 선택.
/// 칩 문구는 서버(`GET /v1/plan-options`)가 준 `label`이다 — 앱에 목록이 없다.
struct PlanThemeStep: View {
    let themes: [PlanOption]
    @Binding var selected: [String]
    /// "덜 붐볐으면 좋겠어요" — 테마와 같은 화면에 있다(시안 958:633, 선택 상태 958:281).
    @Binding var avoidsCrowds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            PlanChipGrid(
                items: themes.map { ($0.code, $0.label) },
                isSelected: { selected.contains($0) },
                allowsMultiple: true,
                groupLabel: "선호 테마, 여러 개 선택 가능",
                groupValue: selected.isEmpty ? "고르지 않음" : "\(selected.count)개 선택"
            ) { code in
                withoutAnimation {
                    // 서버가 준 순서를 유지한다 — 고른 차례대로 쌓으면 같은 선택이 매번 다른 배열이 된다.
                    if selected.contains(code) {
                        selected.removeAll { $0 == code }
                    } else {
                        selected = themes.map(\.code).filter { selected.contains($0) || $0 == code }
                    }
                }
            }

            // 시안은 이 체크박스를 칩 격자 아래 가운데에 둔다. 로그인 화면의 "로그인 상태 유지"와
            //  **같은 컴포넌트**다(시안도 그 프레임을 복제해 썼다 — 이름이 "login remain") —
            //  선택을 색만으로 전하지 않고 체크 글리프가 함께 들어온다.
            AuthCheckbox(title: "덜 붐볐으면 좋겠어요", isOn: $avoidsCrowds)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 5/6 예산

/// 3택 단일 선택. 문구·부연 모두 서버가 준다 (`label` + `hint`).
struct PlanBudgetStep: View {
    let budgets: [PlanOption]
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(budgets) { option in
                row(option)
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("예산, 하나만 선택")
    }

    /// 접근성 판단 — 선택을 색만으로 전달하지 않는다:
    /// 라디오 글리프(빈 원 ↔ 채운 원)가 형태로, 글자 굵기와 테두리 두께가 무게로,
    /// `.isSelected`가 스크린리더로 전달한다.
    private func row(_ option: PlanOption) -> some View {
        let isOn = selected == option.code
        return Button {
            // 다시 누르면 선택이 풀린다 — 예산 nil은 "고르지 않음"이라는 유효한 값이다.
            withoutAnimation { selected = isOn ? nil : option.code }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? .deepGreen : .iconGray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.notoSans(16, isOn ? .bold : .medium, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(isOn ? .textPrimary : .textSecondary)

                    if let hint = option.hint, !hint.isEmpty {
                        Text(hint)
                            .font(.notoSans(13, .regular, relativeTo: .footnote))
                            .tracking(-0.4)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(
                isOn ? Color.moduwaGreen.opacity(0.18) : Color.photoPlaceholder))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(
                isOn ? Color.deepGreen : Color.clear, lineWidth: isOn ? 2 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.hint.map { "\(option.label), \($0)" } ?? option.label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isOn ? "두 번 탭하면 선택을 해제합니다" : "두 번 탭하면 이 하나만 선택합니다")
    }
}

// MARK: - 공통 칩 격자 (2/6 · 4/6)

/// 시안 519:1219 의 3열 격자 — 칸 폭 108, 가로 간격 10, 세로 피치 58.
///
/// 접근성 글자 크기에서는 108pt 칸에 문구가 들어가지 않아 **한 열로 편다**.
/// (`FlowLayout`으로 흘리면 칩 폭이 제각각이라 시안의 반듯한 격자가 무너진다 — 두 배치를 나눈 이유다)
private struct PlanChipGrid: View {
    /// (저장에 쓰는 코드, 화면에 쓰는 문구)
    let items: [(code: String, label: String)]
    let isSelected: (String) -> Bool
    let allowsMultiple: Bool
    let groupLabel: String
    let groupValue: String
    let onTap: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        // 칩이 위아래 3pt 여백을 품어 44pt 탭 영역을 만든다 — 그만큼 행 간격에서 뺀다(58 피치 유지)
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items, id: \.code) { item in
                PlanCreateChip(
                    label: item.label,
                    isSelected: isSelected(item.code),
                    allowsMultiple: allowsMultiple,
                    fillsWidth: true
                ) {
                    onTap(item.code)
                }
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(groupLabel)
        .accessibilityValue(groupValue)
    }
}
