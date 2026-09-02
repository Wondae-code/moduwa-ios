import AuthenticationServices
import Foundation

/// Sign in with Apple — 버튼이 준 결과에서 서버에 보낼 값만 꺼낸다.
///
/// 구글·카카오와 달리 **앱이 로그인 창을 직접 띄우지 않는다**. 애플은 버튼 자체가 흐름을
/// 시작하는 UI 컴포넌트(`SignInWithAppleButton`)라, 여기서는 결과 파싱만 맡는다.
///
/// **왜 필요한가**: 제3자 소셜 로그인(구글·카카오)을 제공하는 앱은 애플 로그인도 함께
/// 제공해야 한다(App Store Review Guideline 4.8). 없으면 심사에서 리젝된다.
enum AppleSignInFlow {
    enum Failure: LocalizedError {
        /// 사용자가 창을 닫았다. 오류로 보여 주지 않는다.
        case cancelled
        /// 자격 증명은 왔는데 ID 토큰이 없다(있을 수 없는 조합이지만 옵셔널로 온다).
        case missingIdentityToken

        var errorDescription: String? {
            switch self {
            case .cancelled: nil
            case .missingIdentityToken: "Apple 로그인 정보를 확인할 수 없어요. 다시 시도해 주세요."
            }
        }
    }

    /// 서버(`POST /v1/auth/apple`)에 보낼 값.
    struct Credential {
        /// 애플이 준 ID 토큰. 서버가 애플 공개키로 검증하고 `aud` 가 번들 ID 인지 본다.
        let idToken: String
        /// 표시 이름. **첫 로그인에만 온다** — 애플은 두 번째부터 이름을 주지 않는다.
        /// 그래서 서버는 이 값이 없으면 기존 닉네임을 쓰거나 기본값을 만든다.
        let nickname: String?
        /// 인가 코드. 서버가 이걸 애플과 교환해 **refresh token** 을 받아 계정에 저장한다.
        ///
        /// **회원 탈퇴 때 필요하다** — 애플 로그인을 제공하는 앱은 계정을 지울 때 애플의 토큰
        /// 폐기 API 를 불러야 하고, 폐기에는 그 refresh token 이 필요하다. ID 토큰만 보내면
        /// 로그인은 되지만 탈퇴 때 폐기할 수단이 없다(서버 `auth-routes.ts:398`).
        ///
        /// 이 값도 **로그인할 때마다 오는 것이 아니다** — 매번 오지만 짧게 만료되고, 서버는
        /// 한 번 교환해 저장한 뒤에는 다시 필요하지 않다.
        let authorizationCode: String?
    }

    /// `SignInWithAppleButton` 의 결과를 서버에 보낼 값으로 바꾼다.
    static func credential(from result: Result<ASAuthorization, Error>) throws -> Credential {
        switch result {
        case .failure(let error):
            // 사용자가 닫은 것은 실패가 아니다. 그 외(1000 등)는 그대로 올린다.
            if (error as? ASAuthorizationError)?.code == .canceled { throw Failure.cancelled }
            throw error

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let idToken = String(data: data, encoding: .utf8)
            else { throw Failure.missingIdentityToken }

            return Credential(
                idToken: idToken,
                nickname: name(from: credential.fullName),
                authorizationCode: credential.authorizationCode
                    .flatMap { String(data: $0, encoding: .utf8) })
        }
    }

    /// 애플이 준 이름 조각을 한 줄로 만든다.
    ///
    /// 한국어 이름은 성 + 이름 순서라 `familyName` 을 앞에 둔다("김" + "은빈" → "김은빈").
    /// 조각이 하나도 없으면 nil — **지어내지 않는다.** 서버가 받은 이름으로 계정 닉네임을
    /// 갱신하므로, 빈 값을 채워 보내면 실제 닉네임을 덮어쓴다(후기·게시글 작성과 같은 규칙).
    private static func name(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let joined = [components.familyName, components.givenName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined()
        return joined.isEmpty ? nil : joined
    }
}
