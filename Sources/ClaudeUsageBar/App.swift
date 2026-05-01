import SwiftUI

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

    var body: some Scene {
        MenuBarExtra {
            MenuView()
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

