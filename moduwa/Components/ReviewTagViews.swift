import SwiftUI

/// 태그 아이콘. **`icon`이 nil인 태그가 있다**(반려동물·가성비·친절·주차) —
/// 브랜드 에셋이 없다는 뜻이므로 임의의 SF Symbol로 메우지 않고 아무것도 그리지 않는다.
/// (기존 무장애 뱃지 아이콘과 결이 다른 글리프가 섞이면 태그 줄이 통일감을 잃는다)
struct ReviewTagIcon: View {
    let icon: String?
    var size: CGFloat = 14

    var body: some View {
        if let icon {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // 아이콘은 옆 텍스트와 같은 뜻이라 따로 읽히면 중복이다
                .accessibilityHidden(true)
        }
    }
}

/// 후기 작성 화면의 다중 선택 칩.
///
/// 접근성 판단 — 선택 상태를 색만으로 전달하지 않는다:
/// 라임 배경(색) 외에 ① 테두리가 1pt 회색 → 2pt 딥그린으로 굵어지고 ② 글자가 medium → bold 로 바뀌며
/// ③ `accessibilityAddTraits(.isSelected)`로 스크린리더에 "선택됨"이 실린다.
/// 셋 중 하나만 남아도 무엇이 골라졌는지 알 수 있어야 한다.
/// (체크 글리프도 신호였지만 칩 폭을 바꿔 줄 전체를 밀어내서 뺐다 — 남은 두 신호로 형태 구분은 유지된다)
struct ReviewTagSelectChip: View {
    let tag: ReviewTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ReviewTagIcon(icon: tag.icon, size: 15)
                Text(tag.label)
                    .font(.notoSans(14, isSelected ? .bold : .medium))
                    // 접근성 글자 크기에서 칩 하나가 한 줄을 다 써도 잘리지 않게
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.moduwaGreen.opacity(0.35) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.deepGreen : Color.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "두 번 탭하면 선택을 해제합니다" : "두 번 탭하면 선택합니다")
    }
}

/// 후기 한 줄에 붙는 태그 뱃지. 여기는 폭이 좁아 `shortLabel`("무장애")을 쓴다.
struct ReviewTagBadge: View {
    let tag: ReviewTag

    var body: some View {
        HStack(spacing: 3) {
            ReviewTagIcon(icon: tag.icon, size: 12)
            Text(tag.shortLabel)
                .font(.notoSans(11, .medium))
        }
        .foregroundStyle(.deepGreen)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.moduwaGreen.opacity(0.25)))
        .overlay(Capsule().stroke(Color.moduwaGreen, lineWidth: 1))
    }
}

/// 장소 후기 화면의 태그 집계 막대 한 칸.
///
/// 접근성 판단 — 막대는 그래픽일 뿐 정보가 아니다:
/// 아이콘·문구·인원수·막대를 하나의 요소로 묶어 "무장애 친화적이에요, 21명"으로 읽힌다.
/// 막대만 남고 수치가 안 읽히면 스크린리더 사용자에게는 아무 정보도 전달되지 않는다.
/// 막대 길이는 1위 태그를 100%로 둔 상대값이라 절대 수치를 대신할 수 없다는 점도 이유다.
struct ReviewTagCountBar: View {
    let item: ReviewTagCount
    /// 이 장소에서 가장 많이 선택된 태그의 인원수 — 막대 길이의 분모
    let maxCount: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var fraction: Double {
        guard maxCount > 0 else { return 0 }
        // 1명인 태그도 막대가 보여야 한다 (0으로 눌리면 "없음"처럼 읽힌다)
        return max(Double(item.count) / Double(maxCount), 0.06)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelRow
            track
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.tag.label), \(item.count)명")
    }

    @ViewBuilder
    private var labelRow: some View {
        let name = HStack(spacing: 6) {
            ReviewTagIcon(icon: item.tag.icon, size: 16)
            Text(item.tag.label)
                .font(.notoSans(14, .medium))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        let count = Text("\(item.count)명")
            .font(.notoSans(13, .medium))
            .foregroundStyle(.textSecondary)
            // 폭이 좁아질 때 문구가 아니라 인원수가 먼저 눌리는 것을 막는다
            .fixedSize()

        if dynamicTypeSize.isAccessibilitySize {
            // 큰 글자에서 한 줄에 두면 "21명"이 폭 0으로 눌려 사라진다
            VStack(alignment: .leading, spacing: 2) {
                name
                count
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                name
                Spacer(minLength: 8)
                count
            }
        }
    }

    private var track: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.photoPlaceholder)
                Capsule()
                    .fill(Color.moduwaGreen)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}

#Preview("작성 칩") {
    VStack(alignment: .leading, spacing: 20) {
        FlowLayout {
            ForEach(Array(MockFeedService.tagPool.enumerated()), id: \.element.id) { index, tag in
                ReviewTagSelectChip(tag: tag, isSelected: index % 2 == 0) {}
            }
        }
        FlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(MockFeedService.tagPool) { ReviewTagBadge(tag: $0) }
        }
    }
    .padding(24)
}

#Preview("집계 막대") {
    VStack(spacing: 16) {
        ForEach(zip(MockFeedService.tagPool, [118, 74, 41, 21, 9]).map(ReviewTagCount.init)) { item in
            ReviewTagCountBar(item: item, maxCount: 118)
        }
    }
    .padding(24)
}
