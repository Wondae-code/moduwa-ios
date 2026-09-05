import SwiftUI

/// 가입 때 받는 동의 세 가지.
///
/// **민감정보를 따로 두는 이유**: 무장애 항목(휠체어·시각·청각·유아·고령자)은 회원의 장애·건강
/// 상태를 드러내는 값이라 개인정보보호법이 정한 **민감정보**다. 민감정보는 다른 개인정보와
/// **구분해 별도로** 동의를 받아야 해서, 개인정보 동의에 묶을 수 없다.
///
/// 그리고 **선택**이다 — 이 값 없이도 앱은 동작한다(온보딩을 건너뛴 사람과 같은 상태가 된다).
/// 필수로 걸면 "동의하지 않으면 가입 불가" 가 되어 강제 동의가 된다.
struct AuthConsent: Hashable, Sendable {
    var terms = false
    var privacy = false
    /// 무장애 항목을 **계정에 저장하는 것**에 대한 동의. 거부하면 가입 요청에 그 값을 싣지 않는다.
    var sensitive = false

    /// 가입에 필요한 최소 조건. 민감정보는 선택이라 여기 들어가지 않는다.
    var hasRequired: Bool { terms && privacy }
}

/// 가입 화면의 동의 영역. 세 줄이 **같은 자리**에 있고 필수·선택이 라벨로 갈린다.
struct AuthConsentSection: View {
    @Binding var consent: AuthConsent
    /// 온보딩에서 고른 무장애 항목이 있는지. **없으면 민감정보 줄을 두지 않는다** —
    /// 저장할 값이 없는데 동의를 묻는 것은 사용자에게 의미 없는 질문이다.
    var hasAccessFeatures: Bool

    @Environment(\.openURL) private var openURL
    @State private var detail: LegalDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ConsentRow(title: "서비스 이용약관 동의", isRequired: true, isOn: $consent.terms) {
                detail = .terms
            }

            // 처리방침은 웹 주소다(앱스토어가 URL 을 요구한다). 주소가 아직 없으면 링크를
            //  걸지 않고 아래 줄로 사실을 알린다 — 없는 주소로 보내면 브라우저 오류가 뜨고,
            //  그것은 방침이 없는 것보다 나쁘게 읽힌다.
            ConsentRow(title: "개인정보 수집·이용 동의", isRequired: true, isOn: $consent.privacy,
                       view: LegalLinks.privacyPolicy.map { url in { openURL(url) } })

            if LegalLinks.privacyPolicy == nil {
                note("개인정보 처리방침 전문은 준비 중이에요. 수집하는 항목은 이용약관 제20조에서 볼 수 있어요.")
            }

