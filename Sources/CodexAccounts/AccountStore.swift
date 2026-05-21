import AppKit
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [AccountRecord] = []
    @Published private(set) var currentAccountID: String?
    @Published var isRefreshing = false
    @Published private(set) var refreshingAccountIDs: Set<String> = []
    @Published private(set) var refreshFailures: [String: String] = [:]
    @Published private(set) var isAddingAccount = false
    @Published var message: String?

    private let client = CodexUsageClient()
    private let oauth = OAuthLoginService()
    private var lastOpenRefreshAt: Date?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Codex Switcher", isDirectory: true)
    }

    var legacyAppSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Codex Account Manager", isDirectory: true)
    }

    var accountsDirectory: URL {
        appSupportDirectory.appendingPathComponent("accounts", isDirectory: true)
    }

    var backupsDirectory: URL {
        appSupportDirectory.appendingPathComponent("backups", isDirectory: true)
    }

    var pendingAddDirectory: URL {
        appSupportDirectory.appendingPathComponent("pending-add", isDirectory: true)
    }

    var pendingStateURL: URL {
        pendingAddDirectory.appendingPathComponent("state.json")
    }

    var codexAuthURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")
    }

    func load() async {
        do {
            try ensureDirectories()
            accounts = try loadAccounts()
            currentAccountID = try readCurrentAccountID()
            isAddingAccount = FileManager.default.fileExists(atPath: pendingStateURL.path)
            message = accounts.isEmpty ? "请先添加 Codex 账号。" : nil
        } catch {
            message = error.localizedDescription
        }
    }

    func beginAddAccount() async {
        do {
            try ensureDirectories()
            try #"{"status":"adding"}"#.write(to: pendingStateURL, atomically: true, encoding: .utf8)

            isAddingAccount = true
            message = "已打开浏览器授权页，等待登录回调。"

            let auth = try await oauth.start()
            let record = try makeAccountRecord(from: auth, existing: accounts.first { $0.id == auth.tokens?.accountID })
            try save(record)
            try resetPendingAddDirectory()
            accounts = try loadAccounts()
            currentAccountID = try readCurrentAccountID()
            isAddingAccount = false
            message = "已添加 \(record.email)。"
            await refresh(accountID: record.id)
        } catch {
            isAddingAccount = false
            try? resetPendingAddDirectory()
            message = error.localizedDescription
        }
    }

    func cancelAddAccount() async {
        do {
            oauth.cancel()
            try ensureDirectories()
            try resetPendingAddDirectory()
            accounts = try loadAccounts()
            currentAccountID = try readCurrentAccountID()
            isAddingAccount = false
            message = "已取消添加账号。"
        } catch {
            message = error.localizedDescription
        }
    }

    func refreshOnOpen() async {
        guard !accounts.isEmpty, !isRefreshing, !isAddingAccount else { return }
        syncCurrentAccountFromDisk()
        if let lastOpenRefreshAt, Date().timeIntervalSince(lastOpenRefreshAt) < 20 {
            return
        }
        lastOpenRefreshAt = Date()
        await refreshAll()
    }

    func switchToAccount(_ id: String) async {
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        do {
            try ensureDirectories()
            let currentID = try readCurrentAccountID()
            if currentID == id {
                currentAccountID = id
                message = "当前已是 \(account.email)。"
                return
            }
            if FileManager.default.fileExists(atPath: codexAuthURL.path) {
                let backup = uniqueBackupURL()
                try FileManager.default.copyItem(at: codexAuthURL, to: backup)
            }
            try writeAuth(account.auth, to: codexAuthURL)
            currentAccountID = id
            message = "已切换到 \(account.email)。"
        } catch {
            message = error.localizedDescription
        }
    }

    func refreshAll() async {
        let snapshots = accounts
        guard !snapshots.isEmpty else { return }

        isRefreshing = true
        refreshingAccountIDs.formUnion(snapshots.map(\.id))
        for account in snapshots {
            refreshFailures[account.id] = nil
        }
        defer {
            refreshingAccountIDs.subtract(snapshots.map(\.id))
            isRefreshing = false
        }

        let client = client
        let failedMessages = await withTaskGroup(of: RefreshAllResult.self) { group in
            for account in snapshots {
                group.addTask {
                    do {
                        let usage = try await client.fetchUsage(auth: account.auth)
                        return RefreshAllResult(accountID: account.id, outcome: .success(usage))
                    } catch {
                        return RefreshAllResult(accountID: account.id, outcome: .failure(error.localizedDescription))
                    }
                }
            }

            var failedMessages: [String] = []
            for await result in group {
                refreshingAccountIDs.remove(result.accountID)
                guard let index = accounts.firstIndex(where: { $0.id == result.accountID }) else { continue }

                switch result.outcome {
                case .success(let usage):
                    var account = accounts[index]
                    account.auth = usage.auth
                    account.usage = usage.usage
                    account.lastUsageRefresh = Date()
                    do {
                        try save(account)
                        accounts[index] = account
                        refreshFailures[result.accountID] = nil
                    } catch {
                        let message = error.localizedDescription
                        refreshFailures[result.accountID] = message
                        failedMessages.append("\(account.email)：\(message)")
                    }
                case .failure(let message):
                    let email = accounts[index].email
                    refreshFailures[result.accountID] = message
                    failedMessages.append("\(email)：\(message)")
                }
            }
            return failedMessages
        }

        message = failedMessages.isEmpty ? "已刷新全部账号。" : "部分账号刷新失败：\(failedMessages.joined(separator: "；"))"
    }

    @discardableResult
    func refresh(accountID: String, showProgress: Bool = true) async -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return false }
        if showProgress {
            isRefreshing = true
        }
        refreshFailures[accountID] = nil
        refreshingAccountIDs.insert(accountID)
        defer {
            refreshingAccountIDs.remove(accountID)
            if showProgress {
                isRefreshing = false
            }
        }

        do {
            var account = accounts[index]
            let result = try await client.fetchUsage(auth: account.auth)
            account.auth = result.auth
            account.usage = result.usage
            account.lastUsageRefresh = Date()
            try save(account)
            accounts[index] = account
            refreshFailures[accountID] = nil
            message = "已刷新 \(account.email)。"
            return true
        } catch {
            let errorMessage = error.localizedDescription
            refreshFailures[accountID] = errorMessage
            message = errorMessage
            return false
        }
    }

    func autoSwitchIfNeeded(hourlyThresholdPercent: Double, weeklyThresholdPercent: Double) async -> AccountRecord? {
        guard !accounts.isEmpty, !isRefreshing, !isAddingAccount else { return nil }
        syncCurrentAccountFromDisk()
        guard let currentID = currentAccountID else { return nil }

        let didRefresh = await refresh(accountID: currentID, showProgress: false)
        guard didRefresh,
              let current = accounts.first(where: { $0.id == currentID }) else {
            return nil
        }

        let currentHourlyRemaining = current.hourlyRemainingPercent
        let currentWeeklyRemaining = current.weeklyRemainingPercent
        let hourlyTriggered = shouldAutoSwitch(remaining: currentHourlyRemaining, threshold: hourlyThresholdPercent)
        let weeklyTriggered = shouldAutoSwitch(remaining: currentWeeklyRemaining, threshold: weeklyThresholdPercent)
        guard hourlyTriggered || weeklyTriggered else { return nil }

        let candidates = accounts
            .filter { $0.id != currentID && $0.hourlyRemainingPercent != nil && $0.weeklyRemainingPercent != nil }
            .sorted(by: isBetterAutoSwitchCandidate)

        guard let target = candidates.first,
              isBetterSwitchTarget(target, than: current) else {
            message = "当前账号额度较低，但没有可切换的更合适账号。"
            return nil
        }

        await switchToAccount(target.id)
        message = "已自动切换到 \(target.email)，请重启 Codex 应用。"
        return accounts.first(where: { $0.id == target.id }) ?? target
    }

    func deleteAccount(_ id: String) async {
        do {
            let url = accountsDirectory.appendingPathComponent("\(id).json")
            try? FileManager.default.removeItem(at: url)
            accounts = try loadAccounts()
            currentAccountID = try readCurrentAccountID()
            message = "已删除账号。"
        } catch {
            message = error.localizedDescription
        }
    }

    func syncCurrentAccountFromDisk() {
        do {
            currentAccountID = try readCurrentAccountID()
        } catch {
            message = error.localizedDescription
        }
    }

    private func ensureDirectories() throws {
        try migrateLegacyAppSupportDirectoryIfNeeded()
        try FileManager.default.createDirectory(at: accountsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pendingAddDirectory, withIntermediateDirectories: true)
    }

    private func migrateLegacyAppSupportDirectoryIfNeeded() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyAppSupportDirectory.path),
              !fileManager.fileExists(atPath: appSupportDirectory.path) else {
            return
        }
        try fileManager.moveItem(at: legacyAppSupportDirectory, to: appSupportDirectory)
    }

    private func loadAccounts() throws -> [AccountRecord] {
        guard FileManager.default.fileExists(atPath: accountsDirectory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: accountsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        return try urls.map { url in
            try decoder.decode(AccountRecord.self, from: Data(contentsOf: url))
        }.sorted { $0.email.localizedCaseInsensitiveCompare($1.email) == .orderedAscending }
    }

    private func readAuth(from url: URL) throws -> AuthFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppError.missingAuth
        }
        let auth = try JSONDecoder().decode(AuthFile.self, from: Data(contentsOf: url))
        guard auth.authMode == "chatgpt" else {
            throw AppError.invalidAuth("当前 auth_mode 不是 chatgpt，无法作为 Codex ChatGPT 账号导入。")
        }
        guard auth.tokens?.accountID != nil, auth.tokens?.accessToken != nil, auth.tokens?.refreshToken != nil else {
            throw AppError.invalidAuth("auth.json 缺少必要 token 字段。")
        }
        return auth
    }

    private func makeAccountRecord(from auth: AuthFile, existing: AccountRecord?) throws -> AccountRecord {
        guard let accountID = auth.tokens?.accountID else {
            throw AppError.invalidAuth("auth.json 缺少 account_id。")
        }
        let payload = JWT.decode(auth.tokens?.idToken)
        return AccountRecord(
            id: accountID,
            email: payload?.email ?? existing?.email ?? accountID,
            name: payload?.name ?? existing?.name ?? "",
            importedAt: existing?.importedAt ?? Date(),
            lastUsageRefresh: existing?.lastUsageRefresh,
            auth: auth,
            usage: existing?.usage
        )
    }

    private func shouldAutoSwitch(remaining: Double?, threshold: Double) -> Bool {
        guard let remaining else { return false }
        return remaining <= threshold
    }

    private func isBetterSwitchTarget(_ target: AccountRecord, than current: AccountRecord) -> Bool {
        let targetWeekly = target.weeklyRemainingPercent ?? -1
        let currentWeekly = current.weeklyRemainingPercent ?? -1
        let targetHourly = target.hourlyRemainingPercent ?? -1
        let currentHourly = current.hourlyRemainingPercent ?? -1
        return targetWeekly > currentWeekly || targetHourly > currentHourly
    }

    private func isBetterAutoSwitchCandidate(_ lhs: AccountRecord, than rhs: AccountRecord) -> Bool {
        let lhsWeeklyReset = lhs.weeklyResetAt ?? .greatestFiniteMagnitude
        let rhsWeeklyReset = rhs.weeklyResetAt ?? .greatestFiniteMagnitude
        if lhsWeeklyReset != rhsWeeklyReset {
            return lhsWeeklyReset < rhsWeeklyReset
        }

        let lhsWeeklyRemaining = lhs.weeklyRemainingPercent ?? -1
        let rhsWeeklyRemaining = rhs.weeklyRemainingPercent ?? -1
        if lhsWeeklyRemaining != rhsWeeklyRemaining {
            return lhsWeeklyRemaining > rhsWeeklyRemaining
        }

        let lhsHourlyRemaining = lhs.hourlyRemainingPercent ?? -1
        let rhsHourlyRemaining = rhs.hourlyRemainingPercent ?? -1
        if lhsHourlyRemaining != rhsHourlyRemaining {
            return lhsHourlyRemaining > rhsHourlyRemaining
        }

        return (lhs.lastUsageRefresh ?? .distantPast) < (rhs.lastUsageRefresh ?? .distantPast)
    }

    private func save(_ account: AccountRecord) throws {
        let url = accountsDirectory.appendingPathComponent("\(account.id).json")
        let tmp = accountsDirectory.appendingPathComponent("\(account.id).json.\(ProcessInfo.processInfo.processIdentifier).tmp")
        try encoder.encode(account).write(to: tmp, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    private func writeAuth(_ auth: AuthFile, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = url.deletingLastPathComponent().appendingPathComponent("auth.json.\(ProcessInfo.processInfo.processIdentifier).tmp")
        try encoder.encode(auth).write(to: tmp, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    private func resetPendingAddDirectory() throws {
        if FileManager.default.fileExists(atPath: pendingAddDirectory.path) {
            try FileManager.default.removeItem(at: pendingAddDirectory)
        }
        try FileManager.default.createDirectory(at: pendingAddDirectory, withIntermediateDirectories: true)
    }

    private func readCurrentAccountID() throws -> String? {
        guard FileManager.default.fileExists(atPath: codexAuthURL.path) else { return nil }
        let auth = try? JSONDecoder().decode(AuthFile.self, from: Data(contentsOf: codexAuthURL))
        return auth?.tokens?.accountID
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }

    private func uniqueBackupURL() -> URL {
        let baseName = "auth-\(timestamp())"
        var candidate = backupsDirectory.appendingPathComponent("\(baseName).json")
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = backupsDirectory.appendingPathComponent("\(baseName)-\(index).json")
            index += 1
        }
        return candidate
    }
}

private extension AccountRecord {
    var hourlyRemainingPercent: Double? {
        remainingPercent(for: usage?.rateLimit?.primaryWindow)
    }

    var weeklyRemainingPercent: Double? {
        remainingPercent(for: usage?.rateLimit?.secondaryWindow)
    }

    var weeklyResetAt: Double? {
        usage?.rateLimit?.secondaryWindow?.resetAt
    }

    private func remainingPercent(for window: UsageWindow?) -> Double? {
        guard let used = window?.usedPercent else { return nil }
        return min(max(100 - used, 0), 100)
    }
}

private struct RefreshAllResult: Sendable {
    var accountID: String
    var outcome: RefreshAllOutcome
}

private enum RefreshAllOutcome: Sendable {
    case success(UsageResult)
    case failure(String)
}
