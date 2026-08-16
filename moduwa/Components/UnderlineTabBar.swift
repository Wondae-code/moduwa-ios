import SwiftUI

/// 밑줄로 선택을 표시하는 탭 바 — 장소 후기 화면(2탭)과 일정 탭(3탭)이 함께 쓴다.
///
/// `PlaceReviewsView` 안에 있던 것을 그대로 뺐다. 일정 탭 시안(532:241)의 세그먼트가
/// 규격까지 같아서(16pt, 선택 시 Bold + 딥그린 2.5pt 밑줄, 비선택 회색 1pt) 값을 베끼는 대신
/// 같은 뷰를 쓰게 한다 — 베껴 두면 한쪽 시안이 바뀔 때 반드시 어긋난다.
///
/// 접근성 판단: `TabView`가 아니라 버튼 여러 개 + 밑줄이다. 그래서 컨테이너에 `.isTabBar`를 주고
/// 선택 상태를 색(딥그린)·굵기·밑줄에 더해 `.isSelected` 트레이트로도 전달한다.
/// 색만 바뀌면 색각 이상 환경에서 지금 어느 탭인지 알 수 없다.
struct UnderlineTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    /// 탭에 그릴 문구.
    let title: (Tab) -> String
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(title(tab))
                            .font(.notoSans(16, selection == tab ? .bold : .medium))
                            .foregroundStyle(selection == tab ? .textPrimary : .textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .padding(.top, 14)
                            // 접근성 글자 크기에서 한쪽 라벨만 두 줄로 접히면 밑줄 높이가 서로 어긋난다.
                            // 글자 영역을 HStack이 정한 높이(가장 큰 쪽)까지 늘려 밑줄을 같은 선에 맞춘다.
                            .frame(maxHeight: .infinity, alignment: .center)
                        // 선택 표시는 2.5pt 밑줄, 비선택은 1pt 회색 선 — 밑줄의 유무·굵기가 형태 신호다
                        Rectangle()
                            .fill(selection == tab ? Color.deepGreen : Color.cardStroke)
                            .frame(height: selection == tab ? 2.5 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(tab))
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        // 가장 높은 탭에 맞춰 줄 높이를 확정한다 (밑줄 정렬의 전제)
        .fixedSize(horizontal: false, vertical: true)
        .background(.white)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }
}

extension UnderlineTabBar where Tab: RawRepresentable, Tab.RawValue == String {
    /// rawValue 가 곧 표시 문구인 흔한 경우.
    init(tabs: [Tab], selection: Binding<Tab>) {
        self.init(tabs: tabs, title: { $0.rawValue }, selection: selection)
    }
}
