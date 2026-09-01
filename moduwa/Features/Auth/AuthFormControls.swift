import AuthenticationServices
import SwiftUI

/// 온보딩·로그인·가입 화면이 공유하는 입력·버튼·오류 줄.
///
/// 피그마 "모두와 UI — 온보딩, 로그인" 페이지(868:150, 2026-08-24) 기준으로 다시 그렸다.
/// 이전 판은 앱의 다른 시트(회색 입력 상자, 라임 캡슐)를 따라갔는데, 새 시안은 로그인 계열만
/// **흰 입력 상자 + 1pt 보더 + radius 18** 로 따로 정의한다 — 값은 시안 그대로 둔다.
///
/// 시안 값 요약:
/// - 입력칸 `321×47`, radius 18, 보더 기본 `#E6E6E6` 1 / 포커스 `#A7E100` 1.5 / 오류 `#BF1414` 1
/// - 주 버튼 `320×51`, radius 18, 활성 `#A7E100`·글자 `#0B2A1C` / 비활성 `#E6E6E6`·글자 `#B3B3B3`
/// - 온보딩 버튼만 캡슐(radius 999)이다
/// - 좌우 여백 36 (앱의 다른 화면은 24 — 이 계열만 시안이 36으로 잡혀 있다)

/// 로그인 계열 화면의 좌우 여백. 시안의 입력칸 x=36, 폭 321(=393-72)에서 온 값.
enum AuthMetrics {
    static let horizontal: CGFloat = 36
    static let fieldHeight: CGFloat = 47
    static let buttonHeight: CGFloat = 51
}

// MARK: - 입력

/// 한 줄 입력. 라벨을 **위에 따로 둔다** — placeholder 만 두면 글자를 넣는 순간 무엇을 넣는
/// 칸인지 사라지고, 스크린리더도 값만 읽는다.
///
/// 보더가 세 가지 상태를 갖는다(시안 868:353 / 868:566 / 868:405). 포커스는 라임, 오류는
/// 빨강이다 — **색만으로 알리지 않는다**: 오류일 때는 칸 아래 문장이 함께 나오고, 그 문장이
/// 스크린리더의 `accessibilityValue` 에도 실린다.
struct AuthField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String

    /// 비밀번호 칸인지. `SecureField` 로 바뀌고 눈 토글이 붙는다.
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    /// iOS 자동완성·키체인 연동. 이메일은 `.username`, 비밀번호는 `.password`/`.newPassword`.
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .next
    /// 칸 아래 빨간 한 줄. 있으면 보더도 빨강이 된다.
    var errorMessage: String?
    /// 이 칸에만 붙일 문장은 없지만 **보더는 빨갛게** 해야 하는 경우.
    /// 로그인은 서버가 어느 쪽이 틀렸는지 알려 주지 않아 두 칸을 함께 표시하고 이유는
    /// 버튼 위에 한 줄로 둔다(시안 868:751).
    var hasError = false
    /// 입력이 규칙을 통과했는지. `nil` 이면 체크 표시를 아예 그리지 않는다
    /// (시안 868:623 — 빈 칸에는 체크가 없다).
    var isValid: Bool?
    var onSubmit: (() -> Void)?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    /// 빨간 보더를 칠할지. **빈 칸은 아직 틀린 것이 아니다** — 시안(868:623)은 빈 가입 화면에도
    /// 비밀번호 규칙 문장을 띄우는데, 그 문장 때문에 손대지도 않은 칸이 오류처럼 보이면 안 된다.
    /// 문장은 그대로 두고(규칙 안내), 색은 입력이 들어온 뒤에 바뀐다.
    private var isErrored: Bool {
        !text.isEmpty && (hasError || !(errorMessage ?? "").isEmpty)
    }

    private var borderColor: Color {
        if isErrored { return .errorRed }
        return isFocused ? .moduwaGreen : .cardStroke
    }

    private var borderWidth: CGFloat {
        isErrored ? 1 : (isFocused ? 1.5 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.notoSans(14, relativeTo: .subheadline))
                .foregroundStyle(.textPrimary)

            HStack(spacing: 6) {
                field
                    .font(.notoSans(16, relativeTo: .body))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }

                if let isValid, !text.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isValid ? Color.deepGreen : Color.iconGray)
                        .accessibilityHidden(true)
                }

                if isSecure {
                    Button {
                        // 애니메이션을 끊는다 — SecureField ↔ TextField 교체는 상위 트랜잭션을
                        //  물려받으면 칸 전체가 한 번 출렁인다.
                        withoutAnimation { isRevealed.toggle() }
                    } label: {
                        Image(systemName: isRevealed ? "eye" : "eye.slash")
                            .font(.system(size: 16))
                            .foregroundStyle(.iconGray)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .padding(.leading, 17)
            .padding(.trailing, 16)
            .frame(minHeight: AuthMetrics.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(.white)
                    .shadow(color: Color.deepGreen.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(borderColor, lineWidth: borderWidth)
            )

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.notoSans(12, relativeTo: .caption))
                    // 아직 입력이 없으면 오류가 아니라 규칙 안내다.
                    .foregroundStyle(isErrored ? Color.errorRed : Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 2)
                    // 칸의 값과 함께 읽히게 한다 — 따로 두면 포커스가 칸에 있는 동안은 안 읽힌다.
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(errorMessage ?? "")
    }

    @ViewBuilder
    private var field: some View {
        if isSecure, !isRevealed {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}

/// "로그인 상태 유지" 같은 체크박스 한 줄 (시안 868:773 — 15×15, radius 3).
///
/// 선택을 **색만으로 전달하지 않는다** — 체크 글리프가 함께 들어온다.
struct AuthCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withoutAnimation { isOn.toggle() }
        } label: {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isOn ? Color.moduwaGreen : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isOn ? Color.moduwaGreen : Color.iconGray, lineWidth: 1)
                    )
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 15, height: 15)

                Text(title)
                    .font(.notoSans(12, relativeTo: .caption))
                    .foregroundStyle(.textSecondary)
            }
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 버튼

