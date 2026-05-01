import Foundation

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var summary = UsageSummary()
    @Published private(set) var lastRefreshed = Date()

    private var timer: Timer?

    var today:     DayUsage { summary.today }
    var sevenDay:  DayUsage { summary.sevenDay }
    var thirtyDay: DayUsage { summary.thirtyDay }

    init() {
        refresh()
        scheduleTimerIfNeeded()
    }

    func refresh() {
        Task.detached(priority: .utility) {
            let result = UsageReader.read()
            await MainActor.run {
                self.summary = result
                self.lastRefreshed = Date()
            }
        }
    }

    // Called by MenuView.onAppear for .onOpen mode
    func refreshIfNeeded() {
        switch AppSettings.shared.refreshMode {
        case .realTime: break          // timer handles it
        case .onOpen, .manual: refresh()
        }
    }

    private func scheduleTimerIfNeeded() {
        timer?.invalidate()
        guard AppSettings.shared.refreshMode == .realTime else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard AppSettings.shared.refreshMode == .realTime else { return }
                self?.refresh()
            }
        }
    }

    // Call when refresh mode setting changes
    func refreshModeDidChange() {
        scheduleTimerIfNeeded()
    }

    var statusBarTitle: String {
        "\(Self.fmt(today.outputTokens))  \(Self.fmtCost(today.estimatedCost))"
    }

    static func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    static func fmtCost(_ d: Double) -> String {
        d < 0.01 ? "<$0.01" : String(format: "$%.2f", d)
    }
}
