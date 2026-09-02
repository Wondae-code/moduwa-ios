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
    /// iOS 설정에서 알림을 바꾸고 돌아오는 경우가 있어 포그라운드 복귀를 본다.
    @Environment(\.scenePhase) private var scenePhase

    /// 줄 하나가 미는 화면.
    private enum Row: Hashable, Identifiable {
        case accessProfile, profileEdit, myPosts, blockedUsers, accessibility, helpCenter, terms

        var id: Self { self }
    }

    @State private var row: Row?

    /// 앱 푸시 알림 허용(시안 978:1163). 실제 등록·해제는 `PushRegistrar` 가 한다.
    ///
    /// **토글이 보는 값은 앱 선호와 시스템 권한의 AND 다**(`isOn`) — iOS 설정에서 껐는데
    /// 앱 토글만 켜져 있으면 "켰는데 안 온다" 가 된다. 켜는 순간이 권한을 물어볼 자리다.
    @State private var push = PushRegistrar.shared
    /// 시스템 권한이 거절 상태여서 앱에서 되돌릴 수 없다 — iOS 설정으로 보내는 안내.
    @State private var isShowingSystemSettingsNotice = false

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
        // 사용자가 iOS 설정에서 알림을 껐다 켰을 수 있다 — 앱에 통보되지 않아 직접 확인한다.
        .task { await push.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await push.refresh() } }
        }
        .onChange(of: push.needsSystemSettings) { _, needs in
            if needs { isShowingSystemSettingsNotice = true }
        }
        .alert("알림이 꺼져 있어요", isPresented: $isShowingSystemSettingsNotice) {
            // 앱에서 시스템 권한을 되돌릴 수는 없다 — 설정으로 보내는 것이 전부다.
            Button("설정 열기") {
                push.needsSystemSettings = false
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("나중에", role: .cancel) { push.needsSystemSettings = false }
        } message: {
            Text("iOS 설정 → 모두와 → 알림에서 허용해 주세요. 앱에서는 켤 수 없어요.")
        }
    }

    /// 토글을 실제 등록·해제로 잇는다. 값을 그냥 저장하면 스위치만 움직이고 알림은 그대로다.
    private var pushBinding: Binding<Bool> {
        Binding(get: { push.isOn },
                set: { on in Task { on ? await push.turnOn() : await push.turnOff() } })
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

            // 시안(983:1192·983:1191): **이름은 화면 가운데**, 연필은 그 오른쪽이다.
            //  연필을 이름과 한 줄에 그냥 이어 붙이면 둘의 합이 가운데로 잡혀 이름이 왼쪽으로
            //  밀린다. 반대편에 같은 크기의 빈 자리를 두어 이름의 중심을 화면 중심에 맞춘다.
            HStack(spacing: 6) {
                if session.account != nil {
                    // ⚠️ `EmptyView` 는 크기를 줘도 자리를 차지하지 않는다(레이아웃에서 없는
                    //  것으로 취급된다 — 실측: 이름이 연필 폭의 절반만큼 왼쪽으로 밀렸다).
                    //  `Color.clear` 는 실제로 자리를 잡는다.
                    pencilSlot { Color.clear }
                }

                Text(session.account?.nickname ?? "로그인이 필요해요")
                    .font(.notoSans(20, .bold, relativeTo: .title3))
                    .tracking(-0.08)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                // 시안의 연필 = 프로필 편집(사진·닉네임). 계정을 다루는 화면(회원정보·인증·
                //  로그아웃)은 그 화면 안에서 이어진다 — 설정 시안 다섯 줄에 자리가 없다.
                if session.account != nil {
                    Button { row = .profileEdit } label: {
                        pencilSlot {
                            Image("detail_pencil")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                                .foregroundStyle(.textSecondary)
                        }
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

    /// 연필이 앉는 자리. 이름 반대편에 **같은 크기**의 빈 자리를 두어 이름을 화면 가운데로
    /// 맞추는 데도 쓴다(시안 983:1191 의 38×38).
    private func pencilSlot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: 38, height: 38)
            .contentShape(Rectangle())
    }

    /// 라임 원 100 + 우하단 딥그린 뱃지. 뱃지의 픽토그램은 **지금 고른 무장애 항목**이다 —
    /// 무엇이 저장돼 있는지 프로필에서 바로 보이게 한다(고른 것이 없으면 시안과 같은 지체장애).
    private var avatar: some View {
        let feature = session.accessFeatures.first ?? .wheelchairAccessible
        let size = feature.iconSize(height: 19)
        // 사진이 없으면 **닉네임 첫 글자**를 그린다 — 남이 보는 자리(게시글·후기)와 같은
        //  규칙이라, 사진을 안 올린 사람이 자리마다 다른 얼굴로 보이지 않는다.
        //  원 색은 시안(983:1302)의 라임을 유지하고, 밝은 배경이라 글자는 딥그린이다.
        //  이름을 모르는 비로그인에서는 이니셜 없이 원만 남긴다.
        return AuthorAvatar(
            name: session.account?.nickname ?? "",
            avatarURL: session.account?.avatarURL,
            diameter: 100,
            fontSize: 36,
            background: Color.moduwaGreen.opacity(0.3),
            foreground: .deepGreen,
            showsInitial: session.account != nil
        )
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
                Toggle("", isOn: pushBinding)
                    .labelsHidden()
                    .tint(.moduwaGreen)
                    .accessibilityLabel("앱 푸시 알림 허용")
                    .accessibilityHint("내 글에 달린 좋아요·댓글과 플랜 합류를 알려 줍니다")
            }

            if session.account != nil {
                SettingsRow(title: "내 게시글") { row = .myPosts }
                // 차단은 **해제할 길이 함께 있어야** 성립한다(심사 1.2 도 그렇게 본다).
                SettingsRow(title: "차단한 사용자") { row = .blockedUsers }
            }
            SettingsRow(title: "접근성") { row = .accessibility }
            SettingsRow(title: "고객센터") { row = .helpCenter }
            SettingsRow(title: "서비스 이용약관", showsDivider: false) { row = .terms }

            dataSource
        }
        .padding(.horizontal, Self.rowInset)
        .padding(.bottom, Spacing.xxl)
    }

    /// 데이터 출처. **표시 의무다** — 관광공사 TourAPI 는 표출 시 출처 표시를 요구하고,
    /// 앱스토어 심사(5.2.1)도 콘텐츠에 대한 권리를 본다. 약관 제11조에만 적고 화면에
    /// 없으면 지킨 것이 아니다.
    ///
    /// 자리를 설정 맨 아래로 둔 이유: 데이터가 여러 화면(홈·장소·플랜)에 흩어져 있어
    /// 화면마다 붙이면 같은 문장이 다섯 번 나온다. 장소 상세에도 한 줄 둔다(그 화면이
    /// 원본 데이터를 가장 많이 그린다).
    private var dataSource: some View {
        Text("관광 정보 출처: 한국관광공사 TourAPI")
            .font(.notoSans(12, .regular, relativeTo: .caption))
            .foregroundStyle(.iconGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.l)
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
        case .blockedUsers:
            BlockedUsersView()
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
