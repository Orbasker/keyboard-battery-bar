import AppKit
import IOKit.hid
import UserNotifications

enum BatteryState {
    case level(name: String, percent: Int)
    case notConnected
    case permissionDenied
}

enum BatteryReader {
    static let usagePage = 0x06
    static let usage = 0x20

    static var hasAccess: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }

    static func requestAccessIfNeeded() {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
    }

    static func read(nameFilter: String) -> BatteryState {
        guard hasAccess else { return .permissionDenied }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return .notConnected }

        var blocked = false
        for device in devices {
            guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String,
                  name.localizedCaseInsensitiveContains(nameFilter) else { continue }
            let criteria: [String: Any] = [kIOHIDElementUsagePageKey: usagePage, kIOHIDElementUsageKey: usage]
            guard let elements = IOHIDDeviceCopyMatchingElements(device, criteria as CFDictionary, 0) as? [IOHIDElement],
                  let element = elements.first else { continue }

            guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                blocked = true
                continue
            }
            defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

            let reportID = IOHIDElementGetReportID(element)
            var buffer = [UInt8](repeating: 0, count: 8)
            var length = buffer.count
            guard IOHIDDeviceGetReport(device, kIOHIDReportTypeInput, CFIndex(reportID), &buffer, &length) == kIOReturnSuccess,
                  length > 0 else { continue }
            let payload = (buffer[0] == UInt8(reportID) && length > 1) ? Int(buffer[1]) : Int(buffer[0])
            if (0...100).contains(payload) { return .level(name: name, percent: payload) }
        }
        return blocked ? .permissionDenied : .notConnected
    }
}

final class Notifier {
    private let thresholds = [30, 20, 10, 5]
    private let resetMargin = 8
    private let defaultsKey = "lastAlertThreshold"

    func evaluate(percent: Int, deviceName: String) {
        let last = UserDefaults.standard.integer(forKey: defaultsKey)
        if last != 0 && percent > last + resetMargin {
            UserDefaults.standard.set(0, forKey: defaultsKey)
            return evaluate(percent: percent, deviceName: deviceName)
        }
        guard let crossed = thresholds.filter({ percent <= $0 }).min() else { return }
        guard last == 0 || crossed < last else { return }
        UserDefaults.standard.set(crossed, forKey: defaultsKey)
        post(title: percent <= 10 ? "\(deviceName) battery critical" : "\(deviceName) battery low",
             body: "\(percent)% left — plug it in")
    }

    private func post(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return postViaScript(title: title, body: body) }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else {
                return self?.postViaScript(title: title, body: body) ?? ()
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func postViaScript(title: String, body: String) {
        let script = "display notification \"\(body)\" with title \"\(title)\" sound name \"Sosumi\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTestNotification() {
        post(title: "Keychron Battery", body: "Notifications are working")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let notifier = Notifier()
    private let deviceFilter = UserDefaults.standard.string(forKey: "deviceFilter") ?? "Keychron"
    private let refreshInterval: TimeInterval = 300
    private var timer: Timer?
    private var lastUpdate: Date?
    private var state: BatteryState = .notConnected

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = []
        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard battery")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.title = " …"
        }
        DispatchQueue.main.async { [weak self] in
            BatteryReader.requestAccessIfNeeded()
            self?.notifier.requestAuthorization()
            self?.refresh()
        }
        if ProcessInfo.processInfo.environment["KEYCHRON_BATTERY_TEST_NOTIFY"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.notifier.postTestNotification() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    @objc private func refresh() {
        let filter = deviceFilter
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let reading = BatteryReader.read(nameFilter: filter)
            DispatchQueue.main.async {
                guard let self else { return }
                self.state = reading
                self.lastUpdate = Date()
                self.writeStateFile()
                self.render()
                if case .level(let name, let percent) = reading {
                    self.notifier.evaluate(percent: percent, deviceName: name)
                }
            }
        }
    }

    private func writeStateFile() {
        let description: String
        switch state {
        case .level(let name, let percent): description = "\(name): \(percent)%"
        case .notConnected: description = "not connected"
        case .permissionDenied: description = "permission denied"
        }
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/keychron-battery")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(description) button=\(statusItem.button != nil) visible=\(statusItem.isVisible) length=\(statusItem.length)\n"
        try? line.write(to: directory.appendingPathComponent("last-state"), atomically: true, encoding: .utf8)
    }

    private func render() {
        guard let button = statusItem.button else { return }
        switch state {
        case .level(_, let percent):
            let color: NSColor = percent <= 15 ? .systemRed : (percent <= 30 ? .systemOrange : .labelColor)
            button.attributedTitle = NSAttributedString(
                string: " \(percent)%",
                attributes: [.foregroundColor: color, .font: button.font as Any]
            )
        case .notConnected:
            button.attributedTitle = NSAttributedString(
                string: " –",
                attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: button.font as Any]
            )
        case .permissionDenied:
            button.attributedTitle = NSAttributedString(
                string: " !",
                attributes: [.foregroundColor: NSColor.systemOrange, .font: button.font as Any]
            )
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        switch state {
        case .level(let name, let percent):
            menu.addItem(withTitle: "\(name): \(percent)%", action: nil, keyEquivalent: "")
        case .notConnected:
            menu.addItem(withTitle: "\(deviceFilter) keyboard not connected", action: nil, keyEquivalent: "")
        case .permissionDenied:
            menu.addItem(withTitle: "Needs Input Monitoring permission", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Enable it, then quit and reopen this app", action: nil, keyEquivalent: "")
            let item = NSMenuItem(title: "Open Privacy settings…", action: #selector(openPrivacySettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if let lastUpdate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            menu.addItem(withTitle: "Updated \(formatter.string(from: lastUpdate))", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh now", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        return menu
    }

    @objc private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
