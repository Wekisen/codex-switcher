import Foundation

struct AuthFile: Codable, Sendable {
    var authMode: String?
    var openAIAPIKey: String?
    var tokens: AuthTokens?
    var lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case openAIAPIKey = "OPENAI_API_KEY"
        case tokens
        case lastRefresh = "last_refresh"
    }
}

struct AuthTokens: Codable, Sendable {
    var accessToken: String?
    var accountID: String?
    var idToken: String?
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accountID = "account_id"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
    }
}

struct AccountRecord: Codable, Identifiable, Sendable {
    var id: String
    var email: String
    var name: String
    var importedAt: Date
    var lastUsageRefresh: Date?
    var auth: AuthFile
    var usage: UsageResponse?
}

struct UsageResponse: Codable, Equatable, Sendable {
    var email: String?
    var planType: String?
    var rateLimit: RateLimit?
    var codeReviewRateLimit: RateLimit?
    var credits: Credits?
    var rateLimitReachedType: String?

    enum CodingKeys: String, CodingKey {
        case email
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case codeReviewRateLimit = "code_review_rate_limit"
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
    }

    init(
        email: String? = nil,
        planType: String? = nil,
        rateLimit: RateLimit? = nil,
        codeReviewRateLimit: RateLimit? = nil,
        credits: Credits? = nil,
        rateLimitReachedType: String? = nil
    ) {
        self.email = email
        self.planType = planType
        self.rateLimit = rateLimit
        self.codeReviewRateLimit = codeReviewRateLimit
        self.credits = credits
        self.rateLimitReachedType = rateLimitReachedType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = container.decodeFlexibleStringIfPresent(forKey: .email)
        planType = container.decodeFlexibleStringIfPresent(forKey: .planType)
        rateLimit = container.decodeLossyIfPresent(RateLimit.self, forKey: .rateLimit)
        codeReviewRateLimit = container.decodeLossyIfPresent(RateLimit.self, forKey: .codeReviewRateLimit)
        credits = container.decodeLossyIfPresent(Credits.self, forKey: .credits)
        rateLimitReachedType = container.decodeFlexibleStringIfPresent(forKey: .rateLimitReachedType)
    }
}

struct RateLimit: Codable, Equatable, Sendable {
    var allowed: Bool?
    var limitReached: Bool?
    var primaryWindow: UsageWindow?
    var secondaryWindow: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }

    init(allowed: Bool? = nil, limitReached: Bool? = nil, primaryWindow: UsageWindow? = nil, secondaryWindow: UsageWindow? = nil) {
        self.allowed = allowed
        self.limitReached = limitReached
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowed = container.decodeFlexibleBoolIfPresent(forKey: .allowed)
        limitReached = container.decodeFlexibleBoolIfPresent(forKey: .limitReached)
        primaryWindow = container.decodeLossyIfPresent(UsageWindow.self, forKey: .primaryWindow)
        secondaryWindow = container.decodeLossyIfPresent(UsageWindow.self, forKey: .secondaryWindow)
    }
}

struct UsageWindow: Codable, Equatable, Sendable {
    var usedPercent: Double?
    var resetAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAt = "reset_at"
    }

    init(usedPercent: Double? = nil, resetAt: Double? = nil) {
        self.usedPercent = usedPercent
        self.resetAt = resetAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = container.decodeFlexibleDoubleIfPresent(forKey: .usedPercent)
        resetAt = container.decodeFlexibleDoubleIfPresent(forKey: .resetAt)
    }
}

struct Credits: Codable, Equatable, Sendable {
    var hasCredits: Bool?
    var unlimited: Bool?
    var balance: String?

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
    }

    init(hasCredits: Bool? = nil, unlimited: Bool? = nil, balance: String? = nil) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCredits = container.decodeFlexibleBoolIfPresent(forKey: .hasCredits)
        unlimited = container.decodeFlexibleBoolIfPresent(forKey: .unlimited)
        balance = container.decodeFlexibleStringIfPresent(forKey: .balance)
    }
}

struct IDTokenPayload: Decodable, Sendable {
    var email: String?
    var name: String?
    var exp: Double?
    var sub: String?
}

enum AppError: LocalizedError {
    case missingAuth
    case invalidAuth(String)
    case network(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAuth:
            return "没有找到 ~/.codex/auth.json，请先运行 codex login。"
        case .invalidAuth(let message):
            return message
        case .network(let message):
            return message
        case .http(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    func decodeFlexibleBoolIfPresent(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
