import SwiftUI

/// 서비스 이용약관 — 번들에 실린 텍스트(`Terms.txt`)를 그대로 보여 준다.
///
/// **웹뷰가 아니라 번들 텍스트인 이유**: 약관은 앱 안에서 읽을 수 있으면 충분하고(앱스토어가
/// URL 을 요구하는 것은 **개인정보 처리방침**이다), 웹으로 두면 비행기·지하철에서 열리지 않는다.
/// 문구가 바뀌면 이 파일 하나만 갈아끼운다.
///
/// ⚠️ 코드에 문구를 넣지 않는다 — 약관은 기획·법무가 쥔 문서이고, 스위프트 문자열에 있으면
/// 고칠 때마다 코드 리뷰를 거쳐야 한다.
struct TermsView: View {
    /// 번들 파일 이름(확장자 제외).
    var resource = "Terms"
    /// 화면 제목. 같은 화면이 약관과 민감정보 안내를 모두 띄우므로 제목도 함께 받는다.
    var title = "서비스 이용약관"

    @State private var text: String?

    var body: some View {
        ScrollView {
            if let text {
                Text(text)
                    .font(.notoSans(14, .regular, relativeTo: .body))
                    .foregroundStyle(.textSecondary)
                    .lineSpacing(6)
                    // 약관은 인용·공유할 일이 있다. 선택을 막을 이유가 없다.
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
            } else {
                // 번들에서 못 읽는 경우(파일 누락). 빈 화면보다 사실을 말한다.
                Text("문서를 불러오지 못했어요. 앱을 다시 실행해 주세요.")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .padding(24)
            }
        }
        .background(.white)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard text == nil else { return }
            text = Self.load(resource)
        }
    }

    static func load(_ resource: String) -> String? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return raw
    }
}

#Preview("이용약관") {
    NavigationStack { TermsView() }
}
