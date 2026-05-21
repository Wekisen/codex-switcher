import SwiftUI

extension Notification.Name {
    static let codexSwitcherPanelWillClose = Notification.Name("codexSwitcherPanelWillClose")
}

struct AccountPanelView: View {
    @ObservedObject var store: AccountStore
    @State private var showSettings = false
    @State private var detailAccount: AccountRecord?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                accountList
                Divider()
                footer
            }
            .blur(radius: activeOverlay == nil ? 0 : 1.5)

            if let account = detailAccount {
                VisualEffectBlur()
                    .ignoresSafeArea()
                    .onTapGesture {
                        detailAccount = nil
                    }

                AccountDetailView(
                    account: latestAccount(account),
                    isRefreshing: store.refreshingAccountIDs.contains(account.id),
                    onRefresh: { Task { await store.refresh(accountID: account.id) } },
                    onDelete: {
                        detailAccount = nil
                        Task { await store.deleteAccount(account.id) }
                    },
                    onClose: { detailAccount = nil }
                )
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if showSettings {
                VisualEffectBlur()
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSettings = false
                    }

                SettingsView(onClose: { showSettings = false })
                    .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.16), value: activeOverlay)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .codexSwitcherPanelWillClose)) { _ in
            detailAccount = nil
            showSettings = false
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Switcher")
                    .font(.headline)
                Text(currentLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                Task { await store.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(store.accounts.isEmpty || store.isRefreshing)
            .help("刷新全部")
        }
        .padding(14)
    }

    private var accountList: some View {
        Group {
            if store.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("还没有账号")
                        .font(.headline)
                    Text("点击下方“添加账号”，按提示完成登录。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.accounts) { account in
                            CompactAccountCard(
                                account: account,
                                isCurrent: account.id == store.currentAccountID,
                                isRefreshing: store.refreshingAccountIDs.contains(account.id),
                                refreshError: store.refreshFailures[account.id],
                                onSwitch: { Task { await store.switchToAccount(account.id) } },
                                onRefresh: { Task { await store.refresh(accountID: account.id) } },
                                onDetails: { detailAccount = account },
                                onDelete: { Task { await store.deleteAccount(account.id) } }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let message = store.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if store.isAddingAccount {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("等待浏览器授权")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await store.cancelAddAccount() }
                    } label: {
                        Label("取消", systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        Task { await store.beginAddAccount() }
                    } label: {
                        Label("添加账号", systemImage: "person.crop.circle.badge.plus")
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                }
            }
        }
        .padding(12)
    }

    private var currentLabel: String {
        guard let id = store.currentAccountID else { return "当前 Codex 账号：未检测到" }
        if let account = store.accounts.first(where: { $0.id == id }) {
            return "当前 Codex 账号：\(account.email)"
        }
        return "当前 Codex 账号：未导入"
    }

    private func latestAccount(_ account: AccountRecord) -> AccountRecord {
        store.accounts.first(where: { $0.id == account.id }) ?? account
    }

    private var activeOverlay: String? {
        if detailAccount != nil { return "detail" }
        if showSettings { return "settings" }
        return nil
    }
}

private struct CompactAccountCard: View {
    var account: AccountRecord
    var isCurrent: Bool
    var isRefreshing: Bool
    var refreshError: String?
    var onSwitch: () -> Void
    var onRefresh: () -> Void
    var onDetails: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onSwitch) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(account.email)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(account.usage?.planType?.uppercased() ?? "-")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        CompactUsageBar(label: "时", window: account.usage?.rateLimit?.primaryWindow)
                        CompactUsageBar(
                            label: "周", window: account.usage?.rateLimit?.secondaryWindow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack(spacing: 4) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        IconButton(
                            systemName: refreshError == nil
                                ? "arrow.clockwise" : "exclamationmark.arrow.triangle.2.circlepath",
                            help: refreshError.map { "刷新失败：\($0)" } ?? "刷新",
                            tint: refreshError == nil ? nil : .red
                        ) {
                            onRefresh()
                        }
                    }
                    IconButton(systemName: "info.circle", help: "查看详情") {
                        onDetails()
                    }
                    IconButton(systemName: "trash", help: "删除", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isCurrent ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isCurrent
                        ? Color.accentColor.opacity(0.55)
                        : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

private struct CompactUsageBar: View {
    var label: String
    var window: UsageWindow?

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(progressColor)
                .frame(width: 74)
            Text(valueText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 34, alignment: .trailing)
            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: Double {
        remainingRatio
    }

    private var progressColor: Color {
        if progress <= 0.15 { return .red }
        if progress <= 0.35 { return .orange }
        return .accentColor
    }

    private var remainingRatio: Double {
        guard let used = window?.usedPercent else { return 0 }
        return min(max((100 - used) / 100, 0), 1)
    }

    private var valueText: String {
        guard let value = window?.usedPercent else { return "-" }
        return "\(Int(max(0, 100 - value).rounded()))%"
    }

    private var resetText: String {
        guard let resetAt = window?.resetAt else { return "未刷新" }
        return Date(timeIntervalSince1970: resetAt).compactMonthDayTime
    }
}

private struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("开机自启动", isOn: $settings.launchAtLogin)
                Toggle("唤起面板时自动刷新", isOn: $settings.autoRefreshOnOpen)
                HStack(alignment: .center, spacing: 1) {
                    Toggle("自动切换账号", isOn: $settings.autoSwitchAccounts)
                        .fixedSize()
                    HelpIcon(
                        text:
                            "开启后，应用会每分钟刷新当前账号用量；当小时或周剩余额度低于阈值时，自动切换到更合适的账号并提醒重启 Codex。候选账号需同时高于小时和周阈值，并优先选择周额度更早刷新的账号。"
                    )
                }
                if settings.autoSwitchAccounts {
                    VStack(alignment: .leading, spacing: 6) {
                        thresholdField(
                            "时低于", text: $settings.autoSwitchHourlyThreshold, placeholder: "5")
                        thresholdField(
                            "周低于", text: $settings.autoSwitchWeeklyThreshold, placeholder: "0")
                    }
                    .font(.caption)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("使用自定义代理", isOn: $settings.useCustomProxy)
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        proxyField("地址") {
                            TextField("127.0.0.1", text: $settings.proxyHost)
                                .textFieldStyle(.roundedBorder)
                        }
                        proxyField("端口") {
                            TextField("7890", text: $settings.proxyPort)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 12) {
                        proxyField("用户名") {
                            TextField("可选", text: $settings.proxyUsername)
                                .textFieldStyle(.roundedBorder)
                        }
                        proxyField("密码") {
                            SecureField("可选", text: $settings.proxyPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .disabled(!settings.useCustomProxy)
                if let message = settings.proxyStatusMessage {
                    ProxyStatusView(status: settings.proxyStatus, message: message)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("关于")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Codex Switcher")
                        .font(.title3.weight(.semibold))
                    Text("一个用于管理和切换多个 Codex / ChatGPT 账号的 macOS 菜单栏工具。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("版本 0.1.1")
                    Text("作者：@Wekisen")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func thresholdField(_ title: String, text: Binding<String>, placeholder: String)
        -> some View
    {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
            Text("% 时切换")
                .foregroundStyle(.secondary)
        }
    }

    private func proxyField<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HelpIcon: View {
    var text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 13, height: 16)
        }
        .buttonStyle(.plain)
        .onReceive(NotificationCenter.default.publisher(for: .codexSwitcherPanelWillClose)) { _ in
            isPresented = false
        }
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(12)
        }
    }
}

private struct ProxyStatusView: View {
    var status: ProxyConnectionStatus
    var message: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 1)
    }

    private var color: Color {
        switch status {
        case .connected:
            return .green
        case .failed:
            return .red
        case .checking:
            return .yellow
        case .disabled:
            return .secondary
        }
    }
}

private struct IconButton: View {
    var systemName: String
    var help: String
    var role: ButtonRole?
    var tint: Color?
    var action: () -> Void

    init(
        systemName: String, help: String, role: ButtonRole? = nil, tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.role = role
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? .primary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct AccountDetailView: View {
    var account: AccountRecord
    var isRefreshing: Bool
    var onRefresh: () -> Void
    var onDelete: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.email)
                        .font(.headline)
                    if !account.name.isEmpty {
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(account.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help("刷新")
                }
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            VStack(alignment: .leading, spacing: 10) {
                DetailUsage(title: "小时用量", window: account.usage?.rateLimit?.primaryWindow)
                DetailUsage(title: "周用量", window: account.usage?.rateLimit?.secondaryWindow)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Plan").foregroundStyle(.secondary)
                    Text(account.usage?.planType ?? "-")
                }
                GridRow {
                    Text("Account ID").foregroundStyle(.secondary)
                    Text(account.id).textSelection(.enabled)
                }
                GridRow {
                    Text("Last Refresh").foregroundStyle(.secondary)
                    Text(account.lastUsageRefresh?.compactMonthDayTime ?? "-")
                }
            }
            .font(.caption)

            HStack {
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 30)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(18)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct DetailUsage: View {
    var title: String
    var window: UsageWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
            }
            ProgressView(value: remainingRatio)
                .tint(progressColor)
            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var valueText: String {
        guard let value = window?.usedPercent else { return "-" }
        return "\(Int(max(0, 100 - value).rounded()))% remaining"
    }

    private var remainingRatio: Double {
        guard let used = window?.usedPercent else { return 0 }
        return min(max((100 - used) / 100, 0), 1)
    }

    private var resetText: String {
        guard let resetAt = window?.resetAt else { return "reset -" }
        return "Reset \(Date(timeIntervalSince1970: resetAt).compactMonthDayTime)"
    }

    private var progressColor: Color {
        guard let used = window?.usedPercent else { return .accentColor }
        let remaining = max(0, 100 - used)
        if remaining <= 15 { return .red }
        if remaining <= 35 { return .orange }
        return .accentColor
    }
}

extension Date {
    fileprivate var compactMonthDayTime: String {
        formatted(
            .dateTime
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
