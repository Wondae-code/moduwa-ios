import SwiftUI

/// 설정 → 차단한 사용자. 차단은 **해제할 길이 함께 있어야** 성립한다 —
/// 되돌릴 수 없으면 차단이 아니라 삭제다.
struct BlockedUsersView: View {
    @Environment(\.blockService) private var blockService
    @Environment(\.blockSignal) private var blockSignal
    @Environment(SessionStore.self) private var session

    @State private var users: [BlockedUser] = []
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var loadFailed = false
    /// 해제 중인 사람. 두 번 누르는 것을 막고 그 줄만 흐리게 한다.
    @State private var unblocking: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            title
            content
        }
        .background(Color.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var title: some View {
        Text("차단한 사용자")
            .font(.notoSans(20, .bold, relativeTo: .title3))
            .tracking(-0.4)
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// ⚠️ 어느 상태든 남는 공간을 채운다 — 짧은 쪽이 내용 높이만 차지하면 바깥 스택이 짧아지고
    /// SwiftUI 가 그것을 가운데로 정렬하면서 제목까지 내려온다("내 게시글"에서 실측한 함정).
    @ViewBuilder
    private var content: some View {
        if session.account == nil {
            SignInPromptView(
                title: "로그인하면 차단 목록을 볼 수 있어요",
                message: "차단은 계정에 저장돼요. 기기를 바꿔도 그대로 따라옵니다.",
                prompt: .comment
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if isLoading && !didLoad {
            row("차단 목록을 불러오는 중이에요")
        } else if loadFailed && !didLoad {
            retryRow
        } else if users.isEmpty {
            row("차단한 사용자가 없어요")
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let errorMessage {
                    AuthErrorLine(message: errorMessage)
                        .padding(.horizontal, 24)
                        .padding(.bottom, Spacing.s)
                }
                ForEach(users) { user in
                    userRow(user)
                    Rectangle().fill(Color.cardStroke).frame(height: 1)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable { await load() }
    }

    private func userRow(_ user: BlockedUser) -> some View {
        HStack(spacing: 12) {
            AuthorAvatar(name: user.nickname, avatarURL: user.avatarURL, diameter: 40)

            Text(user.nickname.isEmpty ? "알 수 없음" : user.nickname)
                .font(.notoSans(15, .medium, relativeTo: .body))
                .foregroundStyle(.textPrimary)

            Spacer(minLength: 8)

            Button {
                Task { await unblock(user) }
            } label: {
                Text("차단 해제")
                    .font(.notoSans(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.deepGreen, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(unblocking.contains(user.uuid))
            .accessibilityLabel("\(user.nickname) 차단 해제")
        }
        .opacity(unblocking.contains(user.uuid) ? 0.4 : 1)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func row(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(14, relativeTo: .subheadline))
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var retryRow: some View {
        VStack(spacing: 14) {
            Text("차단 목록을 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
            Button("다시 시도") { Task { await load() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func load() async {
        guard session.account != nil, !isLoading else { return }
        isLoading = true
        loadFailed = false
        do {
            users = try await blockService.blocked()
            didLoad = true
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    /// 해제는 서버가 먼저다 — 화면에서 먼저 지우고 실패하면 차단이 풀린 것처럼 보인다.
    private func unblock(_ user: BlockedUser) async {
        unblocking.insert(user.uuid)
        errorMessage = nil
        do {
            try await blockService.unblock(uuid: user.uuid)
            users.removeAll { $0.uuid == user.uuid }
            // 목록을 든 화면들이 이 사람의 글을 다시 받아야 한다.
            blockSignal.changed()
            UIAccessibility.post(notification: .announcement, argument: "차단을 해제했어요")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "차단을 해제하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
        unblocking.remove(user.uuid)
    }
}

#Preview("차단한 사용자") {
    NavigationStack { BlockedUsersView() }
        .environment(SessionStore(service: MockAuthService()))
}
