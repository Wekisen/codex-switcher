import Foundation

struct UsageResult: Sendable {
    var auth: AuthFile
    var usage: UsageResponse
}

final class CodexUsageClient: @unchecked Sendable {
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private let usageURLs = [
        URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        URL(string: "https://chatgpt.com/api/codex/usage")!
    ]
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func fetchUsage(auth originalAuth: AuthFile) async throws -> UsageResult {
        var auth = originalAuth
        if JWT.expiresSoon(auth.tokens?.accessToken) {
            auth = try await refresh(auth: auth)
        }

        var errors: [String] = []
        var hasUnauthorizedError = false
        for url in usageURLs {
            do {
                var request = URLRequest(url: url)
                request.setValue("Bearer \(auth.tokens?.accessToken ?? "")", forHTTPHeaderField: "Authorization")
                request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
                if let accountID = auth.tokens?.accountID {
                    request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
                }

                let data = try await send(request)
                let usage = try decoder.decode(UsageResponse.self, from: data)
                return UsageResult(auth: auth, usage: usage)
            } catch {
                hasUnauthorizedError = hasUnauthorizedError || error.requiresVerification
                errors.append("\(url.absoluteString): \(error.localizedDescription)")
            }
        }

        if hasUnauthorizedError {
            throw AppError.unauthorized(errors.joined(separator: "\n"))
        }
        throw AppError.network(errors.joined(separator: "\n"))
    }

    private func refresh(auth originalAuth: AuthFile) async throws -> AuthFile {
        guard let refreshToken = originalAuth.tokens?.refreshToken else {
            throw AppError.invalidAuth(L10n.missingRefreshToken())
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email"
        ])

        let data = try await send(request)
        let response = try decoder.decode(TokenRefreshResponse.self, from: data)

        var auth = originalAuth
        if var tokens = auth.tokens {
            tokens.accessToken = response.accessToken ?? tokens.accessToken
            tokens.idToken = response.idToken ?? tokens.idToken
            tokens.refreshToken = response.refreshToken ?? tokens.refreshToken
            auth.tokens = tokens
        }
        auth.lastRefresh = ISO8601DateFormatter().string(from: Date())
        return auth
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let session = URLSession(configuration: URLSessionConfiguration.codexConfiguration)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network(L10n.httpNoResponse())
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AppError.http(http.statusCode, body)
        }
        return data
    }
}

private struct TokenRefreshResponse: Decodable {
    var accessToken: String?
    var idToken: String?
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
    }
}

enum JWT {
    static func decode(_ token: String?) -> IDTokenPayload? {
        guard let payload = token?.split(separator: ".").dropFirst().first else { return nil }
        var base64 = String(payload)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(IDTokenPayload.self, from: data)
    }

    static func expiresSoon(_ token: String?, skewSeconds: TimeInterval = 300) -> Bool {
        guard let exp = decode(token)?.exp else { return true }
        return exp <= Date().addingTimeInterval(skewSeconds).timeIntervalSince1970
    }

    static func extractAccountID(from token: String?) -> String? {
        guard let object = decodeObject(token),
              let auth = object["https://api.openai.com/auth"] as? [String: Any] else {
            return nil
        }
        return auth["chatgpt_account_id"] as? String
    }

    private static func decodeObject(_ token: String?) -> [String: Any]? {
        guard let payload = token?.split(separator: ".").dropFirst().first else { return nil }
        var base64 = String(payload)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }
}

extension URLSessionConfiguration {
    static var codexConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        if let proxy = EnvironmentProxy.custom ?? EnvironmentProxy.current {
            configuration.connectionProxyDictionary = proxy.dictionary
        }
        return configuration
    }
}

private struct EnvironmentProxy {
    var host: String
    var port: Int
    var username: String?
    var password: String?

    var dictionary: [AnyHashable: Any] {
        var values: [AnyHashable: Any] = [
            kCFNetworkProxiesHTTPEnable as String: true,
            kCFNetworkProxiesHTTPProxy as String: host,
            kCFNetworkProxiesHTTPPort as String: port,
            kCFNetworkProxiesHTTPSEnable as String: true,
            kCFNetworkProxiesHTTPSProxy as String: host,
            kCFNetworkProxiesHTTPSPort as String: port
        ]
        if let username {
            values["HTTPProxyUsername"] = username
            values["HTTPSProxyUsername"] = username
            values[kCFProxyUsernameKey as String] = username
        }
        if let password {
            values["HTTPProxyPassword"] = password
            values["HTTPSProxyPassword"] = password
            values[kCFProxyPasswordKey as String] = password
        }
        return values
    }

    static var current: EnvironmentProxy? {
        let env = ProcessInfo.processInfo.environment
        let raw = env["HTTPS_PROXY"] ?? env["https_proxy"] ?? env["HTTP_PROXY"] ?? env["http_proxy"]
        guard let match = raw?.replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .range(of: #"https?://[^\s]+"#, options: .regularExpression)
            .map({ String(raw![$0]) }),
              let url = URL(string: match),
              let host = url.host,
              let port = url.port else {
            return nil
        }
        return EnvironmentProxy(
            host: host,
            port: port,
            username: url.user,
            password: url.password
        )
    }

    static var custom: EnvironmentProxy? {
        guard let proxy = ProxySettings.customProxy else { return nil }
        return EnvironmentProxy(
            host: proxy.host,
            port: proxy.port,
            username: proxy.username,
            password: proxy.password
        )
    }
}
