import SwiftUI

enum MenuBarStyle: String, CaseIterable {
    case full     = "full"
    case iconOnly = "iconOnly"

    var label: String {
        switch self {
        case .full:     return "Tokens + Cost"
        case .iconOnly: return "Icon only"
        }
    }
}

enum RefreshMode: String, CaseIterable {
    case realTime = "realTime"
    case onOpen   = "onOpen"
    case manual   = "manual"

    var label: String {
        switch self {
        case .realTime: return "Every 30 seconds"
        case .onOpen:   return "When opened"
        case .manual:   return "Manually"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Token Details
    @AppStorage("showInput")      var showInput      = true
    @AppStorage("showOutput")     var showOutput     = true
    @AppStorage("showCacheRead")  var showCacheRead  = false
    @AppStorage("showCacheWrite") var showCacheWrite = false

    // History rows (7d/30d sub-labels under each metric)
    @AppStorage("show7DayHistory")  var show7DayHistory  = false
    @AppStorage("show30DayHistory") var show30DayHistory = false

    // Spend
    @AppStorage("showSpend")      var showSpend      = true
    @AppStorage("show7DaySpend")  var show7DaySpend  = false
    @AppStorage("show30DaySpend") var show30DaySpend = false

    // Model breakdown
    @AppStorage("showModelBreakdown") var showModelBreakdown = false

    // Charts
    @AppStorage("show7DayChart")  var show7DayChart  = false
    @AppStorage("show30DayChart") var show30DayChart = false

    // Menu bar style
    @AppStorage("menuBarStyle") private var menuBarStyleRaw = MenuBarStyle.full.rawValue
    var menuBarStyle: MenuBarStyle {
        get { MenuBarStyle(rawValue: menuBarStyleRaw) ?? .full }
        set { menuBarStyleRaw = newValue.rawValue }
    }

// Refresh
    @AppStorage("refreshMode") private var refreshModeRaw = RefreshMode.realTime.rawValue
    var refreshMode: RefreshMode {
        get { RefreshMode(rawValue: refreshModeRaw) ?? .realTime }
        set { refreshModeRaw = newValue.rawValue }
    }
}
