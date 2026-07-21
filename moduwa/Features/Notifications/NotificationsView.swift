import SwiftUI

/// 알림 화면 (Figma "모두와 UI — 서브 > 알림") — 알림 API 전이라 빈 상태가 기본.
/// DEBUG 빌드에선 헤더의 + 버튼으로 mock 알림을 추가해 뱃지·목록 동작을 확인할 수 있다.
struct NotificationsView: View {
    @Environment(NotificationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            #if DEBUG
            debugBanner
            #endif

            if store.items.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        // 화면을 확인한 시점에 읽음 처리 — 이후 추가된 알림은 다시 뱃지를 띄운다
        .onAppear { store.markAllRead() }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("알림")
                .font(.pretendard(20, .bold))
                .padding(.leading, 12)
                .accessibilityAddTraits(.isHeader)

            Spacer()
        }
        .foregroundStyle(.textPrimary)
        .padding(.leading, 28)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    #if DEBUG
    /// 디버그 전용 배너 — 의도적으로 브랜드 디자인과 어긋나게(주황·점선·모노스페이스)
    /// 만들어 임시 도구임이 한눈에 보이게 한다. 알림 API 연동 시 통째로 제거.
    private var debugBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 12))
            Text("DEBUG")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
            Spacer()
            Button("+ 목 알림") { store.addMockNotification() }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white)
            Button("비우기") { store.removeAll() }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.gray, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.orange, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityLabel("디버그 도구: 목 알림 추가, 비우기")
    }
    #endif

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Circle()
                .fill(Color.photoPlaceholder)
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "bell")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.iconGray)
                }
            Text("아직 알림이 없어요")
                .font(.pretendard(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Text("새로운 소식이 도착하면 여기에서 알려드릴게요")
                .font(.pretendard(14))
                .foregroundStyle(.textSecondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var notificationList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.deepGreen.opacity(item.isRead ? 0.15 : 1))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(item.isRead ? Color.deepGreen : .white)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.pretendard(15, .bold))
                                .foregroundStyle(.textPrimary)
                            Text(item.body)
                                .font(.pretendard(14))
                                .foregroundStyle(.textSecondary)
                            Text(item.receivedAt, format: .relative(presentation: .named))
                                .font(.caption12)
                                .foregroundStyle(.iconGray)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, 14)

                    Rectangle()
                        .fill(Color.photoPlaceholder)
                        .frame(height: 1)
                        .padding(.leading, Spacing.xl)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(NotificationStore())
}
