import SwiftUI

// 새 플랜 플로우 6단계가 공유하는 골격 — Figma 372:409 · 391:96 · 519:1219 · 519:1343
//
// 색 관련 판단(전 단계 공통):
//  시안의 비활성 문구는 #B3B3B3(`iconGray`)인데 흰 배경·#F2F2F2 칩 위에서 대비가 2:1 언저리라
//  본문 최소 4.5:1을 넘지 못한다. 무장애가 주제인 앱에서 읽을 수 없는 글자를 그대로 둘 수 없어
//  **읽어야 하는 글자는 `textSecondary`(#4D4D4D)로 올렸다**. 아이콘·구분선처럼 정보를 담지 않는
//  요소는 시안대로 `iconGray`를 쓴다. (기존 `ReviewTagSelectChip`도 같은 선택을 하고 있다)

// MARK: - 상단 (뒤로 · 진행 바 · n / 6)

/// 시안 Top(393×100) 중 상태 바를 뺀 56pt — 뒤로 화살표(x 25, y 23), "n / 6"(오른쪽 24),
/// 진행 바(x 28, 폭 337, y 100)로 이루어진다.
struct PlanCreateHeader: View {
    let step: PlanCreateStep
    let onBack: () -> Void

    private var progress: Double {
        Double(step.rawValue) / Double(PlanCreateStep.total)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        // 글리프는 20인데 시안의 화살표 중심(x 35)에 맞추려면 44 탭 영역이 필요하다
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(step == .party ? "새 플랜 만들기 그만두기" : "이전 단계로")

                Spacer(minLength: 0)

                counter
                    // 시안에서 카운터는 화살표보다 진행 바 쪽으로 내려와 있다 (중심 y 36 vs 23)
                    .padding(.top, 12)
                    .padding(.trailing, 24)
            }
            .padding(.leading, 13)

            track
                .padding(.horizontal, 28)
                .padding(.top, 4)
        }
        // 막대와 숫자는 같은 사실의 두 표현이라 하나로 읽힌다.
        // 진행 상태를 막대(그래픽)만으로 전달하면 스크린리더에는 아무것도 남지 않는다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행 상황")
        .accessibilityValue("\(PlanCreateStep.total)단계 중 \(step.rawValue)단계")
    }

    /// 현재 단계만 딥그린 Bold로 굵어진다 (시안 519:1207)
    private var counter: some View {
        HStack(spacing: 0) {
            Text("\(step.rawValue)")
                .font(.notoSans(14, .bold, relativeTo: .subheadline))
                .foregroundStyle(Color.deepGreen)
            Text(" / \(PlanCreateStep.total)")
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(Color.textSecondary)
        }
        .tracking(-0.4)
        .fixedSize()
    }

    /// 채움은 **라임**이다(시안 `958:658` 의 SVG `fill=#A7E100`). 딥그린으로 그리고 있었다.
    ///
    /// 트랙은 시안이 `#F2F2F2` 인데 `cardStroke`(#E6E6E6)를 그대로 둔다 — 보통 모드에서는
    /// 구분되지 않는 차이인데, **고대비에서는 `cardStroke` 가 #8C8C8C 로 짙어져** 라임 채움과
    /// 훨씬 잘 갈린다(`photoPlaceholder` 는 고대비에서도 #E4E4E4 로 밝다).
    ///
    /// ⚠️ 라임 채움과 밝은 트랙의 대비는 1.3:1 로 낮다. 진행 상황을 막대만으로 전달하지 않는
    /// 이유가 여기 있다 — 옆의 "4 / 6" 숫자와 스크린리더 값이 같은 사실을 함께 말한다.
    private var track: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.cardStroke)
                Capsule()
                    .fill(Color.moduwaGreen)
                    .frame(width: geometry.size.width * progress)
            }
        }
        // 시안 `Line 6`·`Line 7` 의 stroke 가 **5** 다(8 로 그리고 있었다).
        .frame(height: 5)
    }
}

// MARK: - 질문 제목

