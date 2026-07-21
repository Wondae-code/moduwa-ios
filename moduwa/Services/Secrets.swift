import Foundation

/// 번들 Secrets.plist(gitignore 대상)의 비밀 값 로더. 템플릿: Secrets.plist.example
enum Secrets {
    /// moduwa-backend API 키 (scripts/gen-api-key.mjs로 발급, Railway API_KEYS에 등록)
    static let moduwaAPIKey: String? = value("MODUWA_API_KEY")
    /// 카카오맵 SDK 네이티브 앱 키 (developers.kakao.com — iOS 플랫폼에 번들ID 등록 필요)
    static let kakaoNativeAppKey: String? = value("KAKAO_NATIVE_APP_KEY")

    private static func value(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let value = dict[key] as? String, !value.isEmpty
        else { return nil }
        return value
    }
}
