import SwiftUI

/// 마이페이지 — Figma "설정"(977:662).
///
/// **서랍이 아니라 전체 화면이다.** 예전 판은 오른쪽에서 밀려 나오는 295pt 서랍이었는데
/// (구 시안 821:103), 그 시안이 삭제되고 헤더 "설정"을 가진 전체 화면으로 다시 그려졌다.
/// 시안에 탭바가 그대로 남아 있으므로 **탭 안에서 밀어 올린다** — 진입 버튼
/// (`AccountMenuButton`)이 네 탭의 헤더에 있고, 그 버튼이 자기 자리에서 이 화면을 민다.
///
/// 줄 구성도 시안을 따른다: 프로필 → 내 무장애정보 편집 → (6pt 굵은 구분) → 알림 설정 ·
/// 내 게시글 · 접근성 · 고객센터 · 서비스 이용약관. 구 서랍의 "설정"(화면 이름과 겹친다)과
/// "이용 가이드"는 시안에서 빠졌다.
///
/// ⚠️ 시안에 **로그아웃 자리가 없다.** 로그아웃·이메일 인증·비밀번호 변경은 `AccountInfoView`
/// 하나에 모여 있어서 **프로필 편집 화면 안**으로 옮겼다(이름 옆 연필 → 프로필 편집 → 회원정보 수정).
/// 빼면 앱에서 로그아웃할 길이 사라진다.
struct AccountSettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// 줄 하나가 미는 화면.
    private enum Row: Hashable, Identifiable {
        case accessProfile, profileEdit, myPosts, accessibility, helpCenter, terms

        var id: Self { self }
    }

    @State private var row: Row?

    /// 앱 푸시 알림 허용(시안 978:1163).
    ///
    /// ⚠️ **아직 UI 뿐이다** — 앱에 APNs 등록도, 권한 요청도 없다(`UNUserNotificationCenter`
    /// 호출 0건). 값은 기기에 남지만 그것으로 알림이 오거나 멈추지는 않는다. 푸시가 붙으면
    /// 이 값을 시스템 권한 상태와 맞추고, 켤 때 권한을 요청하는 자리로 쓴다.
    @AppStorage("pushNotificationsAllowed") private var pushAllowed = true

    /// 시안 값: 화면 393에 줄 폭 321 — 좌우 36.
    private static let rowInset: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    profile
                    accessProfileRow
                    thickDivider
                    menu
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $row) { destination($0) }
    }

    // MARK: - 헤더

    /// 시안 978:1024 — "설정" Bold 20, 좌측 24, 아래 1pt 보더.
    ///
    /// ⚠️ **시안 헤더에는 뒤로가기가 없다.** 시안은 이 화면을 탭 자체로 그렸지만 앱은 탭 안에서
    /// 밀어 올리므로, 꺾쇠가 없으면 나갈 길이 사라진다 — 내비게이션 바를 숨기면 스와이프로
    /// 되돌아가는 제스처까지 함께 죽는다(실측). 같은 파일의 형제 시안(983:1193 "‹ 내 무장애정보
    /// 편집")이 쓰는 그 꺾쇠를 같은 자리에 둔다.
    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.textPrimary)
            }
            .accessibilityLabel("뒤로 가기")

            Text("설정")
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 프로필

    /// 아바타(무장애 뱃지 얹음) + 이름 + 연필. 시안 983:1185.
    private var profile: some View {
        VStack(spacing: 0) {
            avatar

            HStack(spacing: 6) {
                Text(session.account?.nickname ?? "로그인이 필요해요")
                    .font(.notoSans(20, .bold, relativeTo: .title3))
                    .tracking(-0.08)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                // 시안의 연필 = 프로필 편집(사진·닉네임). 계정을 다루는 화면(회원정보·인증·
                //  로그아웃)은 그 화면 안에서 이어진다 — 설정 시안 다섯 줄에 자리가 없다.
                if session.account != nil {
                    Button { row = .profileEdit } label: {
                        Image("detail_pencil")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                            .foregroundStyle(.textSecondary)
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("프로필 편집")
                }
            }
            .padding(.top, 4)

            // 시안은 로그인한 상태만 그린다. 비로그인이면 이 자리에서 로그인으로 보낸다 —
            //  아래 줄들(접근성·고객센터·약관)은 계정 없이도 쓸 수 있어 그대로 둔다.
            if session.account == nil {
                AuthPrimaryButton(title: "로그인") {
                    session.prompt = .direct
                }
                .padding(.top, 16)
                .padding(.horizontal, Self.rowInset)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 33)
        .padding(.bottom, 20)
    }

    /// 라임 원 100 + 우하단 딥그린 뱃지. 뱃지의 픽토그램은 **지금 고른 무장애 항목**이다 —
    /// 무엇이 저장돼 있는지 프로필에서 바로 보이게 한다(고른 것이 없으면 시안과 같은 지체장애).
    private var avatar: some View {
        let feature = session.accessFeatures.first ?? .wheelchairAccessible
        let size = feature.iconSize(height: 19)
        return Group {
            // 사진을 올렸으면 그것, 없으면 라임 원(시안 983:1302 의 기본 아바타).
            if let url = session.account?.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.photoPlaceholder
                }
            } else {
                Color.moduwaGreen.opacity(0.3)
            }
        }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.deepGreen)
                    .frame(width: 37, height: 37)
                    .overlay {
                        Image(feature.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .foregroundStyle(.white)
                    }
            }
            .accessibilityElement()
            .accessibilityLabel("내 무장애 정보: \(feature.label)")
    }

    // MARK: - 줄

    /// "내 무장애정보 편집" — 시안 978:1034. 제목이 Bold 이고 부제가 붙는다(다른 줄은 Medium).
    private var accessProfileRow: some View {
        SettingsRow(
            title: "내 무장애정보 편집",
            subtitle: "추천코스 등 앱 이용시 반영돼요",
            isTitleBold: true,
            showsDivider: false
        ) {
            row = .accessProfile
        }
        .padding(.horizontal, Self.rowInset)
    }

    /// 시안 983:1168 — 섹션을 가르는 6pt 띠. 화면 폭을 꽉 채운다.
    private var thickDivider: some View {
        Rectangle()
            .fill(Color.photoPlaceholder)
            .frame(height: 6)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            // 알림 설정은 계정이 아니라 **이 기기**의 값이라 로그인과 무관하게 둔다.
            SettingsRow(
                title: "알림 설정",
                subtitle: "앱 푸시 알림 허용",
                height: 85
            ) {
                Toggle("", isOn: $pushAllowed)
                    .labelsHidden()
                    .tint(.moduwaGreen)
                    .accessibilityLabel("앱 푸시 알림 허용")
            }

            if session.account != nil {
                SettingsRow(title: "내 게시글") { row = .myPosts }
            }
            SettingsRow(title: "접근성") { row = .accessibility }
            SettingsRow(title: "고객센터") { row = .helpCenter }
            SettingsRow(title: "서비스 이용약관", showsDivider: false) { row = .terms }
        }
        .padding(.horizontal, Self.rowInset)
        .padding(.bottom, Spacing.xxl)
    }

    // MARK: - 목적지

    @ViewBuilder
    private func destination(_ row: Row) -> some View {
        switch row {
        case .accessProfile:
            AccessibilityProfileEditView(current: session.accessFeatures)

        case .profileEdit:
            ProfileEditView()

        // 준비 중 안내는 앱의 기존 틀을 그대로 쓴다 — "{이름}은 준비 중이에요" 한 줄.
        case .myPosts:
            MyPostsView()
        case .accessibility:
            AccessibilitySettingsView()
        case .helpCenter:
            comingSoon("고객센터", "questionmark.circle", "고객센터는 준비 중이에요")
        case .terms:
            comingSoon("서비스 이용약관", "doc.text", "서비스 이용약관은 준비 중이에요")
        }
    }

    private func comingSoon(_ title: String, _ symbol: String, _ message: String) -> some View {
        ComingSoonView(title: title, systemImage: symbol, message: message)
            .background(.white)
    }
}

