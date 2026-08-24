import Foundation

/// 번들 Secrets.plist(gitignore 대상)의 비밀 값 로더. 템플릿: Secrets.plist.example
enum Secrets {
    /// moduwa-backend API 키 (scripts/gen-api-key.mjs로 발급, Railway API_KEYS에 등록)
    static let moduwaAPIKey: String? = value("MODUWA_API_KEY")
    /// 카카오맵 SDK 네이티브 앱 키 (developers.kakao.com — iOS 플랫폼에 번들ID 등록 필요)
    static let kakaoNativeAppKey: String? = value("KAKAO_NATIVE_APP_KEY")
    /// 구글 iOS OAuth 클라이언트 ID (`...apps.googleusercontent.com`).
    ///
    /// **비밀이 아니다** — 설치형 앱의 클라이언트 ID 는 앱을 까면 읽히고, 구글도 그것을 전제로
    /// client_secret 을 발급하지 않는다(그 자리는 PKCE 가 맡는다, `GoogleSignInFlow`).
    /// 그래도 Secrets.plist 에 두는 이유는 하나 — 저장소에 올리지 않아 계정과 앱을 잇는
    /// 값이 공개 이력에 남지 않게 하려는 것이다(카카오 키와 같은 취급).
    ///
    /// ⚠️ 이 값의 **역방향** 문자열이 `Info.plist` 의 URL 스킴에 등록돼 있어야 로그인 후
    /// 앱으로 돌아온다. 값을 바꾸면 그쪽도 함께 바꿔야 한다.
    static let googleIOSClientID: String? = value("GOOGLE_IOS_CLIENT_ID")

    private static func value(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let value = dict[key] as? String, !value.isEmpty
        else { return nil }
        return value
    }
}
