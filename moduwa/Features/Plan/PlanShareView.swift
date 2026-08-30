import SwiftUI

/// 플랜 "함께하기" — 초대 링크 발급·공유와 멤버 관리(서버 "플랜 공동 편집").
///
/// 소유자는 초대 링크를 만들어 공유하고 멤버를 내보낼 수 있다. 편집자는 멤버를 보고
/// **자기만** 나갈 수 있다. 역할 판정은 서버가 준 `plan.myRole` 을 그대로 따른다 —
/// 없는 권한을 화면에 그리면 눌러도 403(`owner_only`)만 돌아온다.
///
/// 시안이 없어 앱 기존 패턴(시트 + 섹션 + 라임/딥그린 버튼)으로 짰다.
struct PlanShareView: View {
    let plan: Plan
    /// 멤버가 바뀌면(강퇴) 상세를 다시 받게 한다.
    var onMembersChanged: () async -> Void = {}
    /// 내가 이 플랜을 나갔다 — 상세를 닫는다.
    var onLeft: () -> Void = {}

    @Environment(\.planService) private var planService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// 화면에 그리는 멤버. 강퇴하면 서버 왕복을 기다리지 않고 먼저 지운다(낙관적).
    @State private var members: [PlanMember]
    /// 이번에 발급한 초대. 서버는 활성 코드를 GET 으로 주지 않으므로 시트를 열 때마다 비운다.
    @State private var invite: PlanInvite?
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(plan: Plan, onMembersChanged: @escaping () async -> Void = {}, onLeft: @escaping () -> Void = {}) {
        self.plan = plan
        self.onMembersChanged = onMembersChanged
        self.onLeft = onLeft
        _members = State(initialValue: plan.members)
    }

    private var myUUID: String? { session.account?.uuid }
    private var isOwner: Bool { plan.myRole == .owner }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.notoSans(13))
                            .foregroundStyle(.errorRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isOwner { inviteSection }
                    memberSection
                    if !isOwner { leaveSection }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, Spacing.xl)
            }
            .background(.white)
            .navigationTitle("함께하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.textPrimary)
                }
            }
        }
    }

    // MARK: - 초대 (소유자)

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("초대")

            if let invite {
                Text(invite.code)
                    .font(.notoSans(26, .bold))
                    .tracking(3)
                    .foregroundStyle(.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.l)
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

                ShareLink(item: invite.inviteURL) {
                    pillLabel("링크 공유하기", systemImage: "square.and.arrow.up", filled: true)
                }

                HStack(spacing: Spacing.s) {
                    Button { Task { await makeInvite() } } label: {
                        pillLabel("링크 다시 만들기", filled: false)
                    }
                    .buttonStyle(.plain)
                    Button { Task { await revoke() } } label: {
                        pillLabel("초대 회수", filled: false)
                    }
                    .buttonStyle(.plain)
                }
                .disabled(isWorking)

                Text("\(invite.expiresInMinutes)분 후 만료돼요. 링크 하나로 여러 명이 들어올 수 있어요. 다시 만들면 이전 링크는 끊겨요.")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button { Task { await makeInvite() } } label: {
                    pillLabel(isWorking ? "만드는 중…" : "초대 링크 만들기", filled: true)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                Text("링크를 공유하면 받은 사람이 이 플랜을 함께 편집할 수 있어요. 소유자 포함 최대 10명.")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 멤버

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("멤버 \(members.count)/10")

            VStack(spacing: 0) {
                ForEach(members) { member in
                    memberRow(member)
                    if member.id != members.last?.id {
                        Rectangle().fill(Color.cardStroke).frame(height: 1)
                            .padding(.leading, 56)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
        }
    }

    private func memberRow(_ member: PlanMember) -> some View {
        let isMe = member.uuid == myUUID
        return HStack(spacing: Spacing.m) {
            Circle()
                .fill(member.role == .owner ? Color.deepGreen : Color.iconGray)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(member.nickname.prefix(1)))
                        .font(.notoSans(14, .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(member.nickname) (나)" : member.nickname)
                    .font(.notoSans(15, .medium))
                    .foregroundStyle(.textPrimary)
                Text(member.role == .owner ? "소유자" : "편집자")
                    .font(.notoSans(12))
                    .foregroundStyle(.textSecondary)
            }

            Spacer(minLength: 0)

            // 소유자만, 자기 아닌 멤버를 내보낼 수 있다.
            if isOwner, !isMe {
                Button { Task { await kick(member) } } label: {
                    Text("내보내기")
                        .font(.notoSans(13, .medium))
                        .foregroundStyle(.errorRed)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - 나가기 (편집자)

    private var leaveSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button { Task { await leave() } } label: {
                Text("플랜 나가기")
                    .font(.notoSans(16, .bold, relativeTo: .headline))
                    .foregroundStyle(.errorRed)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.errorRed, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)

            Text("나가면 이 플랜이 내 목록에서 사라져요. 다시 들어오려면 새 초대가 필요해요.")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 조각

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(16, .bold, relativeTo: .headline))
            .foregroundStyle(.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    /// 라임(채움)·테두리(비움) 두 종류의 알약 버튼 라벨.
    private func pillLabel(_ title: String, systemImage: String? = nil, filled: Bool) -> some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.notoSans(15, .bold, relativeTo: .headline))
        .foregroundStyle(filled ? Color.deepGreen : Color.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(filled ? Color.moduwaGreen : Color.photoPlaceholder)
        )
    }

    // MARK: - 동작

    private func makeInvite() async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        do { invite = try await planService.createInvite(planId: plan.id) }
        catch { errorMessage = message(for: error) }
        isWorking = false
    }

    private func revoke() async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        do {
            try await planService.revokeInvite(planId: plan.id)
            invite = nil
        } catch { errorMessage = message(for: error) }
        isWorking = false
    }

    private func kick(_ member: PlanMember) async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        do {
            try await planService.removeMember(planId: plan.id, memberUUID: member.uuid)
            members.removeAll { $0.uuid == member.uuid }
            await onMembersChanged()
        } catch { errorMessage = message(for: error) }
        isWorking = false
    }

    private func leave() async {
        guard !isWorking, let myUUID else { return }
        isWorking = true; errorMessage = nil
        do {
            try await planService.removeMember(planId: plan.id, memberUUID: myUUID)
            dismiss()
            onLeft()
        } catch { errorMessage = message(for: error) }
        isWorking = false
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "잠시 후 다시 시도해 주세요."
    }
}

#Preview("함께하기 — 소유자") {
    PlanShareView(plan: Plan(
        title: "제주 3박 4일",
        startDate: .now,
        endDate: .now,
        myRole: .owner,
        members: [
            PlanMember(uuid: "me", nickname: "대원", role: .owner),
            PlanMember(uuid: "b", nickname: "지현", role: .editor),
        ]
    ))
    .environment(SessionStore(service: MockAuthService()))
    .environment(\.planService, MockPlanService())
}
