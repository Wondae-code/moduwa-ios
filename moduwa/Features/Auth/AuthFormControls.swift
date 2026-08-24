import SwiftUI

/// 로그인·가입 화면이 공유하는 입력·버튼·오류 줄.
///
/// 앱의 다른 시트(`PlanTitleEditView` 등)와 같은 틀을 쓴다 — 흰 배경, 좌우 24,
/// 회색 입력 상자, 라임 캡슐 CTA, 실패 사유는 버튼 위에. 로그인만 다른 생김새를 갖게 되면
/// 사용자에게는 다른 앱처럼 보인다.

/// 한 줄 입력. 라벨을 **위에 따로 둔다** — placeholder 만 두면 글자를 넣는 순간 무엇을 넣는
/// 칸인지 사라지고, 스크린리더도 값만 읽는다.
struct AuthField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String

    /// 비밀번호 칸인지. `SecureField` 로 바뀌고 "보기" 토글이 붙는다.
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    /// iOS 자동완성·키체인 연동. 이메일은 `.username`, 비밀번호는 `.password`/`.newPassword`.
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)

            HStack(spacing: 8) {
                field
                    .font(.notoSans(15))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }

                if isSecure {
                    Button {
                        // 애니메이션을 끊는다 — SecureField ↔ TextField 교체는 상위 트랜잭션을
                        //  물려받으면 칸 전체가 한 번 출렁인다(`withoutAnimation` 주석 참고).
                        withoutAnimation { isRevealed.toggle() }
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(.iconGray)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
        }
        .accessibilityElement(children: .contain)
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

/// 라임 캡슐 CTA. 진행 중이면 글자를 감추고 스피너를 얹는다(폭이 바뀌지 않게 `ZStack`).
struct AuthPrimaryButton: View {
    let title: String
    var isEnabled = true
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.notoSans(16, .bold))
                    .foregroundStyle(isEnabled ? .textPrimary : .textSecondary)
                    .opacity(isBusy ? 0 : 1)
                if isBusy { ProgressView().tint(.textPrimary) }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Capsule().fill(isEnabled ? Color.moduwaGreen : Color.photoPlaceholder))
            .shadow(color: Color(hex: 0x9ACA10).opacity(isEnabled ? 0.3 : 0), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .accessibilityLabel(isBusy ? "\(title) 진행 중" : title)
    }
}

/// 실패 사유 한 줄. 서버가 준 한국어 문장을 그대로 보여 준다.
///
/// 색을 빨강이 아니라 딥그린으로 두는 것은 앱의 다른 화면과 같은 규칙이다 —
/// 이 앱에서 강조색은 초록이고, 오류만 빨강을 쓰면 그 화면만 낯설어진다.
struct AuthErrorLine: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.notoSans(13))
                .foregroundStyle(.deepGreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// 화면 제목 + 설명. 시트마다 같은 자리에 같은 크기로 둔다.
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

/// 6자리 인증번호 입력.
///
/// **칸을 6개로 쪼개지 않는다.** 시안이 없어 흔한 모양을 따라갈 수도 있었지만, 무장애 앱에서
/// 쪼갠 칸은 스크린리더가 "편집 중, 1" 을 여섯 번 읽고 지우기·붙여넣기가 칸마다 어긋난다.
/// 한 칸에 넣고 자간을 넓히면 눈으로도 여섯 자리가 세어지고, iOS 가 메일에서 인증번호를
/// **자동완성**해 준다(`.oneTimeCode`) — 이게 숫자 코드를 고른 이유의 절반이다.
struct CodeField: View {
    @Binding var code: String
    var onSubmit: (() -> Void)?

    static let length = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $code)
            .font(.notoSans(28, .bold, relativeTo: .title))
            .tracking(12)
            .multilineTextAlignment(.center)
            .foregroundStyle(.textPrimary)
            .tint(.deepGreen)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
            .onChange(of: code) {
                // 숫자만, 6자리까지. 붙여넣기로 들어오는 공백·하이픈까지 걸러 낸다.
                let digits = code.filter(\.isNumber)
                let capped = String(digits.prefix(Self.length))
                if capped != code { code = capped }
                if capped.count == Self.length { onSubmit?() }
            }
            .onAppear { isFocused = true }
            .accessibilityLabel("인증번호 6자리")
            .accessibilityValue(code.isEmpty ? "입력하지 않음" : code.map(String.init).joined(separator: " "))
    }
}

/// "또는" 구분선 + 소셜 버튼. 로그인·가입 화면이 같은 모양을 쓴다.
///
/// **애플 버튼은 없다.** Sign in with Apple 은 애플 개발자 프로그램 유료 멤버십이 있어야
/// 앱에 켤 수 있는 기능이고(엔타이틀먼트), 없는 상태로 버튼만 두면 눌렀을 때
/// `ASAuthorizationError 1000` 으로 죽는다 — 서버 라우트(`POST /v1/auth/apple`)는 이미 있으니
/// 멤버십이 생기면 여기 버튼 하나가 늘어난다.
///
/// ⚠️ **iOS 심사 규칙**: 다른 소셜 로그인을 제공하면 애플 로그인도 함께 제공해야 한다.
/// 지금 상태로 앱스토어에 내면 리젝된다(공모전 제출에는 영향 없음).
struct SocialSignInSection: View {
    var isBusy = false
    var onGoogle: () -> Void
    var onKakao: () -> Void

    var body: some View {
        // 클라이언트 ID 가 없으면 버튼을 아예 그리지 않는다 — 눌러야 실패를 아는 버튼보다,
        //  없는 편이 정직하다.
        if GoogleSignInFlow.isConfigured || KakaoSignInFlow.isConfigured {
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    line
                    Text("또는")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                    line
                }

                if GoogleSignInFlow.isConfigured {
                Button(action: onGoogle) {
                    HStack(spacing: Spacing.s) {
                        // 구글 공식 브랜드 에셋. **원본 색을 유지해야 한다** —
                        //  template 로 렌더링해 단색으로 만들면 브랜드 가이드라인 위반이다
                        //  (그래서 imageset 의 rendering intent 가 original 이다).
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Google로 계속하기")
                            .font(.notoSans(15, .medium))
                            .foregroundStyle(.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(Capsule().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel("Google 계정으로 계속하기")
                }

                if KakaoSignInFlow.isConfigured {
                    Button(action: onKakao) {
                        // 카카오는 **공식 버튼 이미지를 그대로** 쓴다. 구글처럼 심볼만 떼어
                        //  우리 캡슐에 얹고 싶었지만 심볼 단독 에셋이 공개 주소로 없다.
                        //  가이드라인이 요구하는 색·문구·심볼이 이 이미지 안에 다 들어 있다.
                        Image("kakao_login")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .accessibilityLabel("카카오 계정으로 계속하기")
                }
            }
        }
    }

    private var line: some View {
        Rectangle().fill(Color.cardStroke).frame(height: 1)
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
