import SwiftUI
import ServiceManagement
import Sparkle

private func openStartupPrompt() {
    let alert = NSAlert()
    alert.messageText = "Open at Login?"
    alert.informativeText = "Would you like Claude Usage Bar to launch automatically when you log in?"
    alert.addButton(withTitle: "Yes, Add to Login Items")
    alert.addButton(withTitle: "Not Now")
    alert.icon = NSImage(named: "AppIcon")

    if alert.runModal() == .alertFirstButtonReturn {
        try? SMAppService.mainApp.register()
    }
    AppSettings.shared.hasPromptedStartup = true
}

private let statusIcon: NSImage = {
    let img = NSImage(size: NSSize(width: 18, height: 18))
    if let url1x = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
       let data = try? Data(contentsOf: url1x),
       let rep1x = NSBitmapImageRep(data: data) {
        img.addRepresentation(rep1x)
    }
    if let url2x = Bundle.main.url(forResource: "StatusIcon@2x", withExtension: "png"),
       let data = try? Data(contentsOf: url2x),
       let rep2x = NSBitmapImageRep(data: data) {
        rep2x.size = NSSize(width: 18, height: 18)
        img.addRepresentation(rep2x)
    }
    img.isTemplate = true
    return img
}()

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var monitor = UsageMonitor()
    @ObservedObject private var settings = AppSettings.shared
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        if !AppSettings.shared.hasPromptedStartup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                openStartupPrompt()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(updater: updaterController.updater)
                .environmentObject(monitor)
        } label: {
            switch settings.menuBarStyle {
            case .full:
                Text(monitor.statusBarTitle)
            case .iconOnly:
                Image(nsImage: statusIcon)
            }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}

