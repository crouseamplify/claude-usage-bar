import SwiftUI
import Sparkle

private enum ViewTab { case overview, projects }

struct MenuView: View {
    @EnvironmentObject var monitor: UsageMonitor
    @EnvironmentObject var updateState: UpdateState
    @ObservedObject private var s = AppSettings.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    var updater: SPUUpdater?

    @State private var selectedTab: ViewTab = .overview
    @State private var selectedProject: String? = nil  // folder key
    @State private var projectSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar

            if selectedTab == .overview {
                overviewContent
            } else {
                projectsContent
            }

            footer
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { monitor.refreshIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsFromMenu)) { _ in
            dismiss()
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if selectedTab == .projects, let key = selectedProject,
               let proj = monitor.summary.byProject[key] {
                Button { selectedProject = nil } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(proj.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Today · \(proj.today.messageCount) messages")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude Usage")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Today · \(monitor.today.messageCount) messages")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button { monitor.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 4) {
                tabButton("Overview", tab: .overview)
                tabButton("Projects", tab: .projects)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider().overlay(Color.white.opacity(0.08))
        }
    }

    private func tabButton(_ label: String, tab: ViewTab) -> some View {
        Button {
            selectedTab = tab
            selectedProject = nil
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview tab

    private var overviewContent: some View {
        Group {
            if s.showInput || s.showOutput || s.showCacheRead || s.showCacheWrite {
                separator
                tokenSection(
                    today: monitor.today,
                    sevenDay: monitor.sevenDay,
                    thirtyDay: monitor.thirtyDay
                )
            }

            if s.showSpend {
                separator
                costRow(
                    today: monitor.today,
                    sevenDay: monitor.sevenDay,
                    thirtyDay: monitor.thirtyDay
                )
            }

            if s.showModelBreakdown && !monitor.summary.todayByModel.isEmpty {
                separator
                modelBreakdownSection(byModel: monitor.summary.todayByModel)
            }

            if s.show7DayChart || s.show30DayChart {
                separator
                ChartView(
                    allPoints: monitor.summary.dailyPoints,
                    showSevenDay: s.show7DayChart,
                    showThirtyDay: s.show30DayChart
                )
            }
        }
    }

    // MARK: - Projects tab

    private var projectsContent: some View {
        Group {
            if let key = selectedProject, let proj = monitor.summary.byProject[key] {
                projectDetail(proj)
            } else {
                projectList
            }
        }
    }

    private var projectList: some View {
        let query = projectSearch.lowercased()
        let sorted = monitor.summary.byProject
            .filter { query.isEmpty || $0.value.displayName.lowercased().contains(query) }
            .sorted { $0.value.displayName.localizedCaseInsensitiveCompare($1.value.displayName) == .orderedAscending }

        return VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search projects…", text: $projectSearch)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                if !projectSearch.isEmpty {
                    Button { projectSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider().overlay(Color.white.opacity(0.08))

            if sorted.isEmpty {
                Text(projectSearch.isEmpty ? "No projects found" : "No matches")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.key) { i, item in
                            if i > 0 { Divider().overlay(Color.white.opacity(0.06)) }
                            ProjectRow(
                                name: item.value.displayName,
                                today: item.value.today.estimatedCost,
                                thirtyDay: item.value.thirtyDay.estimatedCost
                            ) {
                                selectedProject = item.key
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func projectDetail(_ proj: ProjectSummary) -> some View {
        Group {
            if s.showInput || s.showOutput || s.showCacheRead || s.showCacheWrite {
                separator
                tokenSection(
                    today: proj.today,
                    sevenDay: proj.sevenDay,
                    thirtyDay: proj.thirtyDay
                )
            }

            if s.showSpend {
                separator
                costRow(
                    today: proj.today,
                    sevenDay: proj.sevenDay,
                    thirtyDay: proj.thirtyDay
                )
            }

            if s.showModelBreakdown && !proj.todayByModel.isEmpty {
                separator
                modelBreakdownSection(byModel: proj.todayByModel)
            }
        }
    }

    // MARK: - Shared section builders

    private func tokenSection(today: DayUsage, sevenDay: DayUsage, thirtyDay: DayUsage) -> some View {
        VStack(spacing: 10) {
            if s.showInput {
                TokenRow(
                    icon: "arrow.up.circle", color: Color.blue,
                    label: "Input",
                    today: today.inputTokens,
                    sevenDay: s.show7DayHistory  ? sevenDay.inputTokens  : nil,
                    thirtyDay: s.show30DayHistory ? thirtyDay.inputTokens : nil
                )
            }
            if s.showOutput {
                TokenRow(
                    icon: "arrow.down.circle", color: Color.green,
                    label: "Output",
                    today: today.outputTokens,
                    sevenDay: s.show7DayHistory  ? sevenDay.outputTokens  : nil,
                    thirtyDay: s.show30DayHistory ? thirtyDay.outputTokens : nil
                )
            }
            if s.showCacheRead {
                TokenRow(
                    icon: "bolt.circle", color: Color.yellow,
                    label: "Cache read",
                    today: today.cacheReadTokens,
                    sevenDay: s.show7DayHistory  ? sevenDay.cacheReadTokens  : nil,
                    thirtyDay: s.show30DayHistory ? thirtyDay.cacheReadTokens : nil
                )
            }
            if s.showCacheWrite {
                TokenRow(
                    icon: "square.and.arrow.down", color: Color.purple,
                    label: "Cache write",
                    today: today.cacheWriteTokens,
                    sevenDay: s.show7DayHistory  ? sevenDay.cacheWriteTokens  : nil,
                    thirtyDay: s.show30DayHistory ? thirtyDay.cacheWriteTokens : nil
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func costRow(today: DayUsage, sevenDay: DayUsage, thirtyDay: DayUsage) -> some View {
        VStack(spacing: 4) {
            HStack {
                Label("Est. cost today", systemImage: "dollarsign.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(UsageMonitor.fmtCost(today.estimatedCost))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(costColor(today.estimatedCost))
            }
            if s.show7DaySpend || s.show30DaySpend {
                HStack {
                    Spacer()
                    HistoryLabel(
                        sevenDay:  s.show7DaySpend  ? sevenDay.estimatedCost  : nil,
                        thirtyDay: s.show30DaySpend ? thirtyDay.estimatedCost : nil,
                        format: UsageMonitor.fmtCost
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func modelBreakdownSection(byModel: [String: ModelCost]) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Today by Model")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(
                byModel.sorted { $0.value.cost > $1.value.cost },
                id: \.key
            ) { model, mc in
                HStack(spacing: 6) {
                    Text(shortModelName(model))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(mc.messageCount) msg\(mc.messageCount == 1 ? "" : "s")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(UsageMonitor.fmtCost(mc.cost))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func shortModelName(_ model: String) -> String {
        let map: [String: String] = [
            "claude-opus-4-7":             "Opus 4.7",
            "claude-opus-4-6":             "Opus 4.6",
            "claude-opus-4-5":             "Opus 4.5",
            "claude-opus-4-1":             "Opus 4.1",
            "claude-opus-4-0":             "Opus 4",
            "claude-sonnet-4-6":           "Sonnet 4.6",
            "claude-sonnet-4-5":           "Sonnet 4.5",
            "claude-sonnet-4-5-20250929":  "Sonnet 4.5",
            "claude-sonnet-4-0":           "Sonnet 4",
            "claude-sonnet-3-7":           "Sonnet 3.7",
            "claude-sonnet-3-7-20250219":  "Sonnet 3.7",
            "claude-haiku-4-5":            "Haiku 4.5",
            "claude-haiku-4-5-20251001":   "Haiku 4.5",
            "claude-haiku-3-5":            "Haiku 3.5",
            "claude-haiku-3-5-20241022":   "Haiku 3.5",
            "claude-opus-3-20240229":      "Opus 3",
            "claude-haiku-3":              "Haiku 3",
            "claude-haiku-3-20240307":     "Haiku 3",
        ]
        if let name = map[model] { return name }
        let stripped = model.hasPrefix("claude-") ? String(model.dropFirst(7)) : model
        return stripped.prefix(1).uppercased() + stripped.dropFirst()
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.white.opacity(0.08))

            Group {
                if s.refreshMode == .realTime {
                    Text("Updated \(monitor.lastRefreshed, style: .relative) ago")
                } else {
                    Text("Last refreshed \(monitor.lastRefreshed, format: .dateTime.hour().minute().second())")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)

            Divider().overlay(Color.white.opacity(0.08))

            FooterMenuItem(
                label: updateState.updateAvailable ? "Update Available" : "Check for Updates…",
                badge: updateState.updateAvailable
            ) {
                updater?.checkForUpdates()
            }

            FooterMenuItem(label: "Settings…", shortcut: "⌘,") {
                dismiss()
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            FooterMenuItem(label: "Quit Claude Usage Bar", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var separator: some View {
        Divider().overlay(Color.white.opacity(0.08))
    }

    private func costColor(_ cost: Double) -> Color {
        switch cost {
        case ..<15:    return Color.primary
        case 15..<30:  return Color.orange
        default:       return Color.red
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let name: String
    let today: Double
    let thirtyDay: Double
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(hovered ? .white : .primary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(name)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UsageMonitor.fmtCost(today))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(hovered ? .white : .primary)
                    Text("30d \(UsageMonitor.fmtCost(thirtyDay))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(hovered ? Color.white.opacity(0.7) : Color.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(hovered ? Color.white.opacity(0.5) : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(hovered ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Token Row

private struct TokenRow: View {
    let icon: String
    let color: Color
    let label: String
    let today: Int
    let sevenDay: Int?
    let thirtyDay: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color.opacity(0.9))
                .font(.system(size: 13))
                .frame(width: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                if sevenDay != nil || thirtyDay != nil {
                    HistoryLabel(sevenDay: sevenDay, thirtyDay: thirtyDay,
                                 format: UsageMonitor.fmt)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(UsageMonitor.fmt(today))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Footer menu item

private struct FooterMenuItem: View {
    let label: String
    var shortcut: String? = nil
    var badge: Bool = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                if badge {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 13))
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(hovered ? Color.white.opacity(0.7) : Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(hovered ? Color.accentColor : Color.clear)
            .foregroundStyle(hovered ? .white : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - History sub-label

private struct HistoryLabel<T>: View {
    let sevenDay: T?
    let thirtyDay: T?
    let format: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            if let v = sevenDay {
                Text("7d").foregroundStyle(.secondary)
                Text(format(v)).foregroundStyle(.primary)
            }
            if sevenDay != nil && thirtyDay != nil {
                Text("·").foregroundStyle(.secondary)
            }
            if let v = thirtyDay {
                Text("30d").foregroundStyle(.secondary)
                Text(format(v)).foregroundStyle(.primary)
            }
        }
        .font(.system(size: 11, design: .monospaced))
    }
}
