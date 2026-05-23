import Foundation

enum L10n {
    private static var currentLanguage: AppLanguage {
        AppLanguage.savedOrSystemDefault()
    }

    static var addAccount: String { text(en: "Add Account", zh: "添加账号") }
    static var accountID: String { text(en: "Account ID", zh: "账号 ID") }
    static var appDescription: String {
        text(
            en: "A macOS menu bar app for managing and switching multiple Codex / ChatGPT accounts.",
            zh: "一个用于管理和切换多个 Codex / ChatGPT 账号的 macOS 菜单栏工具。"
        )
    }
    static var about: String { text(en: "About", zh: "关于") }
    static var authMissing: String {
        text(
            en: "Could not find ~/.codex/auth.json. Run codex login first.",
            zh: "没有找到 ~/.codex/auth.json，请先运行 codex login。"
        )
    }
    static var autoRefreshOnOpen: String { text(en: "Auto-refresh when opening panel", zh: "唤起面板时自动刷新") }
    static var autoSwitchAccounts: String { text(en: "Auto-switch accounts", zh: "自动切换账号") }
    static var autoSwitchHelp: String {
        text(
            en: "When enabled, the app refreshes the current account every minute. If hourly or weekly remaining quota falls below the threshold, it switches to a better account and reminds you to restart Codex. Candidate accounts must be above both thresholds, with earlier weekly resets preferred.",
            zh: "开启后，应用会每分钟刷新当前账号用量；当小时或周剩余额度低于阈值时，自动切换到更合适的账号并提醒重启 Codex。候选账号需同时高于小时和周阈值，并优先选择周额度更早刷新的账号。"
        )
    }
    static var autoSwitchNoTarget: String {
        text(
            en: "Current account quota is low, but no better account is available.",
            zh: "当前账号额度较低，但没有可切换的更合适账号。"
        )
    }
    static var authorizationFailed: String { text(en: "Authorization Failed", zh: "授权失败") }
    static var authorizationSucceeded: String { text(en: "Authorization Successful", zh: "授权成功") }
    static var author: String { text(en: "Author: @Wekisen", zh: "作者：@Wekisen") }
    static var cancel: String { text(en: "Cancel", zh: "取消") }
    static var close: String { text(en: "Close", zh: "关闭") }
    static var currentAccountImportedMissing: String {
        text(en: "Current Codex account: not imported", zh: "当前 Codex 账号：未导入")
    }
    static var currentAccountMissing: String {
        text(en: "Current Codex account: not detected", zh: "当前 Codex 账号：未检测到")
    }
    static var delete: String { text(en: "Delete", zh: "删除") }
    static var details: String { text(en: "Details", zh: "查看详情") }
    static var devModeLaunchAtLoginUnavailable: String {
        text(
            en: "Running in development mode. Package the app as .app before enabling launch at login.",
            zh: "当前是开发运行模式。请先打包成 .app 后再开启开机自启动。"
        )
    }
    static var closeBrowserWindow: String {
        text(
            en: "You can close this window and return to Codex Switcher.",
            zh: "你可以关闭此窗口并返回 Codex Switcher。"
        )
    }
    static var emptyAccounts: String { text(en: "No Accounts Yet", zh: "还没有账号") }
    static var emptyAccountsHelp: String {
        text(
            en: "Click Add Account below and follow the login prompts.",
            zh: "点击下方“添加账号”，按提示完成登录。"
        )
    }
    static var general: String { text(en: "General", zh: "通用") }
    static var hourShort: String { text(en: "Hr", zh: "时") }
    static var hourlyUsage: String { text(en: "Hourly Usage", zh: "小时用量") }
    static var host: String { text(en: "Host", zh: "地址") }
    static var language: String { text(en: "Language", zh: "语言") }
    static var lastRefresh: String { text(en: "Last Refresh", zh: "上次刷新") }
    static var launchAtLogin: String { text(en: "Launch at login", zh: "开机自启动") }
    static var launchAtLoginDisabled: String { text(en: "Launch at login disabled.", zh: "已关闭开机自启动。") }
    static var launchAtLoginEnabled: String { text(en: "Launch at login enabled.", zh: "已开启开机自启动。") }
    static var noRefresh: String { text(en: "Not refreshed", zh: "未刷新") }
    static var network: String { text(en: "Network", zh: "网络") }
    static var optional: String { text(en: "Optional", zh: "可选") }
    static var password: String { text(en: "Password", zh: "密码") }
    static var port: String { text(en: "Port", zh: "端口") }
    static var plan: String { text(en: "Plan", zh: "套餐") }
    static var proxyChecking: String { text(en: "Checking proxy...", zh: "正在检测代理...") }
    static var proxyConnected: String { text(en: "Proxy is reachable.", zh: "代理可连接。") }
    static var proxyDisabled: String { text(en: "Custom proxy is disabled.", zh: "未启用自定义代理。") }
    static var proxyFailed: String {
        text(en: "Proxy is unreachable. Check the host and port.", zh: "代理不可连接，请检查地址和端口。")
    }
    static var proxyIncomplete: String { text(en: "Proxy configuration is incomplete.", zh: "代理配置不完整。") }
    static var quit: String { text(en: "Quit", zh: "退出") }
    static var refresh: String { text(en: "Refresh", zh: "刷新") }
    static var refreshAll: String { text(en: "Refresh All", zh: "刷新全部") }
    static var settings: String { text(en: "Settings", zh: "设置") }
    static var username: String { text(en: "Username", zh: "用户名") }
    static var useCustomProxy: String { text(en: "Use custom proxy", zh: "使用自定义代理") }
    static var verify: String { text(en: "Verify", zh: "验证") }
    static var verifyHelp: String {
        text(
            en: "Authentication expired. Verify this account to update its tokens.",
            zh: "授权已失效。验证此账号以更新 token。"
        )
    }
    static var version: String { text(en: "Version 0.1.2", zh: "版本 0.1.2") }
    static var waitingForBrowserAuth: String { text(en: "Waiting for browser authorization", zh: "等待浏览器授权") }
    static var weekShort: String { text(en: "Wk", zh: "周") }
    static var weeklyUsage: String { text(en: "Weekly Usage", zh: "周用量") }

