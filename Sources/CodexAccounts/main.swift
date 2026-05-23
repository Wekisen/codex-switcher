import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var autoSwitchTask: Task<Void, Never>?
    private let popover = NSPopover()
    private let store = AccountStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let contentView = AccountPanelView(store: store)
            .frame(width: 500, height: 560)

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 500, height: 560)
        popover.contentViewController = NSHostingController(rootView: contentView)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        requestNotificationPermission()
        Task { await store.load() }
        startAutoSwitchMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        autoSwitchTask?.cancel()
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }
        togglePopover(sender)
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.settings, action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.quit, action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettingsFromMenu() {
        showPopoverIfNeeded()
        NotificationCenter.default.post(name: .codexSwitcherOpenSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            NotificationCenter.default.post(name: .codexSwitcherPanelWillClose, object: nil)
            popover.performClose(sender)
        } else {
            showPopoverIfNeeded()
        }
    }

    private func showPopoverIfNeeded() {
        guard let button = statusItem?.button else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()

        if AppSettings.shared.autoRefreshOnOpen {
            Task { await store.refreshOnOpen() }
        } else {
            store.syncCurrentAccountFromDisk()
        }
    }

    func popoverWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .codexSwitcherPanelWillClose, object: nil)
    }

    private func startAutoSwitchMonitor() {
        autoSwitchTask?.cancel()
        autoSwitchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let self else { return }

                let settings = AppSettings.shared
                guard settings.autoSwitchAccounts else { continue }

                if let account = await store.autoSwitchIfNeeded(
                    hourlyThresholdPercent: settings.autoSwitchHourlyThresholdPercent,
                    weeklyThresholdPercent: settings.autoSwitchWeeklyThresholdPercent
                ) {
                    Self.sendSwitchNotification(account: account)
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func menuBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
        let image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Codex Switcher")
        image?.isTemplate = true
        return image?.withSymbolConfiguration(configuration)
    }

    private static func sendSwitchNotification(account: AccountRecord) {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationTitle()
        content.body = L10n.notificationBody(account.email)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex-switcher-auto-switch-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