// MARK: - 줄 하나

/// 설정 화면의 줄. 시안 값: 폭 321(좌우 36), 높이 65(부제+컨트롤이 있으면 85),
/// 제목 Medium 16(-0.4), 부제 Regular 14(-0.056), 아래 1pt `#F2F2F2` 보더.
///
/// `List`/`Form` 을 쓰지 않는 이유: 이 앱의 줄은 시스템 기본과 다른 폭·높이·구분선 색을 쓰고,
/// 다른 화면들도 같은 방식으로 손으로 그린다. 한 화면만 시스템 컨테이너로 두면 여백과 구분선이
/// 앱 안에서 두 종류가 된다. 다만 스위치는 시스템 `Toggle` 그대로다 —
/// 그것을 직접 그리면 손쉬운 사용·다크 모드·동작 축소를 모두 잃는다.
private struct SettingsRow<Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var isTitleBold = false
    var height: CGFloat = 65
    var showsDivider = true
    /// 오른쪽에 붙는 것. 없으면 화살표(>)가 붙고 줄 전체가 버튼이 된다.
    @ViewBuilder var accessory: () -> Accessory
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsDivider {
                Rectangle().fill(Color.photoPlaceholder).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.notoSans(16, isTitleBold ? .bold : .medium, relativeTo: .headline))
                    .tracking(-0.4)
                if let subtitle {
                    Text(subtitle)
                        .font(.notoSans(14, relativeTo: .subheadline))
                        .tracking(-0.056)
                }
            }
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory()
        }
        .frame(minHeight: height)
        .contentShape(Rectangle())
    }
}

/// 줄 끝 화살표. 시안은 5×11 의 얇은 꺾쇠다.
private struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.textSecondary)
    }
}

extension SettingsRow where Accessory == SettingsChevron {
    /// 화살표로 끝나는 보통 줄.
    init(
        title: String,
        subtitle: String? = nil,
        isTitleBold: Bool = false,
        height: CGFloat = 65,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isTitleBold: isTitleBold,
            height: height,
            showsDivider: showsDivider,
            accessory: { SettingsChevron() },
            action: action
        )
    }
}

extension SettingsRow {
    /// 오른쪽에 컨트롤(스위치 등)이 오는 줄. 줄 전체를 버튼으로 만들지 않는다 —
    /// 스위치가 이미 두드릴 대상이라, 줄까지 버튼이면 무엇을 눌렀는지 알 수 없다.
    init(
        title: String,
        subtitle: String? = nil,
        height: CGFloat = 65,
        showsDivider: Bool = true,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isTitleBold: false,
            height: height,
            showsDivider: showsDivider,
            accessory: accessory,
            action: nil
        )
    }
}

#Preview("설정 — 로그인") {
    NavigationStack {
        AccountSettingsView()
            .environment(SessionStore(service: MockAuthService()))
    }
}
