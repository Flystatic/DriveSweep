import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var watcher: DiskWatcher!
    private let defaults = UserDefaults.standard
    private let work = DispatchQueue(label: "DriveSweep.work")

    private var cleanOnEject: Bool {
        get { defaults.object(forKey: "cleanOnEject") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "cleanOnEject") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "externaldrive.badge.checkmark",
                                           accessibilityDescription: "DriveSweep")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        watcher = DiskWatcher(
            isEnabled: { [weak self] in self?.cleanOnEject ?? false },
            onCleaned: { [weak self] name, result in
                if result.removed > 0 || result.failed > 0 { self?.notify(name, result) }
            })

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        if !defaults.bool(forKey: "didSetUpLoginItem") {
            try? SMAppService.mainApp.register()
            defaults.set(true, forKey: "didSetUpLoginItem")
        }
    }

    // MARK: Services menu — Finder → right-click drive → Services → Clean Junk Files

    @objc func cleanJunk(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let volumes = Set(urls.compactMap(Volumes.volume(containing:)))
        for volume in volumes {
            guard Volumes.isEligible(volume) else {
                notify(Volumes.name(of: volume), text: "Skipped — not an external drive")
                continue
            }
            clean(volume, thenEject: false)
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let drives = Volumes.eligible()
        if drives.isEmpty {
            menu.addItem(withTitle: "No external drives", action: nil, keyEquivalent: "")
        }
        for drive in drives {
            let header = menu.addItem(withTitle: Volumes.name(of: drive), action: nil, keyEquivalent: "")
            header.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil)
            for (title, eject) in [("Clean", false), ("Clean & Eject", true)] {
                let item = menu.addItem(withTitle: title, action: #selector(menuClean(_:)), keyEquivalent: "")
                item.target = self
                item.indentationLevel = 1
                item.representedObject = (drive, eject)
            }
        }
        menu.addItem(.separator())

        let eject = menu.addItem(withTitle: "Clean When Ejecting", action: #selector(toggleCleanOnEject), keyEquivalent: "")
        eject.target = self
        eject.state = cleanOnEject ? .on : .off

        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit DriveSweep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func menuClean(_ sender: NSMenuItem) {
        guard let (drive, eject) = sender.representedObject as? (URL, Bool) else { return }
        clean(drive, thenEject: eject)
    }

    @objc private func toggleCleanOnEject() { cleanOnEject.toggle() }

    @objc private func toggleLogin() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
    }

    // MARK: Work

    private func clean(_ volume: URL, thenEject: Bool) {
        let name = Volumes.name(of: volume)
        work.async { [self] in
            let result = Sweeper.clean(volume: volume)
            guard thenEject else { return notify(name, result) }
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: volume)
                notify(name, text: "\(result.summary). Ejected.")
            } catch {
                notify(name, text: "\(result.summary). Couldn't eject — is a file still open?")
            }
        }
    }

    private func notify(_ name: String, _ result: SweepResult) {
        notify(name, text: result.summary)
    }

    private func notify(_ name: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = text
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
