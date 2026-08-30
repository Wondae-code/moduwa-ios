import SwiftUI

/// 마이페이지 — 홈 헤더의 햄버거에서 오른쪽에서 밀려 나오는 서랍
/// (시안 821:103 "05. 마이페이지 - 로그인시").
///
/// **`fullScreenCover` 로 띄우지 않는다.** 시트·전체화면은 아래에서 위로 올라오는 전환이
/// 붙어 있어서, 안에서 패널을 오른쪽에서 밀어 넣어도 창 전체가 아래에서 올라오는 것으로
/// 읽힌다(실기기 확인). `RootView` 가 이 뷰를 오버레이로 얹고
/// (`AccountDrawerPresenter`), 어두워지는 배경과 패널이 각각 자기 전환을 갖는다.
///
/// 예전 판은 아래에서 올라오는 시트 하나에 계정·로그아웃·무장애 프로필을 모두 담았다.
/// 새 시안은 **서랍(295pt) + 메뉴 목록**이고, 각 줄이 자기 화면으로 들어간다.
/// 시안 값: 검은 오버레이 75%, 흰 패널 295, 아바타 100(라임 30%), 닉네임 24 Bold,
/// 메뉴 줄 높이 70·글자 18 Medium, 구분선 6pt `#F2F2F2`.
///
/// **로그아웃은 시안에 없다.** 어느 줄에도 없고 "비로그인시" 화면도 없어서, 계정 자체를
/// 다루는 줄인 **"회원정보 수정"** 안에 두었다(`AccountInfoView`) — 이메일 인증·비밀번호
/// 변경과 같은 자리가 맞고, 서랍 첫 화면에 파괴적이지 않은 동작을 하나만 튀게 둘 이유가 없다.
struct AccountDrawerView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accountDrawer) private var drawer

    /// 서랍의 각 줄이 여는 화면.
    private enum Row: Hashable, Identifiable {
        case accessProfile, accountInfo, myPosts, accessibility, settings, guide
        case helpCenter, terms, profileEdit

        var id: Self { self }
    }

    /// 회원정보 수정 **안에서** 이어지는 화면들. 목적지 안의 스택이 쥔다.
    private enum SubRoute: Hashable { case verifyEmail, resetPassword }

    @State private var row: Row?
    @State private var subPath: [SubRoute] = []

    static let panelWidth: CGFloat = 295
    private static let rowInset: CGFloat = 24

    var body: some View {
        // ⚠️ 서랍을 `NavigationStack` 으로 감싸지 않는다. 스택은 **자기 배경(시스템 배경색)을
        //  깔기 때문에** 어두워지는 층 아래가 그 흰 배경이 되어 뒤의 앱이 보이지 않는다
        //  (실측: 왼쪽이 균일한 회색). iOS 18 의 `containerBackground(for: .navigation)` 으로
        //  지울 수 있지만 이 앱의 최소 버전은 17 이다.
        //
        //  그래서 서랍은 어두운 배경 + 패널뿐이고, 각 줄이 여는 화면은 **전체화면으로 따로**
        //  띄운다. 서랍은 그 뒤에 남아 있어 닫으면 제자리로 돌아온다.
        drawerBody
            .fullScreenCover(item: $row) { row in
                destination(row)
            }
    }

    // MARK: - 서랍

    private var drawerBody: some View {
        ZStack(alignment: .trailing) {
            // 배경은 서서히 어두워지고 패널은 오른쪽에서 들어온다.
            Color.black
                .opacity(drawer.isPresented ? 0.75 : 0)
                .ignoresSafeArea()
                .onTapGesture { drawer.close() }
                .accessibilityLabel("닫기")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { drawer.close() }

            // **삽입 전환(`.transition`)이 아니라 오프셋으로 민다.** 전환은 뷰가 계층에
            //  들어오고 나가는 순간에만 붙고, 그 순간을 놓치면(상위에서 애니메이션 없이
            //  값이 바뀌면) 아무 움직임 없이 툭 나타난다. 오프셋은 값이 변하기만 하면
            //  언제나 따라 움직인다 — 서랍은 열고 닫는 방향이 보여야 서랍이다.
            panel
                .frame(width: Self.panelWidth)
                .background(Color.white.ignoresSafeArea())
                .offset(x: drawer.isPresented ? 0 : Self.panelWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Button { drawer.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Self.rowInset - 10)
            .accessibilityLabel("마이페이지 닫기")

            ScrollView {
                VStack(spacing: 0) {
                    if let account = session.account {
                        header(nickname: account.nickname)
                    } else {
                        signedOutHeader
                    }

                    accessProfileRow

                    thickDivider

                    menu

                    thickDivider
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
    }

    // MARK: - 머리

    private func header(nickname: String) -> some View {
        VStack(spacing: 0) {
            avatar

            Text(nickname)
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .foregroundStyle(.textSecondary)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            Button { row = .profileEdit } label: {
                Text("프로필 편집")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    /// 시안에 "비로그인시" 화면이 없다. 계정이 없으면 아바타 자리에 로그인으로 가는 길만 둔다 —
    /// 무엇이 계정을 필요로 하는지 설명하는 줄은 두지 않는다. 여기서 읽어야 하는 것은
    /// "로그인이 어디 있나" 하나뿐이고, 나머지는 각 기능이 막힐 때 그 자리에서 말해 준다.
    private var signedOutHeader: some View {
        VStack(spacing: 0) {
            avatar

            Text("로그인이 필요해요")
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .foregroundStyle(.textSecondary)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            AuthPrimaryButton(title: "로그인") { startSignIn() }
                .padding(.top, 20)
                .padding(.horizontal, Self.rowInset)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var avatar: some View {
        Circle()
            .fill(Color.moduwaGreen.opacity(0.3))
            .frame(width: 100, height: 100)
            .accessibilityHidden(true)
    }

    // MARK: - 줄

    /// "내 무장애정보 편집" — 시안 873:2138. 아이콘은 지금 고른 항목의 픽토그램을 쓴다
    /// (없으면 시안과 같은 지체장애). 서랍에서 무엇이 저장돼 있는지 한눈에 보이게 하려고.
    private var accessProfileRow: some View {
        let feature = session.accessFeatures.first ?? .wheelchairAccessible
        let size = feature.iconSize(height: 22)
        return DrawerRow(title: "내 무장애정보 편집", showsDivider: false) {
            row = .accessProfile
        } leading: {
            Circle()
                .fill(Color.deepGreen)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(feature.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .foregroundStyle(.white)
                }
        }
        .padding(.horizontal, Self.rowInset)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            if session.account != nil {
                DrawerRow(title: "회원정보 수정") { row = .accountInfo }
                DrawerRow(title: "내 게시글") { row = .myPosts }
            }
            DrawerRow(title: "접근성") { row = .accessibility }
            DrawerRow(title: "설정") { row = .settings }
            DrawerRow(title: "이용 가이드", showsDivider: false) { row = .guide }
        }
        .padding(.horizontal, Self.rowInset)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerLink("고객센터") { row = .helpCenter }
            footerLink("서비스 약관") { row = .terms }
        }
        .padding(.bottom, Spacing.s)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 시안의 6pt `#F2F2F2` 띠 — 서랍의 세 덩어리(내 정보 / 메뉴 / 바깥 링크)를 나눈다.
    private var thickDivider: some View {
        Rectangle()
            .fill(Color.photoPlaceholder)
            .frame(height: 6)
            .accessibilityHidden(true)
    }

    // MARK: - 목적지

    /// 줄 하나가 여는 전체화면. 자기 `NavigationStack` 을 갖는다 — 화면 제목과 "회원정보 수정
    /// → 이메일 인증" 같은 안쪽 이동이 여기서 일어난다. 서랍은 이 화면 뒤에 그대로 남는다.
    private func destination(_ row: Row) -> some View {
        NavigationStack(path: $subPath) {
            rowScreen(row)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { closeDestination() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                        }
                        .accessibilityLabel("마이페이지로 돌아가기")
                    }
                }
                .navigationDestination(for: SubRoute.self) { subScreen($0) }
        }
    }

    @ViewBuilder
    private func rowScreen(_ row: Row) -> some View {
        switch row {
        case .accessProfile:
            AccessibilityProfileEditView(current: session.accessFeatures)

        case .accountInfo:
            // 로그아웃이 여기 있다. 이 화면과 서랍을 함께 닫아야 로그아웃 뒤에 남은 화면이
            //  어긋나지 않는다.
            AccountInfoView(
                onSignedOut: { closeDestination(); drawer.close() },
                onVerifyEmail: { subPath.append(.verifyEmail) },
                onChangePassword: { subPath.append(.resetPassword) }
            )

        // 준비 중 안내는 앱의 기존 틀을 그대로 쓴다 — "{이름}은 준비 중이에요" 한 줄
        //  (`ScheduleView`·`PlaceReviewsView` 와 같은 문장 모양). 여기에만 사연을 덧붙이면
        //  같은 안내가 화면마다 다른 말로 읽힌다.
        case .profileEdit:
            comingSoon("프로필 편집", "person.crop.circle", "프로필 편집은 준비 중이에요")
        case .myPosts:
            comingSoon("내 게시글", "square.text.square", "내 게시글은 준비 중이에요")
        case .accessibility:
            AccessibilitySettingsView()
        case .settings:
            comingSoon("설정", "gearshape", "설정은 준비 중이에요")
        case .guide:
            comingSoon("이용 가이드", "book", "이용 가이드는 준비 중이에요")
        case .helpCenter:
            comingSoon("고객센터", "questionmark.circle", "고객센터는 준비 중이에요")
        case .terms:
            comingSoon("서비스 약관", "doc.text", "서비스 약관은 준비 중이에요")
        }
    }

    @ViewBuilder
    private func subScreen(_ route: SubRoute) -> some View {
        switch route {
        case .verifyEmail:
            EmailVerifyCodeView { subPath.removeAll() }
        case .resetPassword:
            PasswordResetView { _ in
                // 서버가 모든 세션을 끊었다 — 이 기기도 로그아웃 상태다.
                closeDestination()
                drawer.close()
            }
        }
    }

    /// 목적지를 닫는다. 안쪽 경로도 비워야 다음에 열 때 이전 화면이 남아 있지 않다.
    private func closeDestination() {
        subPath.removeAll()
        row = nil
    }

    private func comingSoon(_ title: String, _ symbol: String, _ message: String) -> some View {
        ComingSoonView(title: title, systemImage: symbol, message: message)
            .background(.white)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    /// 로그인은 **서랍 안에서 열지 않는다.** 시트 안에 또 시트를 띄우면 이 코드베이스에서
    /// 버튼 동작을 잃은 적이 있고, 로그인 흐름은 이미 `RootView` 가 `session.prompt` 로
    /// 띄우는 시트 하나에 모여 있다. 서랍을 닫고 그 하나를 깨운다.
    private func startSignIn() {
        session.prompt = .direct
        drawer.close()
    }
}

/// 서랍의 메뉴 한 줄 (시안 873:2101 — 높이 70, 글자 18 Medium, 아래 1pt 보더).
private struct DrawerRow<Leading: View>: View {
    let title: String
    var showsDivider = true
    let action: () -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    leading()
                    Text(title)
                        .font(.notoSans(18, .medium, relativeTo: .headline))
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                }
                .frame(minHeight: 70)

                if showsDivider {
                    Rectangle().fill(Color.cardStroke).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension DrawerRow where Leading == EmptyView {
    init(title: String, showsDivider: Bool = true, action: @escaping () -> Void) {
        self.init(title: title, showsDivider: showsDivider, action: action) { EmptyView() }
    }
}

#Preview("마이페이지 — 로그인시") {
    ZStack {
        Color.gray
        AccountDrawerView()
            .environment(SessionStore(service: MockAuthService()))
    }
}
