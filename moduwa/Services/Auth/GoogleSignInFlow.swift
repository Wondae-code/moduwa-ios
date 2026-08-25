import AuthenticationServices
import CryptoKit
import Foundation

/// 구글 로그인 — **SDK 없이** `ASWebAuthenticationSession` + PKCE(RFC 8252).
///
/// SDK(`GoogleSignIn-iOS`)도 내부에서 같은 `ASWebAuthenticationSession` 을 쓴다. 사용자가 보는
/// 화면은 다르지 않다. SDK 가 더 주는 것은 토큰 갱신·무음 재로그인·브랜드 버튼 에셋인데,
/// **앞의 둘은 구글 API 를 계속 호출하는 앱을 위한 것**이다. 우리는 여기서 받은 id_token 을
/// 서버에 한 번 넘기고 우리 세션 토큰(90일)을 받으므로 그 뒤로 구글 토큰을 쓸 데가 없다.
/// 그래서 의존성 4개(AppAuth·GTMAppAuth·GTMSessionFetcher 포함) 대신 이 파일을 둔다.
///
/// 구글 API(캘린더 내보내기, 포토 가져오기)를 부르기로 하면 그때 SDK 로 갈아탄다 —
/// 서버는 손댈 것이 없다(둘 다 같은 id_token 을 준다).
///
/// **흐름**: 인증 URL 열기 → 사용자가 구글에서 승인 → `code` 로 리다이렉트 →
/// `code` + `code_verifier` 를 구글 토큰 엔드포인트에 교환 → `id_token` 을 얻는다.
/// 그 토큰을 `POST /v1/auth/google` 로 보내면 서버가 서명·발급자·**aud** 를 검증한다.
@MainActor
final class GoogleSignInFlow: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: LocalizedError, Equatable {
        /// 클라이언트 ID 가 없다(Secrets.plist 미설정). 버튼 자체를 감추는 게 맞다.
        case notConfigured
        /// 사용자가 시트를 닫았다. **오류로 보여 주지 않는다** — 본인이 취소한 것이다.
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "지금은 Google 로그인을 쓸 수 없어요."
            case .cancelled: nil
            // 버튼에 적힌 이름과 같이 "Google" 로 쓴다 — 한 화면에서 "Google"과 "구글"을
            //  섞으면 같은 것을 두 이름으로 배우게 된다.
            case .failed(let reason): reason.isEmpty ? "Google 로그인에 실패했어요." : reason
            }
        }
    }

    /// 클라이언트 ID 가 있는지. 없으면 화면이 버튼을 그리지 않는다.
    static var isConfigured: Bool {
        (Secrets.googleIOSClientID?.isEmpty == false)
    }

    private let clientID: String
    private let urlSession: URLSession
    /// 진행 중인 세션. **강한 참조가 필요하다** — 놓으면 시트가 뜨자마자 사라진다.
    private var session: ASWebAuthenticationSession?

    init(clientID: String? = nil, urlSession: URLSession = .shared) {
        self.clientID = clientID ?? Secrets.googleIOSClientID ?? ""
        self.urlSession = urlSession
        super.init()
    }

    /// 구글 iOS 클라이언트의 리다이렉트 스킴은 **역방향 클라이언트 ID** 다(구글이 정한 규칙).
    /// `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`
    ///
    /// ⚠️ 이 문자열이 `Info.plist` 의 `CFBundleURLSchemes` 에 등록돼 있어야 앱으로 돌아온다.
    private var redirectScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    private var redirectURI: String { "\(redirectScheme):/oauth2redirect" }

    /// 로그인 한 판. 성공하면 구글이 발급한 `id_token`(JWT)을 준다.
    func idToken() async throws -> String {
        guard !clientID.isEmpty else { throw Failure.notConfigured }

        // PKCE — 인증 코드가 중간에서 가로채여도 verifier 없이는 토큰으로 바꿀 수 없다.
        //  iOS 클라이언트에는 client_secret 이 없으므로(앱에 넣으면 비밀이 아니다)
        //  코드와 이 앱을 잇는 유일한 근거가 이것이다.
        let verifier = Self.randomURLSafe(bytes: 32)
        let challenge = Self.sha256URLSafe(verifier)
        // CSRF 방어. 돌아온 state 가 보낸 것과 다르면 우리가 시작한 흐름이 아니다.
        let state = Self.randomURLSafe(bytes: 16)
        // 구글이 id_token 에 그대로 담아 준다. 재생 공격 방어용이며 검증은 서버가 aud·서명과
        //  함께 본다(PKCE 가 이미 코드를 이 앱에 묶으므로 앱에서 따로 열어 보지 않는다).
        let nonce = Self.randomURLSafe(bytes: 16)

        let callback = try await authorize(challenge: challenge, state: state, nonce: nonce)
        let code = try Self.authorizationCode(from: callback, expectedState: state)
        return try await exchange(code: code, verifier: verifier)
    }

    // MARK: - ① 인증 화면

    private func authorize(challenge: String, state: String, nonce: String) async throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            // openid 는 id_token 을 받기 위해, email 은 계정 이메일을 위해 필요하다.
            //  profile 은 초기 닉네임(`name`)에 쓴다 — 없으면 계정 이름이 "여행자"로 시작한다.
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "nonce", value: nonce),
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: redirectScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                    return
                }
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: Failure.cancelled)
                    return
                }
                continuation.resume(throwing: Failure.failed(error?.localizedDescription ?? ""))
            }
            session.presentationContextProvider = self
            // 사파리의 기존 구글 로그인을 그대로 쓴다. `true` 로 두면 매번 비밀번호를 넣어야 한다.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            // start() 가 false 를 주면 완료 핸들러는 **불리지 않는다** — 여기서 끝내야 한다.
            if !session.start() {
                continuation.resume(throwing: Failure.failed("로그인 창을 열 수 없어요."))
            }
        }
    }

    /// 돌아온 URL 에서 인증 코드를 꺼낸다. `state` 가 다르면 우리가 시작한 흐름이 아니다.
    private static func authorizationCode(from url: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        // 사용자가 구글 화면에서 거부한 경우. 취소와 같게 다룬다.
        if value("error") == "access_denied" { throw Failure.cancelled }
        if let error = value("error") { throw Failure.failed("Google이 거부했어요 (\(error)).") }
        guard value("state") == expectedState else {
            throw Failure.failed("로그인 응답이 요청과 맞지 않아요. 다시 시도해 주세요.")
        }
        guard let code = value("code"), !code.isEmpty else {
            throw Failure.failed("Google이 인증 코드를 주지 않았어요.")
        }
        return code
    }

    // MARK: - ② 토큰 교환

    private struct TokenResponse: Decodable {
        let idToken: String?
        /// 구글이 실패를 이 모양으로 준다 — `{error, error_description}`.
        let error: String?
        let errorDescription: String?
    }

    private func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // client_secret 이 없다. 설치형 앱(iOS)에는 발급되지 않고, 넣더라도 앱을 까면 읽히므로
        //  비밀이 될 수 없다 — 그 자리를 PKCE 가 대신한다.
        var form = URLComponents()
        form.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "code", value: code),
            .init(name: "code_verifier", value: verifier),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "redirect_uri", value: redirectURI),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        do {
            (data, _) = try await urlSession.data(for: request)
        } catch {
            throw Failure.failed("Google에 연결하지 못했어요. 네트워크 상태를 확인해 주세요.")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(TokenResponse.self, from: data) else {
            throw Failure.failed("Google 응답을 읽지 못했어요.")
        }
        if let idToken = response.idToken, !idToken.isEmpty { return idToken }
        // 사유는 개발자용 문구라 그대로 보여 주지 않는다. 로그에만 남긴다.
        print("[google] 토큰 교환 실패: \(response.error ?? "?") \(response.errorDescription ?? "")")
        throw Failure.failed("Google 로그인을 마치지 못했어요. 다시 시도해 주세요.")
    }

    // MARK: - 값 만들기

    private static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        // 추측 가능한 값이면 PKCE·state 가 둘 다 무의미해진다 — 시스템 CSPRNG 를 쓴다.
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func sha256URLSafe(_ text: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(text.utf8))))
    }

    /// base64url(패딩 없음) — OAuth 파라미터는 URL 에 그대로 실려야 한다.
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - 시트를 띄울 창

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
