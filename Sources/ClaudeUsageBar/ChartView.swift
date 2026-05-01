import SwiftUI

enum ChartPeriod: String, CaseIterable {
    case sevenDays  = "7D"
    case thirtyDays = "30D"
}

struct ChartView: View {
    let allPoints: [DailyPoint]
    var showSevenDay: Bool = true
    var showThirtyDay: Bool = true
    @State private var period: ChartPeriod = .sevenDays
    @State private var hoveredIndex: Int? = nil

    private var availablePeriods: [ChartPeriod] {
        var p: [ChartPeriod] = []
        if showSevenDay  { p.append(.sevenDays) }
        if showThirtyDay { p.append(.thirtyDays) }
        return p
    }

    private var points: [DailyPoint] {
        Array(allPoints.suffix(period == .sevenDays ? 7 : 30))
    }

    private var hoveredPoint: DailyPoint? {
        guard let i = hoveredIndex, points.indices.contains(i) else { return nil }
        return points[i]
    }

    var body: some View {
        VStack(spacing: 0) {
            chartHeader
            Divider().overlay(Color.white.opacity(0.08))
            BarChart(points: points, period: period, hoveredIndex: $hoveredIndex)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)
            tooltip
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .onAppear {
            if !availablePeriods.contains(period), let first = availablePeriods.first {
                period = first
            }
        }
    }

    // MARK: - Header

    private var chartHeader: some View {
        HStack {
            Text("Daily Cost")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if availablePeriods.count > 1 {
                Picker("", selection: $period) {
                    ForEach(availablePeriods, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .scaleEffect(0.85, anchor: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Tooltip (stacked, fixed height to prevent panel resize)

    private var tooltip: some View {
        Group {
            if let pt = hoveredPoint {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pt.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(UsageMonitor.fmtCost(pt.usage.estimatedCost))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    HStack(spacing: 6) {
                        Text("out")
                            .foregroundStyle(.secondary)
                        Text(UsageMonitor.fmt(pt.usage.outputTokens))
                            .foregroundStyle(.primary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("msgs")
                            .foregroundStyle(.secondary)
                        Text("\(pt.usage.messageCount)")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hover a bar for details")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(" ")
                        .font(.system(size: 11))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.1), value: hoveredIndex)
    }
}

// MARK: - Custom bar chart


private struct BarChart: View {
    let points: [DailyPoint]
    let period: ChartPeriod
    @Binding var hoveredIndex: Int?

    private let chartHeight: CGFloat = 90
    private let yLabelWidth: CGFloat = 28

    private var maxCost: Double {
        max(points.map(\.usage.estimatedCost).max() ?? 0, 0.01)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                yAxisLabels
                ZStack(alignment: .bottomLeading) {
                    gridlines
                    bars
                }
            }
            .frame(height: chartHeight)

            // X labels — offset to align with bars (skip y-label column)
            HStack(spacing: 0) {
                Spacer().frame(width: yLabelWidth)
                xAxisLabels
            }
            .frame(height: 14)
            .padding(.top, 3)
        }
    }

    // MARK: - Y-axis labels (own column, no overlap)

    private var yAxisLabels: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(compactCost(maxCost))
            Spacer()
            Text(compactCost(maxCost / 2))
            Spacer()
            Text("$0")
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .frame(width: yLabelWidth, height: chartHeight)
    }

    // MARK: - Gridlines

    private var gridlines: some View {
        GeometryReader { geo in
            ForEach([1.0, 0.5, 0.0], id: \.self) { fraction in
                Path { p in
                    let y = geo.size.height * CGFloat(1.0 - fraction)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(Color.white.opacity(fraction == 0 ? 0.15 : 0.07), lineWidth: 1)
            }
        }
    }

    // MARK: - Bars

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                let fraction  = CGFloat(point.usage.estimatedCost / maxCost)
                let isHovered = hoveredIndex == i

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHovered
                              ? Palette.hover(point.usage.estimatedCost)
                              : Palette.standard(point.usage.estimatedCost))
                        .frame(height: point.usage.estimatedCost > 0
                               ? max(fraction * chartHeight, 3)
                               : 2)
                }
                .frame(maxWidth: .infinity, maxHeight: chartHeight)
                .contentShape(Rectangle())
                .onHover { hoveredIndex = $0 ? i : nil }
            }
        }
    }

    // MARK: - X-axis labels

    private var xAxisLabels: some View {
        HStack(spacing: 2) {
            ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                Text(shouldShowLabel(i) ? xLabel(for: point.date) : "")
                    .font(.system(size: 9))
                    .foregroundStyle(hoveredIndex == i ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    // barColor replaced by Palette — see below


    private func shouldShowLabel(_ i: Int) -> Bool {
        let n = points.count
        if n <= 7 { return true }
        if n > 15 { return i == 0 || i == n - 1 }
        return i % 2 == 0
    }

    private func xLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = period == .sevenDays ? "EEE" : "d"
        return fmt.string(from: date)
    }

    private func compactCost(_ d: Double) -> String {
        d < 1 ? String(format: "$%.1f", d) : String(format: "$%.0f", d)
    }
}

// MARK: - Color palette
//
//  Standard (muted)      Hover (vivid)
//  ─────────────────     ─────────────
//  Blue   #1D98CD   →    #00A6ED   low cost  (< $5)
//  Gold   #DFA620   →    #FFB400   mid cost  ($5 – $20)
//  Red    #DB5F39   →    #F6511D   high cost (> $20)

private enum Palette {
    static func standard(_ cost: Double) -> Color {
        switch cost {
        case ..<0.01: return Color(hex: "1D98CD").opacity(0.3)
        case ..<15:   return Color(hex: "1D98CD")
        case ..<30:   return Color(hex: "DFA620")
        default:      return Color(hex: "DB5F39")
        }
    }

    static func hover(_ cost: Double) -> Color {
        switch cost {
        case ..<0.01: return Color(hex: "00A6ED").opacity(0.3)
        case ..<15:   return Color(hex: "00A6ED")
        case ..<30:   return Color(hex: "FFB400")
        default:      return Color(hex: "F6511D")
        }
    }
}

private extension Color {
    init(hex: String) {
        let v = UInt64(hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
