import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// 카카오 로그인 — **공식 SDK**를 쓴다.
///
/// 구글은 SDK 없이 붙였는데(`GoogleSignInFlow`) 카카오는 다르게 판단했다. 카카오톡이 깔려
/// 있으면 **앱으로 전환해 한 번에** 로그인되는데, 그건 SDK 만 할 수 있다. 웹 로그인만 두면
/// 한국 사용자는 아이디·비밀번호를 직접 입력해야 하고 "왜 카톡으로 안 넘어가지?"가 된다.
///
/// 서버에는 **ID 토큰(OIDC)** 을 넘긴다(`POST /v1/auth/kakao`). 액세스 토큰이 아니다 —
/// 서버가 서명·발급자·`aud` 를 직접 검증할 수 있어야 하고, 그래야 남의 앱 토큰으로 남의
/// 계정에 들어가는 길이 막힌다.
///
/// ⚠️ **개발자 콘솔에서 OpenID Connect 를 켜야 한다.** 켜지 않으면 로그인은 성공하는데
/// `idToken` 이 nil 로 온다 — 앱에서는 성공처럼 보이고 서버에 보낼 것이 없는 상태가 된다.
@MainActor
enum KakaoSignInFlow {
    enum Failure: LocalizedError {
        /// 네이티브 앱 키가 없다(Secrets.plist 미설정). 버튼 자체를 감춘다.
        case notConfigured
        /// 사용자가 취소했다. **오류로 보여 주지 않는다.**
        case cancelled
        /// 로그인은 됐는데 ID 토큰이 없다 — 콘솔에서 OpenID Connect 가 꺼져 있다는 뜻이다.
        case missingIDToken
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "지금은 카카오 로그인을 쓸 수 없어요."
            case .cancelled: nil
            // 사용자가 고칠 수 있는 문제가 아니라 설정 문제다. 원인은 로그에 남긴다.
            case .missingIDToken: "카카오 로그인 설정이 끝나지 않았어요. 이메일로 로그인해 주세요."
            case .failed(let reason): reason.isEmpty ? "카카오 로그인에 실패했어요." : reason
            }
        }
    }

    /// 앱 키가 있는지. 없으면 화면이 버튼을 그리지 않는다.
    static var isConfigured: Bool { Secrets.kakaoNativeAppKey?.isEmpty == false }

    /// 로그인 한 판. 성공하면 카카오가 발급한 `id_token`(JWT)을 준다.
    ///
    /// 카카오톡이 있으면 앱으로, 없으면 카카오계정(웹)으로 간다. **카카오톡 쪽이 실패하면
    /// 웹으로 한 번 더 시도한다** — 톡이 깔려 있어도 로그아웃 상태거나 버전이 낮아 실패할 수
    /// 있는데, 거기서 끝내면 사용자는 들어갈 길이 없다.
    static func idToken() async throws -> String {
        guard isConfigured else { throw Failure.notConfigured }

        if UserApi.isKakaoTalkLoginAvailable() {
            do {
                return try await token(kakaoTalk: true)
            } catch Failure.cancelled {
                // 톡 화면에서 직접 취소한 것은 취소다. 웹으로 다시 밀지 않는다.
                throw Failure.cancelled
            } catch {
                print("[kakao] 카카오톡 로그인 실패 — 카카오계정으로 재시도: \(error)")
            }
        }
        return try await token(kakaoTalk: false)
    }

    private static func token(kakaoTalk: Bool) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let handler: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: mapped(error))
                    return
                }
                guard let idToken = token?.idToken, !idToken.isEmpty else {
                    // OIDC 가 꺼져 있으면 여기로 온다. 액세스 토큰은 있지만 서버가 검증할 수 없다.
                    print("[kakao] idToken 이 없다 — 개발자 콘솔의 OpenID Connect 설정을 확인할 것")
                    continuation.resume(throwing: Failure.missingIDToken)
                    return
                }
                continuation.resume(returning: idToken)
            }

            if kakaoTalk {
                UserApi.shared.loginWithKakaoTalk(completion: handler)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: handler)
            }
        }
    }

    /// 카카오 SDK 오류를 우리 오류로. 취소는 조용히 넘긴다.
    private static func mapped(_ error: Error) -> Failure {
        if let sdkError = error as? SdkError,
           case .ClientFailed(let reason, _) = sdkError,
           reason == .Cancelled {
            return .cancelled
        }
        return .failed("")
    }

    /// 카카오톡에서 앱으로 돌아왔을 때 SDK 에 넘겨 준다.
    ///
    /// 이걸 연결하지 않으면 **카카오톡에서 승인해도 앱이 그대로 멈춰 있다** — SDK 가 결과를
    /// 받지 못해 완료 핸들러가 영원히 불리지 않는다.
    /// - Returns: 카카오가 처리한 URL 이면 `true`.
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }
}
