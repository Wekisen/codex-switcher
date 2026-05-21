import AppKit
import CryptoKit
import Foundation
import Network

@MainActor
final class OAuthLoginService {
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let issuer = "https://auth.openai.com"
    private let port: UInt16 = 1455
    private var listener: NWListener?
    private var continuation: CheckedContinuation<AuthFile, Error>?
    private var expectedState: String?
    private var codeVerifier: String?

    func start() async throws -> AuthFile {
        let verifier = randomBase64URL(byteCount: 32)
        let challenge = pkceChallenge(for: verifier)
        let state = randomBase64URL(byteCount: 32)
        let redirectURI = "http://localhost:\(port)/auth/callback"

        codeVerifier = verifier
        expectedState = state

        try startServer(redirectURI: redirectURI)
        openAuthorizeURL(redirectURI: redirectURI, challenge: challenge, state: state)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        listener?.cancel()
        listener = nil
        continuation?.resume(throwing: AppError.invalidAuth("已取消添加账号。"))
        continuation = nil
        expectedState = nil
        codeVerifier = nil
    }

    private func startServer(redirectURI: String) throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor in
                self?.handle(connection: connection, redirectURI: redirectURI)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                Task { @MainActor in
                    self?.finish(with: .failure(AppError.network("OAuth 本地回调服务失败：\(error.localizedDescription)")))
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func handle(connection: NWConnection, redirectURI: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            Task { @MainActor in
                self?.process(data: data, connection: connection, redirectURI: redirectURI)
            }
        }
    }

    private func process(data: Data?, connection: NWConnection, redirectURI: String) {
        let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              let target = firstLine.split(separator: " ").dropFirst().first,
              let url = URL(string: "http://localhost:\(port)\(target)") else {
            respond(connection, status: "400 Bad Request", body: Self.errorHTML("Invalid callback request"))
            return
        }

        guard url.path == "/auth/callback" else {
            respond(connection, status: "404 Not Found", body: Self.errorHTML("Unknown callback path"))
            return
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        if let error = query["error"] {
            let message = query["error_description"] ?? error
            respond(connection, status: "200 OK", body: Self.errorHTML(message))
            finish(with: .failure(AppError.invalidAuth(message)))
            return
        }

        guard query["state"] == expectedState else {
            respond(connection, status: "400 Bad Request", body: Self.errorHTML("Invalid state"))
            finish(with: .failure(AppError.invalidAuth("OAuth state 校验失败。")))
            return
        }

        guard let code = query["code"], let verifier = codeVerifier else {
            respond(connection, status: "400 Bad Request", body: Self.errorHTML("Missing authorization code"))
            finish(with: .failure(AppError.invalidAuth("OAuth 回调缺少授权码。")))
            return
        }

        respond(connection, status: "200 OK", body: Self.successHTML)
        Task {
            do {
                let auth = try await exchangeCode(code, redirectURI: redirectURI, verifier: verifier)
                finish(with: .success(auth))
            } catch {
                finish(with: .failure(error))
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func openAuthorizeURL(redirectURI: String, challenge: String, state: String) {
        var components = URLComponents(string: "\(issuer)/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access api.connectors.read api.connectors.invoke"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: "codex_accounts_macos")
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func exchangeCode(_ code: String, redirectURI: String, verifier: String) async throws -> AuthFile {
        let url = URL(string: "\(issuer)/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier
        ])

        let session = URLSession(configuration: .codexConfiguration)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network("OAuth token exchange 没有收到 HTTP 响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let tokens = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        let accountID = JWT.extractAccountID(from: tokens.idToken) ?? JWT.extractAccountID(from: tokens.accessToken)
        guard let accountID else {
            throw AppError.invalidAuth("OAuth token 中没有找到 ChatGPT account id。")
        }

        return AuthFile(
            authMode: "chatgpt",
            openAIAPIKey: nil,
            tokens: AuthTokens(
                accessToken: tokens.accessToken,
                accountID: accountID,
                idToken: tokens.idToken,
                refreshToken: tokens.refreshToken
            ),
            lastRefresh: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func finish(with result: Result<AuthFile, Error>) {
        listener?.cancel()
        listener = nil
        expectedState = nil
        codeVerifier = nil

        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    private func pkceChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private func randomBase64URL(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func formBody(_ values: [String: String]) -> Data {
        let body = values.map { key, value in
            "\(urlEncode(key))=\(urlEncode(value))"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static let successHTML = """
    <!doctype html><html><head><meta charset="utf-8"><title>Codex Switcher</title></head>
    <body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:40px">
    <h2>Authorization Successful</h2><p>You can close this window and return to Codex Switcher.</p>
    <script>setTimeout(() => window.close(), 1200)</script>
    </body></html>
    """

    private static func errorHTML(_ message: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><title>Codex Switcher</title></head>
        <body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:40px">
        <h2>Authorization Failed</h2><p>\(message)</p>
        </body></html>
        """
    }
}

private struct OAuthTokenResponse: Decodable {
    var accessToken: String
    var idToken: String
    var refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
    }
}
