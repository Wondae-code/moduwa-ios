import SwiftUI
import UIKit

/// 고객센터 — 문의 메일을 보내는 자리.
///
/// **앱스토어 심사(1.2)가 연락 수단 공개를 요구한다.** 예전에는 "준비 중" 안내만 띄웠는데,
/// 주소(`help@moduwa.app`)는 이미 처리방침·약관 본문에 있었다 — 화면에 연결만 안 돼 있었다.
///
/// ⚠️ **`mailto:` 하나로 끝내지 않는다.** 메일 앱을 지웠거나 계정을 넣지 않은 기기에서는
/// 그 링크가 **아무 일도 하지 않는다** — 누른 사람은 앱이 고장 났다고 읽는다. 그래서 주소를
/// 화면에 **글자로 먼저 보여 주고**(길게 눌러 복사할 수 있다), 버튼은 그 위에 얹는다.
/// 열지 못하면 자동으로 클립보드에 넣고 그 사실을 알린다.
///
/// 제목에 버전·빌드를 미리 넣어 둔다 — 문의 대부분이 "어떤 버전이세요?" 로 한 번 더 오간다.
struct HelpCenterView: View {
    @Environment(\.openURL) private var openURL
    /// 주소를 클립보드에 넣었다는 알림. 메일 앱이 없을 때만 뜬다.
    @State private var didCopy = false

    private var address: String { LegalLinks.supportEmail ?? "" }

    /// "모두와 문의 (1.0(80), iOS 26.0)" — 답장하는 쪽이 되묻지 않아도 되게.
    private var subject: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let system = UIDevice.current.systemVersion
        return "모두와 문의 (\(version)(\(build)), iOS \(system))"
    }

    private var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("문의하실 내용이 있으면 아래 주소로 메일을 보내 주세요.\n확인하는 대로 답장드릴게요.")
                    .font(.notoSans(15, .regular, relativeTo: .body))
                    .foregroundStyle(.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text(address)
                    .font(.notoSans(18, .bold, relativeTo: .headline))
                    .foregroundStyle(.textPrimary)
                    // 메일 앱이 없어도 손으로 옮길 수 있어야 한다.
                    .textSelection(.enabled)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .background(Color.photoPlaceholder, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 22)

                Button(action: compose) {
                    Text("메일 보내기")
                        .font(.notoSans(16, .bold, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 47)
                        .background(Capsule().fill(Color.moduwaGreen))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .accessibilityHint("메일 앱이 열립니다. 열 수 없으면 주소가 복사돼요")

                if didCopy {
                    Text("메일 앱을 열 수 없어 주소를 복사했어요.")
                        .font(.notoSans(13, .regular, relativeTo: .footnote))
                        .foregroundStyle(.textSecondary)
                        .padding(.top, 10)
                        // 화면을 보지 않는 사용자에게도 결과가 닿아야 한다.
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(.white)
        .navigationTitle("고객센터")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 메일 앱을 연다. 못 열면 **주소를 복사하고 그 사실을 알린다** — 아무 일도 안 일어나는
    /// 것이 제일 나쁘다.
    private func compose() {
        guard let mailURL else { return copyAddress() }
        openURL(mailURL) { opened in
            if !opened { copyAddress() }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = address
        withAnimation { didCopy = true }
        UIAccessibility.post(notification: .announcement, argument: "주소를 복사했어요")
    }
}

#Preview("고객센터") {
    NavigationStack { HelpCenterView() }
}