/// 시안 공통 — 왼쪽 24, Bold 20, 자간 -0.4.
struct PlanCreateQuestion: View {
    let text: String
    /// 질문 아래 한 줄(선택). 고른 값이 어디에 쓰이는지 알려 준다.
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let hint {
                Text(hint)
                    .font(.notoSans(14, .regular, relativeTo: .subheadline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - 칩

/// 1/6·2/6·4/6이 공유하는 선택 칩. 시안 값: 좌우 14 / 상하 2, 캡슐, 14pt, 자간 -0.4.
///
/// 접근성 판단 — 선택 상태를 **색만으로** 전달하지 않는다:
///  ① 글자가 Regular → Bold 로 굵어지고 ② `.isSelected` 가 스크린리더에 실린다.
///  체크 글리프는 넣지 않았다 — 칩 폭이 바뀌어 줄 전체가 흔들린다(`ReviewTagSelectChip`과 같은 이유).
///
/// 탭 영역은 시안의 30pt 알약보다 커야 한다. 알약은 그대로 두고 **위아래 5pt를 여백으로 덧대**
/// 40pt를 만든다 — 시안의 줄 간격(40 피치)이 마침 그 여백으로 채워져 배치도 함께 맞는다.
struct PlanCreateChip: View {
    let label: String
    let isSelected: Bool
    /// 한 줄에서 여러 개를 고를 수 있는지. 스크린리더 힌트 문구가 달라진다.
    var allowsMultiple = true
    /// 2/6·4/6의 3열 격자처럼 칸 폭을 꽉 채워야 하는 자리인지
    var fillsWidth = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 3열 격자에서 **한 줄로 고정하는지.** 칸 폭이 셋 다 같아야 하는데(같은 종류의
    /// 선택지니까) 문구 길이는 제각각이라, 제일 긴 것("통영·거제·남해")이 108pt 칸에
    /// 안 들어가 두 줄로 접히고 **그 줄만 높이가 달라졌다**(2026-09-07 실측).
    ///
    /// 칸을 넓히는 대신 글자를 살짝 줄인다 — 아이폰 17 Pro 폭에서는 줄지 않고, SE 처럼
    /// 좁은 화면에서만 0.85 배까지 준다(14 → 11.9pt). 칩 크기는 끝까지 같다.
    ///
    /// ⚠️ **접근성 글자 크기에서는 걸지 않는다.** 그때는 격자가 한 열로 펴져 줄바꿈이
    /// 정상이고, 한 줄로 묶으면 글자가 잘리거나 읽을 수 없게 작아진다.
    private var clampsToOneLine: Bool {
        fillsWidth && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                // 선택을 **색만으로** 전하지 않는다 — 굵기가 함께 바뀐다(시안은 둘 다 Medium 이지만
                //  고른 것을 색으로만 알리면 색을 구분하기 어려운 사람에게는 단서가 사라진다).
                .font(.notoSans(14, isSelected ? .bold : .regular, relativeTo: .subheadline))
                .tracking(-0.4)
                // 시안 `958:683/684`: 선택 칩은 **라임 배경 + 딥그린 글자**다(딥그린 배경 + 흰
                //  글자로 그리고 있었다). 미선택 글자는 시안이 `#B3B3B3` 인데 `textSecondary`
                //  (#4D4D4D)를 유지한다 — #B3B3B3 은 #F2F2F2 배경에서 1.9:1 로 읽을 수 없다.
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                .multilineTextAlignment(.center)
                // 접근성 글자 크기에서 칩 하나가 여러 줄이 되어도 잘리지 않게
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(clampsToOneLine ? 1 : nil)
                .minimumScaleFactor(clampsToOneLine ? 0.85 : 1)
                // 3열 격자는 12 — 14 로는 제일 긴 문구가 칸에 안 들어간다(위 주석).
                .padding(.horizontal, fillsWidth ? 12 : 14)
                .padding(.vertical, fillsWidth ? 6 : 2)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: fillsWidth ? 38 : 30)
                .background(Capsule().fill(isSelected ? Color.moduwaGreen : Color.photoPlaceholder))
                .padding(.vertical, fillsWidth ? 3 : 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(hint)
    }

    private var hint: String {
        if isSelected {
            allowsMultiple ? "두 번 탭하면 선택을 해제합니다" : "두 번 탭하면 선택을 해제합니다"
        } else {
            allowsMultiple ? "두 번 탭하면 선택합니다" : "두 번 탭하면 이 하나만 선택합니다"
        }
    }
}

// MARK: - 하단 버튼

/// 시안 공통 하단 — "다음으로"(라임 320×47 알약) 위에 "나중에 할래요"(건너뛰기).
///
/// **문구·색이 갱신됐다(2026-08-31 시안)**: 구 "완료했어요"(딥그린 345×55) 버튼은 시안에서
///  hidden 처리되고(958:639) 라임 "다음으로"(958:661)가 그 자리에 왔다. 스킵도 "다음에
///  할래요" → "나중에 할래요"(구 문구 958:638 은 hidden).
///
/// **"다음으로"는 항상 그리고, 값이 없으면 비활성이다**(2026-09-20 피드백).
///
/// 한동안은 값이 생겼을 때만 그렸다. 이유가 있었다 — 값이 없을 때 "다음으로"를 누르면
/// "나중에 할래요"와 **같은 동작**이 되어 두 버튼이 같은 뜻을 두 번 말하기 때문이다.
/// 그런데 그렇게 두니 **값을 고르는 순간 버튼이 툭 나타나** 화면이 흔들렸고, 그 전까지는
/// 다음으로 가는 길이 있다는 것조차 보이지 않았다.
///
/// 비활성 버튼은 그 걱정에 해당하지 않는다 — **눌리지 않으면 같은 동작이 아니다.**
/// 자리를 늘 차지하니 나타났다 사라지지도 않고, 회색이라 "아직 못 누른다"가 읽힌다.
/// "나중에 할래요"는 그대로 항상 남긴다 — 건너뛰기는 값이 없을 때가 오히려 필요한 자리다.
/// (초기 시안 372:409 에는 두 버튼이 아예 없어 아무것도 못 고른 사용자가 갇히기도 했다.)
struct PlanCreateFooter: View {
    /// 이 단계에서 고른 값이 있는지
    let hasValue: Bool
    var isBusy = false
    let onComplete: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onComplete) {
                ZStack {
                    // 시안(`958:662`)은 Medium 16 이지만 **Bold 로 둔다**(2026-08-31 사용자 결정) —
                    //  이 화면에서 유일한 다음 행동이라 눈에 먼저 들어와야 한다.
                    Text("다음으로")
                        .font(.notoSans(16, .bold, relativeTo: .headline))
                        .tracking(-0.4)
                        // 비활성 색은 `AuthPrimaryButton` 과 같은 규칙이다 — 앱 안에서 "못 누른다"가
                        //  한 가지 색으로 읽혀야 한다.
                        .foregroundStyle(hasValue ? Color.textPrimary : Color.iconGray)
                        .opacity(isBusy ? 0 : 1)
                    if isBusy { ProgressView().tint(.textPrimary) }
                }
                .frame(maxWidth: 320)
                .frame(minHeight: 47)
                .background(Capsule().fill(hasValue ? Color.moduwaGreen : Color.photoPlaceholder))
            }
            .buttonStyle(.plain)
            .disabled(!hasValue || isBusy)
            .animation(.easeInOut(duration: 0.15), value: hasValue)
            .accessibilityLabel("다음으로")
            // 왜 못 누르는지 말해 준다 — 비활성만으로는 스크린리더 사용자가 이유를 알 수 없다.
            .accessibilityHint(hasValue ? "다음 단계로 넘어갑니다" : "먼저 위에서 하나를 골라 주세요")

            Button(action: onSkip) {
                Text("나중에 할래요")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("나중에 할래요")
            .accessibilityHint("이 단계를 건너뜁니다")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        // 3/6 달력은 화면보다 길어 버튼 바로 위까지 날짜가 올라온다. 잘린 날짜 줄이 버튼에
        // 맞닿으면 어디까지가 달력인지 읽히지 않아, 목록 화면과 같은 방식으로 배경색까지 흐린다.
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.appBackground.opacity(0), Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .offset(y: -24)
        }
        .background(Color.appBackground)
    }
}

// MARK: - 저장 실패 안내

/// 저장·선택지 불러오기 실패를 알리는 줄. 사유는 서버가 준 한국어 문장을 그대로 쓴다.
struct PlanCreateNotice: View {
    let message: String
    var retryLabel: String?
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(Color.deepGreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retryLabel {
                Button(action: onRetry) {
                    Text(retryLabel)
                        .font(.notoSans(14, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.deepGreen)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
