import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class LunchBell: NSObject, NSApplicationDelegate, ObservableObject {
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var reminder: NSPanel?
    private var settings: NSWindow?
    private var soundTimer: Timer?
    private var isPreview = false
    @Published var loginError: String?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "enabled")
            if !enabled { closeReminder() }
            refreshMenu()
        }
    }
    @Published var sound: Bool {
        didSet { defaults.set(sound, forKey: "sound") }
    }
    @Published var time: Date {
        didSet {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            if parts.hour! != defaults.integer(forKey: "hour") || parts.minute! != defaults.integer(forKey: "minute") {
                defaults.removeObject(forKey: "snoozedUntil")
            }
            defaults.set(parts.hour!, forKey: "hour")
            defaults.set(parts.minute!, forKey: "minute")
            refreshMenu()
        }
    }

    override init() {
        defaults.register(defaults: ["hour": 11, "minute": 21, "enabled": true, "sound": true])
        enabled = defaults.bool(forKey: "enabled")
        sound = defaults.bool(forKey: "sound")
        time = Calendar.current.date(bySettingHour: defaults.integer(forKey: "hour"),
                                     minute: defaults.integer(forKey: "minute"), second: 0, of: Date())!
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One process owns the reminder, including when opened again from Finder.
        let copies = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if copies.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshMenu()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(check),
            name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(check),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        if !defaults.bool(forKey: "welcomed") {
            defaults.set(true, forKey: "welcomed")
            showSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("--preview") { preview() }
        else { check() }
    }

    private var schedule: LunchSchedule {
        LunchSchedule(hour: defaults.integer(forKey: "hour"), minute: defaults.integer(forKey: "minute"))
    }

    private func refreshMenu() {
        guard statusItem != nil else { return }
        statusItem.button?.image = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: "Lunch Bell")
        statusItem.button?.appearsDisabled = !enabled
        let label = schedule.scheduledTime(on: Date()).formatted(date: .omitted, time: .shortened)
        statusItem.button?.toolTip = enabled ? "Lunch Bell · \(label)" : "Lunch Bell · paused"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Lunch at \(label) every day", action: nil, keyEquivalent: ""))
        add("Enabled", #selector(toggleEnabled), to: menu).state = enabled ? .on : .off
        menu.addItem(.separator())
        add("Settings…", #selector(showSettings), to: menu, key: ",")
        add("Try the alert…", #selector(preview), to: menu)
        menu.addItem(.separator())
        add("Quit Lunch Bell", #selector(quit), to: menu, key: "q")
        statusItem.menu = menu
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, to menu: NSMenu, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleEnabled() { enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func check() {
        guard enabled, reminder == nil else { return }
        let now = Date()
        var snooze = defaults.object(forKey: "snoozedUntil") as? Date
        if let date = snooze, !Calendar.current.isDate(date, inSameDayAs: now) {
            defaults.removeObject(forKey: "snoozedUntil")
            snooze = nil
        }
        if schedule.isDue(now: now, handled: defaults.object(forKey: "handled") as? Date,
                          snoozedUntil: snooze) { showReminder(preview: false) }
    }

    @objc func preview() { showReminder(preview: true) }

    private func showReminder(preview: Bool) {
        if let reminder { reminder.makeKeyAndOrderFront(nil); return }
        isPreview = preview
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 350),
                            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = preview ? "Lunch Bell — preview" : "Lunch Bell"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ReminderView(preview: preview, sound: sound,
            acknowledge: { [weak self] in self?.acknowledge() },
            snooze: { [weak self] in self?.snooze() }))
        panel.center()
        reminder = panel
        panel.makeKeyAndOrderFront(nil)
        if sound { playSound() }
        soundTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if self?.sound == true { self?.playSound() } }
        }
    }

    private func playSound() { NSSound(named: "Glass")?.play() }

    private func closeReminder() {
        soundTimer?.invalidate()
        soundTimer = nil
        reminder?.close()
        reminder = nil
    }

    private func acknowledge() {
        if !isPreview {
            defaults.set(Date(), forKey: "handled")
            defaults.removeObject(forKey: "snoozedUntil")
        }
        closeReminder()
    }

    private func snooze() {
        if !isPreview { defaults.set(Date().addingTimeInterval(600), forKey: "snoozedUntil") }
        closeReminder()
    }

    @objc func showSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 410, height: 400),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Lunch Bell"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(app: self))
            window.center()
            settings = window
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        time = schedule.scheduledTime(on: Date())
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "Approve Lunch Bell in System Settings → General → Login Items." : nil
        } catch { loginError = error.localizedDescription }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }
}

struct ReminderView: View {
    let preview: Bool
    let sound: Bool
    let acknowledge: () -> Void
    let snooze: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Time for lunch.").font(.system(size: 32, weight: .bold, design: .rounded))
            Text(preview ? "This is a preview. Your schedule won’t change." : "Step away. Get something good to eat.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button(preview ? "Close preview" : "Snooze 10 min", action: snooze)
                Button(preview ? "Looks good" : "I’m going", action: acknowledge)
                    .buttonStyle(.borderedProminent).tint(.orange)
            }
            .controlSize(.large)
            Text(sound ? "Stays here until you choose. Sound repeats every 30 seconds." : "Stays here until you choose.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(30).frame(width: 460, height: 350)
        .background(.background)
    }
}

struct SettingsView: View {
    @ObservedObject var app: LunchBell

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill").font(.system(size: 40)).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("Lunch Bell").font(.title2.bold())
                    Text("A proper break, every day.").foregroundStyle(.secondary)
                }
            }
            DatePicker("Lunch time", selection: $app.time, displayedComponents: .hourAndMinute)
            Toggle("Remind me every day", isOn: $app.enabled)
            Toggle("Play a sound (repeats every 30 seconds)", isOn: $app.sound)
            Toggle("Open at login", isOn: Binding(get: { app.loginEnabled }, set: app.setLogin))
            if let error = app.loginError { Text(error).font(.caption).foregroundStyle(.red) }
            Text("A window stays above your apps until you acknowledge it or snooze for 10 minutes. Keep Lunch Bell running in the menu bar.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Try the alert…", action: app.preview)
        }
        .padding(28).frame(width: 410)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = LunchBell()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
