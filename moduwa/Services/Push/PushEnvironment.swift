import Foundation

/// 이 빌드가 어느 APNs 게이트웨이에 속하는지. 서버 `POST /v1/devices` 의 필수 필드다.
///
/// ⚠️ **가장 틀리기 쉬운 값이다.** 반대쪽으로 보내면 애플이 `BadDeviceToken` 으로 **조용히**
/// 거절해서, 앱에서는 "알림이 안 온다"로만 보인다(서버가 필수로 막아 둔 이유).
///
/// `#if DEBUG` 로 가르지 않는다 — Xcode 에서 Release 로 기기에 꽂아 보면 그 빌드는 여전히
/// 개발 프로비저닝이라 sandbox 인데, DEBUG 기준으로는 production 이라고 말하게 된다.
/// 실제 기준은 **프로비저닝 프로파일의 `aps-environment`** 이고, 그것을 그대로 읽는다.
enum PushEnvironment: String {
    /// Xcode 로 꽂은 빌드(개발 프로파일).
    case sandbox
    /// TestFlight · 앱스토어 빌드(배포 프로파일).
    case production

    /// 번들에 들어 있는 `embedded.mobileprovision` 의 `Entitlements.aps-environment` 를 읽는다.
    ///
    /// 시뮬레이터에는 프로파일이 아예 없어 `sandbox` 로 본다 — 시뮬레이터 토큰은 어차피
    /// 실제 APNs 로 가지 않는다(`simctl push` 전용).
    static var current: PushEnvironment {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url)
        else { return .sandbox }

        // 프로파일은 CMS 서명으로 감싼 바이너리다. 그 안에 평문 plist 가 그대로 들어 있어
        //  `<?xml` ~ `</plist>` 구간만 잘라 내면 별도 복호화 없이 읽을 수 있다.
        guard let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.lowerBound..<raw.endIndex)
        else { return .sandbox }

        let plist = raw[start.lowerBound..<end.upperBound]
        guard let parsed = try? PropertyListSerialization.propertyList(
                  from: plist, options: [], format: nil) as? [String: Any],
              let entitlements = parsed["Entitlements"] as? [String: Any],
              let aps = entitlements["aps-environment"] as? String
        else { return .sandbox }

        // 프로파일의 표기는 `development`/`production` 이고 서버 표기는 `sandbox`/`production` 이다.
        return aps == "production" ? .production : .sandbox
    }
}
