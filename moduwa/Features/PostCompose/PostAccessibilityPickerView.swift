import SwiftUI

/// 무장애 정보 추가 — 게시글 작성 화면의 라임 캡슐(시안 652:3429).
///
/// **시안은 버튼만 있고 누른 뒤 화면이 없다.** 무엇을 담는지도 적혀 있지 않아,
/// 이 앱의 축(브랜드 가이드 접근성 아이콘 5종)에 맞춰 **"어떤 접근성이 좋았는지 고르는" 화면**으로
/// 정했다 — 게시글이 다른 사람의 여행 판단에 쓰이려면 그 정보가 가장 값지다.
///
/// 별점이나 등급을 두지 않는다. 접근성은 "몇 점"이 아니라 **되는지 안 되는지**의 문제이고,
/// 점수는 사람마다 기준이 달라 다음 방문자에게 쓸모가 없다.
struct PostAccessibilityPickerView: View {
    @Binding var selection: [AccessibilityFeature]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("어떤 점이 편했나요?")
                        .font(.notoSans(18, .bold, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("고른 정보는 글에 뱃지로 붙어요. 다음 여행자가 이 글을 보고 갈 수 있을지 판단해요.")
                        .font(.notoSans(13))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        // 온보딩과 같은 목록·같은 줄을 쓴다(`AccessibilityChoiceRow`).
                        ForEach(AccessibilityChoiceRow.choices, id: \.self) { feature in
                            row(feature)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { doneBar }
    }

    private var headerBar: some View {
        Text("무장애 정보 추가")
            .font(.notoSans(18, .bold, relativeTo: .headline))
            .tracking(-0.4)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ feature: AccessibilityFeature) -> some View {
        AccessibilityChoiceRow(feature: feature, isOn: selection.contains(feature)) {
            if selection.contains(feature) {
                selection.removeAll { $0 == feature }
            } else {
                selection.append(feature)
            }
        }
    }

    /// 아무것도 안 고른 채 닫아도 된다 — 무장애 정보는 선택이다.
    /// 그래서 "완료"만 두고 취소를 따로 두지 않는다(고르는 즉시 반영되므로 되돌리려면 다시 누른다).
    private var doneBar: some View {
        Button { dismiss() } label: {
            Text(selection.isEmpty ? "닫기" : "\(selection.count)개 선택 완료")
                .font(.notoSans(16, .bold))
                .foregroundStyle(selection.isEmpty ? Color.textSecondary : Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Capsule().fill(
                    selection.isEmpty ? Color.photoPlaceholder : Color.moduwaGreen))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }
}

#Preview("무장애 정보") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PostAccessibilityPickerView(selection: .constant([.wheelchairAccessible]))
        }
}
