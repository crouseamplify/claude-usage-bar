import SwiftUI

struct MenuView: View {
    @EnvironmentObject var monitor: UsageMonitor
    @ObservedObject private var s = AppSettings.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header

            // Token metrics
            if s.showInput || s.showOutput || s.showCacheRead || s.showCacheWrite {
                separator
                tokenSection
            }

            // Spend
            if s.showSpend {
                separator
                costRow
            }

            // Model breakdown
            if s.showModelBreakdown && !monitor.summary.todayByModel.isEmpty {
                separator
                modelBreakdownSection
            }

            // Charts
            if s.show7DayChart || s.show30DayChart {
                separator
                ChartView(
                    allPoints: monitor.summary.dailyPoints,
                    showSevenDay: s.show7DayChart,
                    showThirtyDay: s.show30DayChart
                )
            }

            separator
            footer
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { monitor.refreshIfNeeded() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.system(size: 14, weight: .semibold))
                Text("Today · \(monitor.today.messageCount) messages")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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

    private var tokenSection: some View {
        VStack(spacing: 10) {
            if s.showInput {
                TokenRow(
                    icon: "arrow.up.circle", color: Color.blue,
                    label: "Input",
                    today: monitor.today.inputTokens,
                    sevenDay: s.show7DayHistory  ? monitor.sevenDay.inputTokens  : nil,
                    thirtyDay: s.show30DayHistory ? monitor.thirtyDay.inputTokens : nil
                )
            }
            if s.showOutput {
                TokenRow(
                    icon: "arrow.down.circle", color: Color.green,
                    label: "Output",
                    today: monitor.today.outputTokens,
                    sevenDay: s.show7DayHistory  ? monitor.sevenDay.outputTokens  : nil,
                    thirtyDay: s.show30DayHistory ? monitor.thirtyDay.outputTokens : nil
                )
            }
            if s.showCacheRead {
                TokenRow(
                    icon: "bolt.circle", color: Color.yellow,
                    label: "Cache read",
                    today: monitor.today.cacheReadTokens,
                    sevenDay: s.show7DayHistory  ? monitor.sevenDay.cacheReadTokens  : nil,
                    thirtyDay: s.show30DayHistory ? monitor.thirtyDay.cacheReadTokens : nil
                )
            }
            if s.showCacheWrite {
                TokenRow(
                    icon: "square.and.arrow.down", color: Color.purple,
                    label: "Cache write",
                    today: monitor.today.cacheWriteTokens,
                    sevenDay: s.show7DayHistory  ? monitor.sevenDay.cacheWriteTokens  : nil,
                    thirtyDay: s.show30DayHistory ? monitor.thirtyDay.cacheWriteTokens : nil
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var costRow: some View {
        VStack(spacing: 4) {
            HStack {
                Label("Est. cost today", systemImage: "dollarsign.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(UsageMonitor.fmtCost(monitor.today.estimatedCost))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(costColor(monitor.today.estimatedCost))
            }
            if s.show7DaySpend || s.show30DaySpend {
                HStack {
                    Spacer()
                    HistoryLabel(
                        sevenDay:  s.show7DaySpend  ? monitor.sevenDay.estimatedCost  : nil,
                        thirtyDay: s.show30DaySpend ? monitor.thirtyDay.estimatedCost : nil,
                        format: UsageMonitor.fmtCost
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var modelBreakdownSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Today by Model")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(
                monitor.summary.todayByModel
                    .sorted { $0.value.cost > $1.value.cost },
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
            "claude-opus-4-7":            "Opus 4.7",
            "claude-sonnet-4-6":          "Sonnet 4.6",
            "claude-sonnet-4-5-20250929": "Sonnet 4.5",
            "claude-haiku-4-5-20251001":  "Haiku 4.5",
        ]
        if let name = map[model] { return name }
        // Generic fallback: strip "claude-" prefix and capitalise first word
        let stripped = model.hasPrefix("claude-") ? String(model.dropFirst(7)) : model
        return stripped.prefix(1).uppercased() + stripped.dropFirst()
    }

    private var footer: some View {
        HStack {
            Group {
                if s.refreshMode == .realTime {
                    Text("Updated \(monitor.lastRefreshed, style: .relative) ago")
                } else {
                    Text("Last refreshed \(monitor.lastRefreshed, format: .dateTime.hour().minute().second())")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            Spacer()
            Button("Settings") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .keyboardShortcut(",")

            Text("·").foregroundStyle(.tertiary).font(.system(size: 11))

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
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
