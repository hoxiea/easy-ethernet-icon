import Cocoa
import SwiftUI
import Network

/// Manages the application's menu and monitors ethernet connection status
class ApplicationMenu: NSObject, NSWindowDelegate, NSMenuDelegate {
    // Main menu instance
    let menu = NSMenu()

    /// Represents the possible states of ethernet connection
    enum ConnectionStatus {
        case Connected
        case Disconnected
    }

    // Menu items
    let toggleEthernetItem = NSMenuItem(
        title: "Checking...",
        action: #selector(toggleEthernet),
        keyEquivalent: "t"
    )
    let ethernetStatusItem = NSMenuItem(
        title: "Checking Ethernet Status...",
        action: nil,
        keyEquivalent: ""
    )
    let speedStatusItem = NSMenuItem(
        title: "Speed: -",
        action: nil,
        keyEquivalent: ""
    )
    let quitApplicationItem = NSMenuItem(
        title: "Quit Application",
        action: #selector(quitApplication),
        keyEquivalent: "q"
    )
    let networkSettingsItem = NSMenuItem(
        title: "Open Network Settings",
        action: #selector(openNetworkSettings),
        keyEquivalent: "n"
    )
    let settingsItem = NSMenuItem(
        title: "Settings",
        action: #selector(openSettings),
        keyEquivalent: "s"
    )

    // Settings window reference
    var settingsPanel: NSPanel?

    // Reference to NetworkMonitor
    private let networkMonitor = NetworkMonitor()

    // Detected ethernet service name (e.g. "Thunderbolt Ethernet Slot 2")
    private var ethernetServiceName: String?

    override init() {
        super.init()
        setupMenuItems()
        setupSpeedMonitoring()

        // Observe changes to showConnectionSpeed setting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpeedSettingChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Detect ethernet service name and set initial toggle title
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.ethernetServiceName = self?.detectEthernetServiceName()
            self?.refreshToggleMenuItemTitle()
        }
    }

    private func setupSpeedMonitoring() {
        // Setup speed monitoring callback
        networkMonitor.onSpeedUpdate = { [weak self] download, upload in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let unit = UserDefaults.standard.string(forKey: "speedUnit") ?? "MB/s"
                let speedText = String(format: "Speed: %.1f %@ ↓ | %.1f %@ ↑", download, unit, upload, unit)
                self.speedStatusItem.title = speedText
            }
        }

        // Start monitoring only if enabled in settings
        updateSpeedMonitoring()
    }

    @objc private func handleSpeedSettingChange() {
        updateSpeedMonitoring()
    }

    private func updateSpeedMonitoring() {
        let showSpeed = UserDefaults.standard.bool(forKey: "showConnectionSpeed")

        if showSpeed {
            networkMonitor.startMonitoring()
        } else {
            networkMonitor.stopMonitoring()
            DispatchQueue.main.async {
                self.speedStatusItem.title = "Speed: -"
            }
        }
    }

    /// Sets up menu item targets
    private func setupMenuItems() {
        toggleEthernetItem.target = self
        quitApplicationItem.target = self
        networkSettingsItem.target = self
        settingsItem.target = self
    }

    /// Creates and returns the configured menu
    func createMenu() -> NSMenu {
        menu.removeAllItems() // Clean up before adding items

        menu.addItem(toggleEthernetItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(ethernetStatusItem)
        menu.addItem(speedStatusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(networkSettingsItem)
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitApplicationItem)

        menu.delegate = self

        return menu
    }

    // MARK: - NSMenuDelegate

    /// Refresh toggle title each time the menu opens, in case the user changed state via System Settings
    func menuWillOpen(_ menu: NSMenu) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.refreshToggleMenuItemTitle()
        }
    }

    // MARK: - Ethernet Toggle

    /// Finds the first wired ethernet service name using networksetup
    private func detectEthernetServiceName() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: "\n")

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                let portName = line.replacingOccurrences(of: "Hardware Port: ", with: "")
                if i + 1 < lines.count {
                    let deviceLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if deviceLine.hasPrefix("Device: en")
                        && !portName.lowercased().contains("wi-fi")
                        && !portName.lowercased().contains("bluetooth") {
                        return portName
                    }
                }
            }
            i += 1
        }
        return nil
    }

    /// Returns whether the ethernet service is currently enabled
    private func isEthernetEnabled() -> Bool {
        guard let serviceName = ethernetServiceName else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-getnetworkserviceenabled", serviceName]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "Enabled"
    }

    /// Updates the toggle menu item title to reflect current ethernet state
    private func refreshToggleMenuItemTitle() {
        guard ethernetServiceName != nil else {
            DispatchQueue.main.async {
                self.toggleEthernetItem.title = "Toggle Ethernet (not found)"
                self.toggleEthernetItem.isEnabled = false
            }
            return
        }
        let enabled = isEthernetEnabled()
        DispatchQueue.main.async {
            self.toggleEthernetItem.title = enabled ? "Disable Ethernet" : "Enable Ethernet"
            self.toggleEthernetItem.isEnabled = true
        }
    }

    /// Toggles the ethernet service on or off, prompting for admin credentials if needed
    @objc func toggleEthernet() {
        guard let serviceName = ethernetServiceName else { return }
        let action = isEthernetEnabled() ? "off" : "on"
        let escaped = serviceName.replacingOccurrences(of: "'", with: #"'\''"#)
        let source = """
            do shell script "/usr/sbin/networksetup -setnetworkserviceenabled '\(escaped)' \(action)" with administrator privileges
            """
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if error == nil {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.refreshToggleMenuItemTitle()
            }
        }
    }

    // MARK: - Status Monitoring

    /// Starts monitoring ethernet connection status
    func startMonitoringEthernetStatus(statusUpdate: @escaping (ConnectionStatus) -> Void) {
        let monitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)

        monitor.pathUpdateHandler = { path in
            let status: ConnectionStatus = path.status == .satisfied
                ? .Connected
                : .Disconnected

            statusUpdate(status)

            DispatchQueue.main.async {
                self.updateStatusMenuItem(status: status)
            }
        }

        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    private func updateStatusMenuItem(status: ConnectionStatus) {
        self.ethernetStatusItem.title = "Ethernet: \(status == .Connected ? "Connected" : "Disconnected")"
    }

    func stopMonitoring() {
        networkMonitor.stopMonitoring()
    }

    /// Quits the application
    @objc func quitApplication() {
        stopMonitoring()
        NSApplication.shared.terminate(self)
    }

    /// Opens the settings panel
    @objc func openSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if settingsPanel == nil {
            createSettingsPanel()
        }

        settingsPanel?.makeKeyAndOrderFront(nil)
        settingsPanel?.orderFrontRegardless()
    }

    /// Creates the settings panel
    private func createSettingsPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.center()
        panel.setFrameAutosaveName("Settings")
        panel.contentView = NSHostingView(rootView: SettingsView())
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating

        self.settingsPanel = panel
    }

    /// Opens system network settings
    @objc func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