    static func notificationTitle() -> String {
        text(en: "Codex Account Switched", zh: "Codex 账号已切换")
    }

    static func notificationBody(_ email: String) -> String {
        format(en: "Switched to %@. Restart Codex.", zh: "已切换到 %@。请重启 Codex 应用。", email)
    }

    static func accountAdded(_ email: String) -> String {
        format(en: "Added %@.", zh: "已添加 %@。", email)
    }

    static func accountDeleted() -> String {
        text(en: "Account deleted.", zh: "已删除账号。")
    }

    static func accountRefreshed(_ email: String) -> String {
        format(en: "Refreshed %@.", zh: "已刷新 %@。", email)
    }

    static func accountVerified(_ email: String) -> String {
        format(en: "Verified %@.", zh: "已验证 %@。", email)
    }

    static func alreadyCurrentAccount(_ email: String) -> String {
        format(en: "Already using %@.", zh: "当前已是 %@。", email)
    }

    static func authModeUnsupported() -> String {
        text(
            en: "Current auth_mode is not chatgpt, so it cannot be imported as a Codex ChatGPT account.",
            zh: "当前 auth_mode 不是 chatgpt，无法作为 Codex ChatGPT 账号导入。"
        )
    }

    static func autoSwitched(_ email: String) -> String {
        format(en: "Auto-switched to %@. Restart Codex.", zh: "已自动切换到 %@，请重启 Codex 应用。", email)
    }

    static func cancelledAddAccount() -> String {
        text(en: "Canceled adding account.", zh: "已取消添加账号。")
    }

    static func currentAccount(_ email: String) -> String {
        format(en: "Current Codex account: %@", zh: "当前 Codex 账号：%@", email)
    }

