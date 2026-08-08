import SwiftUI

/// 플랜 목록 — Figma "03. 플랜"(391:232)
struct PlanListView: View {
    let plans: [Plan]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 30) {
                    ForEach(plans) { plan in
                        PlanCard(plan: plan)
                    }

                    createPlanButton
                        .padding(.top, 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground)
        .navigationDestination(for: Plan.self) { PlanDetailView(plan: $0) }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("내 플랜")
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .tracking(-0.4)

            Spacer(minLength: 0)

            // 메뉴는 아직 목적지가 없다 — 시안 자리만 잡아둔다.
            Image("hamburger")
                .renderingMode(.template)
                .resizable()
                .frame(width: 26, height: 26)
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)
        }
    }

    private var createPlanButton: some View {
        Button {
            // 새 플랜 플로우(03-2)는 아직 미구현
        } label: {
            Text("+ 새 플랜 계획하기")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 57)
                .padding(.vertical, 10)
                .background(Color.moduwaGreen, in: Capsule())
        }
    }
}

// MARK: - 카드

/// 진행 중 플랜은 흰 배경 + 라임 테두리에 버튼 두 개, 지난 플랜은 회색 배경에 흑백 썸네일.
/// 두 상태를 `Plan.isPast()`로만 가른다 — 시안의 "지난 여행 - 날짜 수정시"(519:378)가
/// 날짜만 고치면 카드가 되살아나는 동작이 이 파생과 맞는다.
private struct PlanCard: View {
    let plan: Plan

    private var isPast: Bool { plan.isPast() }

    var body: some View {
        VStack(spacing: 15) {
            NavigationLink(value: plan) {
                HStack(alignment: .top, spacing: 10) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.title)
                            .font(.notoSans(18, .bold, relativeTo: .headline))
                            .tracking(-0.4)

                        Text(plan.dateRangeText)
                            .font(.notoSans(14, .regular, relativeTo: .subheadline))
                            .tracking(-0.4)
                    }
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if !isPast {
                HStack(spacing: 7) {
                    // 둘 다 목적지가 아직 없다. "일정에 추가"는 일정 탭 설계 후 연결한다.
                    actionButton("팀 수정", background: .moduwaGreen, foreground: .textPrimary)
                    actionButton("일정에 추가", background: .deepGreen, foreground: .white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 25)
        .background(isPast ? Color.cardStroke : Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            if !isPast {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.moduwaGreen, lineWidth: 1)
            }
        }
        .shadow(color: Color.deepGreen.opacity(0.05), radius: 5, y: 2)
    }

    /// 지난 플랜 썸네일은 시안이 mix-blend-luminosity로 흑백 처리한다.
    private var thumbnail: some View {
        Group {
            if let url = plan.coverImageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.photoPlaceholder
                }
            } else {
                Color.photoPlaceholder
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .grayscale(isPast ? 1 : 0)
    }

    private func actionButton(_ title: String, background: Color, foreground: Color) -> some View {
        Button {
        } label: {
            Text(title)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(background, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        PlanListView(plans: MockData.plans)
    }
}