/// 주 CTA. 시안이 두 모양을 쓴다 — 로그인 계열은 radius 18, 온보딩은 캡슐.
struct AuthPrimaryButton: View {
    /// 시안의 두 모서리. 기본값은 로그인 계열(radius 18)이다.
    enum Shape { case rounded, capsule }

    let title: String
    var isEnabled = true
    var isBusy = false
    var shape: Shape = .rounded
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.notoSans(16, .bold, relativeTo: .headline))
                    .foregroundStyle(isEnabled ? Color.textPrimary : Color.iconGray)
                    .opacity(isBusy ? 0 : 1)
                if isBusy { ProgressView().tint(.textPrimary) }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AuthMetrics.buttonHeight)
            .background(background)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .accessibilityLabel(isBusy ? "\(title) 진행 중" : title)
    }

    @ViewBuilder
    private var background: some View {
        let fill = isEnabled ? Color.moduwaGreen : Color.cardStroke
        switch shape {
        case .rounded: RoundedRectangle(cornerRadius: Radius.card).fill(fill)
        case .capsule: Capsule().fill(fill)
        }
    }
}

/// 보조 CTA — 흰 배경 + 딥그린 보더 (시안 868:783 "둘러보기").
struct AuthSecondaryButton: View {
    let title: String
    var shape: AuthPrimaryButton.Shape = .capsule
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AuthMetrics.buttonHeight)
                .background(border)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var border: some View {
        switch shape {
        case .rounded:
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.deepGreen, lineWidth: 1))
        case .capsule:
            Capsule().fill(.white).overlay(Capsule().stroke(Color.deepGreen, lineWidth: 1))
        }
    }
}

