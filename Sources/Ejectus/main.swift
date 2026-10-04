import AppKit

// Root daemon mode, launched by launchd (see SpotlightHelper).
if CommandLine.arguments.contains("--helper") { SpotlightHelper.runDaemon() }

// Test the root side's safety check without root: Ejectus --check-mount /Volumes/X
if let i = CommandLine.arguments.firstIndex(of: "--check-mount"), i + 1 < CommandLine.arguments.count {
    let ok = SpotlightHelper.isSafeMountPoint(CommandLine.arguments[i + 1])
    print(ok ? "SAFE" : "REFUSED")
    exit(ok ? 0 : 1)
}

// Command-line mode for testing: Ejectus --clean /Volumes/SDCARD
if let i = CommandLine.arguments.firstIndex(of: "--clean"), i + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    guard Volumes.isEligible(url) else {
        print("Not an eligible external volume: \(url.path)")
        exit(1)
    }
    print(Sweeper.fullClean(volume: url).summary)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