    static func httpNoResponse() -> String {
        text(en: "No HTTP response received.", zh: "没有收到 HTTP 响应。")
    }

    static func launchAtLoginFailed(_ message: String) -> String {
        format(en: "Failed to update launch at login: %@", zh: "开机自启动设置失败：%@", message)
    }

    static func missingAccountID() -> String {
        text(en: "auth.json is missing account_id.", zh: "auth.json 缺少 account_id。")
    }

    static func missingAuthFields() -> String {
        text(en: "auth.json is missing required token fields.", zh: "auth.json 缺少必要 token 字段。")
    }

    static func missingRefreshToken() -> String {
        text(en: "Missing refresh_token.", zh: "缺少 refresh_token。")
    }

    static func oauthCallbackFailed(_ message: String) -> String {
        format(en: "OAuth local callback service failed: %@", zh: "OAuth 本地回调服务失败：%@", message)
    }

    static func oauthMissingAccountID() -> String {
        text(en: "Could not find ChatGPT account id in OAuth token.", zh: "OAuth token 中没有找到 ChatGPT account id。")
    }

    static func oauthMissingCode() -> String {
        text(en: "OAuth callback is missing authorization code.", zh: "OAuth 回调缺少授权码。")
    }

    static func oauthInvalidCallbackRequest() -> String {
        text(en: "Invalid callback request", zh: "无效的回调请求")
    }

    static func oauthInvalidState() -> String {
        text(en: "Invalid state", zh: "无效的 state")
    }

    static func oauthNoResponse() -> String {
        text(en: "OAuth token exchange did not receive an HTTP response.", zh: "OAuth token exchange 没有收到 HTTP 响应。")
    }

    static func oauthStateFailed() -> String {
        text(en: "OAuth state validation failed.", zh: "OAuth state 校验失败。")
    }

    static func oauthUnknownCallbackPath() -> String {
        text(en: "Unknown callback path", zh: "未知的回调路径")
    }

    static func openedBrowserForAdd() -> String {
        text(en: "Opened browser authorization page. Waiting for login callback.", zh: "已打开浏览器授权页，等待登录回调。")
    }

    static func openedBrowserForVerification(_ email: String) -> String {
        format(en: "Opened browser authorization page for %@.", zh: "已打开 %@ 的浏览器验证页。", email)
    }

    static func partialRefreshFailed(_ messages: String) -> String {
        format(en: "Some accounts failed to refresh: %@", zh: "部分账号刷新失败：%@", messages)
    }

    static func refreshAllSucceeded() -> String {
        text(en: "Refreshed all accounts.", zh: "已刷新全部账号。")
    }

    static func refreshFailed(_ message: String) -> String {
        format(en: "Refresh failed: %@", zh: "刷新失败：%@", message)
    }

    static func remainingPercent(_ value: Int) -> String {
        format(en: "%d%% remaining", zh: "剩余 %d%%", value)
    }

    static func resetAt(_ value: String) -> String {
        format(en: "Reset %@", zh: "%@ 重置", value)
    }

    static func switchToAccount(_ email: String) -> String {
        format(en: "Switched to %@.", zh: "已切换到 %@。", email)
    }

    static func switchThresholdSuffix() -> String {
        text(en: "% then switch", zh: "% 时切换")
    }

    static func thresholdHourly() -> String {
        text(en: "Hour below", zh: "时低于")
    }

    static func thresholdWeekly() -> String {
        text(en: "Week below", zh: "周低于")
    }

    static func verifyWrongAccount(expected: String, actual: String) -> String {
        format(
            en: "Verification returned %@, but this card is for %@.",
            zh: "验证返回的是 %@，但当前卡片账号是 %@。",
            actual,
            expected
        )
    }

    static func text(en: String, zh: String) -> String {
        currentLanguage == .simplifiedChinese ? zh : en
    }

    private static func format(en: String, zh: String, _ args: CVarArg...) -> String {
        String(format: text(en: en, zh: zh), arguments: args)
    }
}