/// 밑줄 링크 한 줄 — "비밀번호를 잊으셨나요?" (시안 868:769).
struct AuthLinkButton: View {
    let title: String
    var size: CGFloat = 12
    var weight: NotoSans = .medium
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.notoSans(size, weight, relativeTo: .caption))
                .foregroundStyle(.textSecondary)
                .underline()
                .frame(minHeight: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 안내 · 오류

/// 폼 전체의 실패 사유 한 줄 (시안 868:771 — 14 Medium, `#BF1414`, 가운데).
///
/// 예전에는 이 줄도 딥그린이었다("앱의 강조색은 초록"). 새 시안이 빨강으로 바꿨고 그 편이
/// 맞다 — 초록 문장은 성공 안내와 구분되지 않는다. 문구는 서버가 준 한국어를 그대로 쓴다.
struct AuthErrorLine: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.errorRed)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// 화면 제목. 시안의 로그인·가입 화면은 제목을 **가운데**에 20 Medium 으로 둔다.
struct AuthTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.notoSans(20, .medium, relativeTo: .title3))
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 제목 + 설명(왼쪽 정렬). 시안에 없는 화면(비밀번호 재설정·무장애 프로필 편집)이 계속 쓴다.
struct AuthHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "아직 계정이 없으신가요? / 회원가입" 처럼 화면 맨 아래에 붙는 안내 + 링크
/// (시안 868:650·868:651).
struct AuthFooterLink: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(message)
                .font(.notoSans(12, relativeTo: .caption))
                .foregroundStyle(.textSecondary)
            Button(action: action) {
                Text(actionTitle)
                    .font(.notoSans(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(.deepGreen)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 인증코드

/// 6자리 인증코드 입력 (시안 868:463 — 40×68 박스 6개, radius 10, 라임 보더 1.5).
/// 틀렸을 때는 보더가 `#BF1414` 1pt 로 바뀐다(시안 868:491).
///
/// **칸을 진짜로 6개 두지 않는다.** 시안의 모양은 그대로 그리지만 실제 입력은 **투명한 한 칸**이
/// 받는다. 무장애 앱에서 쪼갠 칸은 스크린리더가 "편집 중, 1"을 여섯 번 읽고 지우기·붙여넣기가
/// 칸마다 어긋난다. 한 칸이면 iOS 가 메일에서 인증코드를 **자동완성**해 주기도 한다
/// (`.oneTimeCode`) — 이게 숫자 코드를 고른 이유의 절반이다.
struct CodeField: View {
    @Binding var code: String
    /// 방금 넣은 코드가 틀렸다. 보더만 바꾼다 — 문장은 화면이 박스 위에 따로 둔다(시안).
    var hasError = false
    var onSubmit: (() -> Void)?

    static let length = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<Self.length, id: \.self) { index in
                    box(digit: digit(at: index))
                }
            }
            .accessibilityHidden(true)

            // 실제 입력을 받는 칸. 보이지 않지만 **자리를 차지한다** — 자리가 없으면
            //  탭이 박스에 닿지 않고, VoiceOver 도 이 요소를 찾지 못한다.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(height: 68)
                .contentShape(Rectangle())
                .onChange(of: code) {
                    // 숫자만, 6자리까지. 붙여넣기로 들어오는 공백·하이픈까지 걸러 낸다.
                    let digits = code.filter(\.isNumber)
                    let capped = String(digits.prefix(Self.length))
                    if capped != code { code = capped }
                    if capped.count == Self.length { onSubmit?() }
                }
                .onAppear { isFocused = true }
                .accessibilityLabel("인증코드 6자리")
                .accessibilityValue(
                    code.isEmpty ? "입력하지 않음" : code.map(String.init).joined(separator: " "))
        }
        .frame(maxWidth: .infinity)
    }

    private func digit(at index: Int) -> String? {
        guard index < code.count else { return nil }
        return String(Array(code)[index])
    }

    private func box(digit: String?) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(hasError ? Color.errorRed : Color.moduwaGreen, lineWidth: hasError ? 1 : 1.5)
            .frame(width: 40, height: 68)
            .overlay {
                if let digit {
                    Text(digit)
                        .font(.notoSans(30, .regular, relativeTo: .largeTitle))
                        .foregroundStyle(.textPrimary)
                }
            }
    }
}

/// 인증 화면의 오류 한 줄 (시안 868:527 "exclamanation message" — ⓘ 24pt + 12 Medium `#BF1414`).
///
/// 아이콘은 시안이 vuesax info-circle 을 쓰지만 이 앱은 같은 성격의 글리프를 SF Symbol 로
/// 통일해 왔다(`AccountInfoView` 의 인증 상태 표시와 같은 규칙).
struct AuthInlineError: View {
    let message: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.errorRed)
            Text(message)
                .font(.notoSans(12, .medium, relativeTo: .caption))
                .foregroundStyle(.errorRed)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }
}

/// 회색 알약 토스트 (시안 868:536 "Resend Toast Message" — `#B3B3B3`, radius 10, 흰 12 Medium).
struct AuthToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.notoSans(12, .medium, relativeTo: .caption))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.iconGray))
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - 소셜 로그인

