import SwiftUI

/// 최근 코스 불러오기 — 게시글 작성 헤더의 "최근코스 불러오기"(시안 642:2782).
///
/// 짜 놓은 플랜의 장소를 글에 한꺼번에 붙인다. 여행을 다녀와 글을 쓰는 사람이 방문한 곳을
/// 하나씩 다시 검색하지 않아도 되게 하는 자리다.
///
/// ⚠️ **목록 응답만으로는 붙일 수 없다.** 목록은 장소 **이름만** 준다(`daySummaries`) —
/// 게시글의 장소는 `contentID` 로 원본 장소에 이어져야 해서, 고른 플랜의 상세를 한 번 더 받는다.
struct PostCoursePickerView: View {
    /// 이미 붙인 장소. 중복으로 붙지 않게 걸러 내는 데 쓴다.
    let attached: [PostPlace]
    var onPick: ([PostPlace]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.planService) private var planService

    @State private var state: LoadState = .loading
    /// 상세를 받아 오는 중인 플랜. 그 줄만 비활성 + 스피너.
    @State private var loadingID: Plan.ID?
    @State private var pickError: String?

    private enum LoadState {
        case loading
        case failed
        case loaded([Plan])
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            content
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .foregroundStyle(.textPrimary)
            .accessibilityLabel("닫기")

            Text("최근 코스 불러오기")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.leading, 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            message("플랜을 불러오는 중이에요", isLoading: true)
        case .failed:
            VStack(spacing: 14) {
                message("플랜을 불러오지 못했어요", isLoading: false)
                Button("다시 시도") { Task { await load() } }
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let plans) where plans.isEmpty:
            message("아직 만든 플랜이 없어요", isLoading: false)
        case .loaded(let plans):
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let pickError {
                        Text(pickError)
                            .font(.notoSans(13))
                            .foregroundStyle(Color.deepGreen)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 12)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                            row(plan)
                            if index < plans.count - 1 {
                                Rectangle().fill(Color.photoPlaceholder).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func row(_ plan: Plan) -> some View {
        // 목록 응답의 요약으로 몇 곳이 담겼는지 미리 보여 준다 — 고르기 전에 알 수 있어야 한다.
        let names = plan.daySummaries.flatMap(\.placeNames)
        return Button {
            Task { await pick(plan) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.notoSans(15, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(plan.dottedDateRangeText)
                        .font(.meta13)
                        .foregroundStyle(Color.textSecondary)

                    if names.isEmpty {
                        Text("담긴 장소가 없어요")
                            .font(.notoSans(13))
                            .foregroundStyle(Color.iconGray)
                    } else {
                        Text(names.joined(separator: " · "))
                            .font(.notoSans(13))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if loadingID == plan.id {
                    ProgressView().tint(.deepGreen)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(names.isEmpty ? Color.cardStroke : Color.deepGreen)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 담긴 장소가 없으면 붙일 것이 없다.
        .disabled(names.isEmpty || loadingID != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.title), \(plan.dottedDateRangeText), 장소 \(names.count)곳")
        .accessibilityHint(names.isEmpty ? "담긴 장소가 없어요" : "두 번 탭하면 이 코스의 장소를 붙입니다")
    }

    private func message(_ text: String, isLoading: Bool) -> some View {
        VStack(spacing: 10) {
            if isLoading { ProgressView().tint(.deepGreen) }
            Text(text)
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    // MARK: - 동작

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await planService.fetchPlans())
        } catch {
            state = .failed
        }
    }

    /// 고른 플랜의 상세를 받아 장소를 뽑는다.
    ///
    /// **나만의 장소는 빠진다** — `contentID` 가 없어(사용자가 지도에 찍은 점이다) 게시글의
    /// 장소로 이어 붙일 원본이 없다. 조용히 빼면 왜 개수가 다른지 알 수 없으므로 사유를 알린다.
    private func pick(_ plan: Plan) async {
        loadingID = plan.id
        pickError = nil
        defer { loadingID = nil }

        let detail: Plan
        do {
            detail = try await planService.fetchPlan(id: plan.id)
        } catch {
            pickError = (error as? PlanServiceError)?.errorDescription
                ?? "코스를 불러오지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            return
        }

        let stops = detail.days.flatMap(\.stops)
        let custom = stops.filter { $0.place.isCustom }.count
        let attachedIDs = Set(attached.map(\.contentID))
        var seen = attachedIDs
        var picked: [PostPlace] = []
        for stop in stops {
            guard let contentID = stop.place.contentID, !seen.contains(contentID) else { continue }
            seen.insert(contentID)
            picked.append(PostPlace(
                contentID: contentID, name: stop.place.name, region: stop.place.region))
        }

        guard !picked.isEmpty else {
            pickError = custom > 0
                ? "이 코스는 나만의 장소로만 이루어져 있어 붙일 수 없어요."
                : "이미 붙인 장소뿐이에요."
            return
        }

        onPick(picked)
        if custom > 0 {
            // 붙이긴 했지만 개수가 다른 이유를 남긴다. 화면은 곧 닫히므로 스크린리더로도 알린다.
            UIAccessibility.post(
                notification: .announcement,
                argument: "장소 \(picked.count)곳을 붙였어요. 나만의 장소 \(custom)곳은 제외했어요.")
        }
        dismiss()
    }
}

#Preview("최근 코스") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PostCoursePickerView(attached: []) { _ in }
                .environment(\.planService, MockPlanService())
        }
}