            if hasAccessFeatures {
                ConsentRow(title: "민감정보(무장애 정보) 수집·이용 동의",
                           isRequired: false, isOn: $consent.sensitive) { detail = .sensitive }

                note("동의하지 않아도 가입할 수 있어요. 대신 무장애 조건을 반영한 맞춤 추천은 받지 못해요.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .legalDocumentSheet($detail)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(12, relativeTo: .caption))
            .foregroundStyle(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            // 체크박스 글자와 왼쪽을 맞춘다(체크 15 + 간격 5).
            .padding(.leading, 20)
            .padding(.bottom, 6)
    }
}

/// 동의 한 줄 — 체크와 **읽을 길**을 함께 둔다.
///
/// 체크만 두면 무엇에 동의하는지 확인할 방법이 없고, 링크만 두면 동의한 사실이 어디에도
/// 남지 않는다. 둘 중 하나만 있는 동의는 형식이다.
struct ConsentRow: View {
    let title: String
    let isRequired: Bool
    @Binding var isOn: Bool
    /// 전문을 여는 동작. nil 이면 "보기" 를 두지 않는다(열 곳이 아직 없는 경우).
    var view: (() -> Void)?

    var body: some View {
        // ⚠️ `.top` 정렬을 쓰지 않는다 — `AuthCheckbox` 는 안에서 `minHeight: 42` 로 터치
        //  영역을 확보하므로, 위로 붙이면 "보기" 만 42pt 줄의 천장에 걸린다.
        HStack(spacing: 8) {
            AuthCheckbox(title: "\(isRequired ? "(필수)" : "(선택)") \(title)", isOn: $isOn)

            Spacer(minLength: 4)

            if let view {
                Button("보기", action: view)
                    .font(.notoSans(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(.deepGreen)
                    .accessibilityLabel("\(title) 전문 보기")
            }
        }
    }
}

/// 무장애 정보를 **계정에 저장하기 직전**에 받는 민감정보 동의.
///
/// 가입 화면을 지나온 뒤에도 이 동의가 필요한 자리가 있다 — 소셜 로그인은 동의 화면 없이
/// 계정이 만들어지고(`SocialSignInConsentNotice`), 무장애 항목을 나중에 고치는 길도 있다.
/// 그 두 경우에 값이 서버로 나가는 지점이 여기다.
struct SensitiveConsentGate: View {
    @Binding var isOn: Bool
    @State private var detail: LegalDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConsentRow(title: "민감정보(무장애 정보) 저장 동의", isRequired: true, isOn: $isOn) {
                detail = .sensitive
            }

            Text("무장애 정보는 건강·장애에 관한 민감정보라서, 계정에 저장하려면 동의가 필요해요.")
                .font(.notoSans(12, relativeTo: .caption))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .legalDocumentSheet($detail)
    }
}

/// 소셜 로그인 버튼 아래 한 줄.
///
/// 소셜 로그인은 체크박스를 거치지 않고 계정을 만든다 — 그래서 **약관·처리방침은 고지로**
/// 받고(업계 표준이고 심사에서도 이 형태를 본다), **민감정보는 고지로 갈음하지 않는다.**
/// 무장애 항목은 이 길로 들어온 계정에는 올라가지 않고 기기에 남아 있다가,
/// 설정에서 동의를 받은 뒤에 저장된다(`SensitiveConsentGate`).
///
/// ⚠️ **한 문장으로 둔다.** 무장애 항목을 어떻게 처리하는지까지 여기 적었더니 세 줄이 되어
/// 화면 아래 "회원가입" 줄과 겹쳤다(실측). 그 설명은 실제로 고르는 자리
/// (`SensitiveConsentGate`)에 있어야 읽힌다 — 로그인 화면에서는 아직 결정할 것이 없다.
struct SocialSignInConsentNotice: View {
    @State private var detail: LegalDocument?

    var body: some View {
        // 이 화면은 가운데 정렬이다 — 왼쪽으로 붙이면 고지만 어긋나 보이고, 링크를 글줄
        //  옆에 두면 문장 옆에서 세로 가운데에 걸린다(실측). 링크는 아래에 둔다.
        VStack(spacing: 2) {
            Text("계속하면 서비스 이용약관과 개인정보 처리방침에 동의하게 됩니다.")
                .font(.notoSans(11, relativeTo: .caption2))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("서비스 이용약관 보기") { detail = .terms }
                .font(.notoSans(11, .bold, relativeTo: .caption2))
                .foregroundStyle(.deepGreen)
                .frame(minHeight: 30)
        }
        .frame(maxWidth: .infinity)
        .legalDocumentSheet($detail)
    }
}

// MARK: - 전문 띄우기

/// 시트로 띄울 문서. 번들 텍스트 파일 이름이 그대로 값이다.
enum LegalDocument: String, Identifiable {
    case terms = "Terms"
    case sensitive = "SensitiveConsent"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "서비스 이용약관"
        case .sensitive: "민감정보 수집·이용 안내"
        }
    }
}

extension View {
    /// 동의 줄의 "보기" 가 띄우는 시트. 세 곳이 같은 방식으로 띄우게 한 곳에 둔다.
    func legalDocumentSheet(_ item: Binding<LegalDocument?>) -> some View {
        sheet(item: item) { document in
            NavigationStack {
                TermsView(resource: document.rawValue, title: document.title)
            }
        }
    }
}

#Preview("동의 영역") {
    @Previewable @State var consent = AuthConsent()
    return VStack(spacing: 32) {
        AuthConsentSection(consent: $consent, hasAccessFeatures: true)
        SensitiveConsentGate(isOn: $consent.sensitive)
        SocialSignInConsentNotice()
    }
    .padding(24)
}