/// 소셜 로그인 버튼 묶음 — 시안 868:645 "00. 로그인" 의 아래쪽 세 줄.
///
/// **애플 버튼이 맨 위에 있다**(2026-09-01 추가). 제3자 소셜 로그인을 제공하는 앱은 애플
/// 로그인도 함께 제공해야 한다(심사 규칙 4.8) — 없으면 리젝된다. 유료 멤버십이 생겨
/// 엔타이틀먼트를 켤 수 있게 되면서 막고 있던 이유가 사라졌다.
///
/// ⚠️ 애플 버튼은 **애플이 주는 컴포넌트**(`SignInWithAppleButton`)를 그대로 쓴다. 다른 버튼처럼
/// 직접 그리면 브랜드 지침 위반이고, 지침은 "다른 로그인 수단보다 덜 눈에 띄게 두지 말라"고
/// 요구한다 — 그래서 높이를 다른 버튼과 같게 맞추고 맨 위에 둔다.
struct SocialSignInSection: View {
    var isBusy = false
    var onGoogle: () -> Void
    var onKakao: () -> Void
    /// 애플 버튼이 준 결과. 파싱은 `AppleSignInFlow` 가 한다.
    var onApple: (Result<ASAuthorization, Error>) -> Void

    /// 구글·카카오는 클라이언트 ID 가 없으면 버튼을 그리지 않는다 — 눌러야 실패를 아는
    /// 버튼보다 없는 편이 정직하다. **애플은 앱 키가 필요 없어 늘 그린다**(엔타이틀먼트만 있으면 된다).
    var body: some View {
            VStack(spacing: 10) {
                divider

                // 애플 버튼. `.signInWithAppleButtonStyle(.black)` 은 시안의 어두운 CTA 톤과
                //  맞고, 흰 배경에서 대비도 가장 높다.
                SignInWithAppleButton(.signIn) { request in
                    // 이름·이메일을 요청한다. **이름은 첫 로그인에만** 돌아온다.
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    onApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: AuthMetrics.buttonHeight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .disabled(isBusy)
                .accessibilityLabel("Apple로 시작하기")

                if GoogleSignInFlow.isConfigured {
                    // 라벨은 **화면에 적힌 그대로** 둔다 — 보이는 말과 VoiceOver 가 읽는 말이
                    //  다르면(예전엔 "계속하기"였다) 같은 버튼을 두 이름으로 배우게 된다.
                    socialButton(fill: .white, hasBorder: true, action: onGoogle,
                                 label: "Google로 시작하기") {
                        // 구글 공식 브랜드 에셋. **원본 색을 유지해야 한다** —
                        //  template 로 렌더링해 단색으로 만들면 브랜드 가이드라인 위반이다.
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Google로 시작하기")
                    }
                }

                if KakaoSignInFlow.isConfigured {
                    socialButton(fill: Color(hex: 0xFEE500), hasBorder: false, action: onKakao,
                                 label: "카카오로 시작하기") {
                        Image("kakao_symbol")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 17)
                        Text("카카오로 시작하기")
                    }
                }
            }
    }

    private var divider: some View {
        HStack(spacing: 16) {
            line
            Text("또는")
                .font(.notoSans(12, relativeTo: .caption))
                .foregroundStyle(Color.textSecondary.opacity(0.5))
            line
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle().fill(Color.cardStroke).frame(height: 1)
    }

    /// 시안의 소셜 버튼: 322×51~54, radius 18, 아이콘과 글자 사이 15.
    private func socialButton<Content: View>(
        fill: Color, hasBorder: Bool, action: @escaping () -> Void, label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                content()
            }
            .font(.notoSans(16, .medium, relativeTo: .headline))
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AuthMetrics.buttonHeight)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(fill))
            .overlay {
                if hasBorder {
                    RoundedRectangle(cornerRadius: Radius.card)
                        .stroke(Color.cardStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(label)
    }
}

// MARK: - 공통 크롬

/// 온보딩·로그인 화면 오른쪽 위의 작은 로고 (시안 47×31.2, top 47).
struct AuthBrandMark: View {
    var body: some View {
        Image("logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 47, height: 31.2)
            .foregroundStyle(.deepGreen)
            .accessibilityHidden(true)
    }
}

/// 시트 위쪽의 얇은 구분선 — 다른 시트와 같은 헤더 처리.
struct AuthSheetTopBar: View {
    var body: some View {
        Color.clear
            .frame(height: 22)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityHidden(true)
    }
}
