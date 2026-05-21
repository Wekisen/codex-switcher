import Foundation
import Network
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }
    @Published var autoRefreshOnOpen: Bool {
        didSet { UserDefaults.standard.set(autoRefreshOnOpen, forKey: Keys.autoRefreshOnOpen) }
    }
    @Published var autoSwitchAccounts: Bool {
        didSet { UserDefaults.standard.set(autoSwitchAccounts, forKey: Keys.autoSwitchAccounts) }
    }
    @Published var autoSwitchHourlyThreshold: String {
        didSet { UserDefaults.standard.set(autoSwitchHourlyThreshold, forKey: Keys.autoSwitchHourlyThreshold) }
    }
    @Published var autoSwitchWeeklyThreshold: String {
        didSet { UserDefaults.standard.set(autoSwitchWeeklyThreshold, forKey: Keys.autoSwitchWeeklyThreshold) }
    }
    @Published var useCustomProxy: Bool {
        didSet {
            UserDefaults.standard.set(useCustomProxy, forKey: Keys.useCustomProxy)
            scheduleProxyStatusUpdate()
        }
    }
    @Published var proxyHost: String {
        didSet {
            UserDefaults.standard.set(proxyHost, forKey: Keys.proxyHost)
            scheduleProxyStatusUpdate()
        }
    }
    @Published var proxyPort: String {
        didSet {
            UserDefaults.standard.set(proxyPort, forKey: Keys.proxyPort)
            scheduleProxyStatusUpdate()
        }
    }
    @Published var proxyUsername: String {
        didSet {
            UserDefaults.standard.set(proxyUsername, forKey: Keys.proxyUsername)
            scheduleProxyStatusUpdate()
        }
    }
    @Published var proxyPassword: String {
        didSet {
            UserDefaults.standard.set(proxyPassword, forKey: Keys.proxyPassword)
            scheduleProxyStatusUpdate()
        }
    }
    @Published var lastSettingsMessage: String?
    @Published var proxyStatusMessage: String?
    @Published var proxyStatus: ProxyConnectionStatus = .disabled

    private var isApplyingLaunchAtLoginChange = false
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let autoRefreshOnOpen = "autoRefreshOnOpen"
        static let autoSwitchAccounts = "autoSwitchAccounts"
        static let autoSwitchHourlyThreshold = "autoSwitchHourlyThreshold"
        static let autoSwitchWeeklyThreshold = "autoSwitchWeeklyThreshold"
        static let useCustomProxy = "useCustomProxy"
        static let proxyHost = "proxyHost"
        static let proxyPort = "proxyPort"
        static let proxyUsername = "proxyUsername"
        static let proxyPassword = "proxyPassword"
    }

    private var proxyStatusTask: Task<Void, Never>?

    private init() {
        if Bundle.main.bundleURL.pathExtension == "app" {
            let enabled = SMAppService.mainApp.status == .enabled
            launchAtLogin = enabled
            UserDefaults.standard.set(enabled, forKey: Keys.launchAtLogin)
        } else {
            launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        }
        autoRefreshOnOpen = UserDefaults.standard.bool(forKey: Keys.autoRefreshOnOpen)
        autoSwitchAccounts = UserDefaults.standard.bool(forKey: Keys.autoSwitchAccounts)
        autoSwitchHourlyThreshold = UserDefaults.standard.string(forKey: Keys.autoSwitchHourlyThreshold)
            ?? UserDefaults.standard.string(forKey: "autoSwitchThreshold")
            ?? "5"
        autoSwitchWeeklyThreshold = UserDefaults.standard.string(forKey: Keys.autoSwitchWeeklyThreshold) ?? "0"
        useCustomProxy = UserDefaults.standard.bool(forKey: Keys.useCustomProxy)
        proxyHost = UserDefaults.standard.string(forKey: Keys.proxyHost) ?? "127.0.0.1"
        proxyPort = UserDefaults.standard.string(forKey: Keys.proxyPort) ?? "7890"
        proxyUsername = UserDefaults.standard.string(forKey: Keys.proxyUsername) ?? ""
        proxyPassword = UserDefaults.standard.string(forKey: Keys.proxyPassword) ?? ""
        scheduleProxyStatusUpdate()
    }

    private func updateLaunchAtLogin() {
        guard !isApplyingLaunchAtLoginChange else { return }
        UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)

        guard Bundle.main.bundleURL.pathExtension == "app" else {
            lastSettingsMessage = "当前是开发运行模式。请先打包成 .app 后再开启开机自启动。"
            return
        }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                lastSettingsMessage = "已开启开机自启动。"
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                lastSettingsMessage = "已关闭开机自启动。"
            }
            syncLaunchAtLoginState()
        } catch {
            lastSettingsMessage = "开机自启动设置失败：\(error.localizedDescription)"
            syncLaunchAtLoginState()
        }
    }

    private func syncLaunchAtLoginState() {
        let enabled = SMAppService.mainApp.status == .enabled
        isApplyingLaunchAtLoginChange = true
        launchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.launchAtLogin)
        isApplyingLaunchAtLoginChange = false
    }

    var autoSwitchHourlyThresholdPercent: Double {
        percent(from: autoSwitchHourlyThreshold)
    }

    var autoSwitchWeeklyThresholdPercent: Double {
        percent(from: autoSwitchWeeklyThreshold)
    }

    private func percent(from text: String) -> Double {
        let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return min(max(value, 0), 100)
    }

    func scheduleProxyStatusUpdate() {
        proxyStatusTask?.cancel()

        guard useCustomProxy else {
            proxyStatus = .disabled
            proxyStatusMessage = "未启用自定义代理。"
            return
        }

        let host = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = proxyPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let port = UInt16(portText), port > 0 else {
            proxyStatus = .failed
            proxyStatusMessage = "代理配置不完整。"
            return
        }

        proxyStatus = .checking
        proxyStatusMessage = "正在检测代理..."
        proxyStatusTask = Task { [host, port] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let reachable = await Self.checkTCPConnection(host: host, port: port)
            guard !Task.isCancelled else { return }
            proxyStatus = reachable ? .connected : .failed
            proxyStatusMessage = reachable ? "代理可连接。" : "代理不可连接，请检查地址和端口。"
        }
    }

    private static func checkTCPConnection(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let probe = TCPProbe(connection: connection, continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    probe.finish(true)
                case .failed, .cancelled:
                    probe.finish(false)
                default:
                    break
                }
            }

            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                probe.finish(false)
            }
        }
    }
}

enum ProxyConnectionStatus {
    case disabled
    case checking
    case connected
    case failed
}

private final class TCPProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let connection: NWConnection
    private let continuation: CheckedContinuation<Bool, Never>

    init(connection: NWConnection, continuation: CheckedContinuation<Bool, Never>) {
        self.connection = connection
        self.continuation = continuation
    }

    func finish(_ result: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        connection.cancel()
        continuation.resume(returning: result)
    }
}

enum ProxySettings {
    static var customProxy: (host: String, port: Int, username: String?, password: String?)? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "useCustomProxy") else { return nil }
        let host = defaults.string(forKey: "proxyHost")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let portString = defaults.string(forKey: "proxyPort")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let username = defaults.string(forKey: "proxyUsername")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = defaults.string(forKey: "proxyPassword") ?? ""
        guard !host.isEmpty, let port = Int(portString), port > 0 else { return nil }
        return (host, port, username.isEmpty ? nil : username, password.isEmpty ? nil : password)
    }
}
