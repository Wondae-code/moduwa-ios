import AuthenticationServices
import Foundation
import UIKit

/// Sign in with Apple — 창을 띄우고, 결과에서 서버에 보낼 값을 꺼낸다.
///
/// **애플이 주는 버튼(`SignInWithAppleButton`)을 쓰지 않는다**(2026-09-07). 그 버튼은 글자
/// 크기를 버튼 높이에 비례해 스스로 정해서(51pt 높이에 약 22pt) 옆의 구글·카카오 버튼(16pt)
/// 사이에서 혼자 커 보였다 — 손댈 수 있는 노브가 없다. 그래서 버튼은 직접 그리고
/// (`SocialSignInSection`) 흐름은 여기서 시작한다.
///
/// ⚠️ **직접 그릴 때 지켜야 하는 것**(애플 브랜드 지침): 애플 로고를 쓰고, 문구는 승인된
/// 것만 쓴다("Apple로 로그인"·"Apple로 계속하기"·"Apple로 가입하기"), 색은 검정 또는 흰색.
/// 글자 크기만 지침의 비율(높이의 43%)에서 벗어난다 — 다른 버튼과 나란히 세우기 위한 것이고,
/// 지침이 요구하는 "다른 로그인 수단보다 덜 눈에 띄게 두지 말라"는 조건은 높이·순서·대비로
/// 지킨다(맨 위, 검정 배경, 같은 높이).
///
/// **왜 필요한가**: 제3자 소셜 로그인(구글·카카오)을 제공하는 앱은 애플 로그인도 함께
/// 제공해야 한다(App Store Review Guideline 4.8). 없으면 심사에서 리젝된다.
enum AppleSignInFlow {
    /// 애플 로그인 창을 띄우고 결과를 돌려준다.
    ///
    /// 실패를 던지지 않고 `Result` 로 돌려주는 이유: 예전에 `SignInWithAppleButton` 이
    /// 같은 모양으로 줬고, 그 뒤를 받는 `credential(from:)` 과 화면 코드가 그대로 쓰인다.
    @MainActor
    static func start() async -> Result<ASAuthorization, Error> {
        await ApplePresenter().run()
    }

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

    /// 로그인 창의 결과를 서버에 보낼 값으로 바꾼다.
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

/// `ASAuthorizationController` 를 한 번 돌리고 사라지는 일회용 델리게이트.
///
/// ⚠️ **자기 자신과 컨트롤러를 붙잡아 둬야 한다.** 컨트롤러는 델리게이트를 약하게 들고,
/// 이 객체를 지역 변수로만 두면 창이 뜬 뒤 콜백이 오기 전에 사라져 **아무 일도 일어나지
/// 않는다.** 결과를 넘긴 뒤에 놓는다.
@MainActor
private final class ApplePresenter: NSObject, ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?
    private var controller: ASAuthorizationController?
    private var retained: ApplePresenter?

    func run() async -> Result<ASAuthorization, Error> {
        // 이름·이메일을 요청한다. **이름은 첫 로그인에만** 돌아온다.
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        retained = self

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        finish(.success(authorization))
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithError error: Error
    ) {
        // 사용자가 닫은 경우도 여기로 온다 — 걸러 내는 일은 `credential(from:)` 이 한다.
        finish(.failure(error))
    }

    /// 창을 어디에 띄울지. 시트 위에서 부를 수 있으므로 **키 윈도**를 찾는다.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        continuation?.resume(returning: result)
        continuation = nil
        controller = nil
        retained = nil
    }
}
