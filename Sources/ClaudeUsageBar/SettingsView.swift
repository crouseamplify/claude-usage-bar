import SwiftUI

struct SettingsView: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {

            Section("Token Details") {
                Toggle("Input tokens",  isOn: $s.showInput)
                    .help("Tokens you send to Claude — your messages, instructions, and context.")
                Toggle("Output tokens", isOn: $s.showOutput)
                    .help("Tokens Claude generates in response. Output tokens cost more than input.")
                Toggle("Cache read",    isOn: $s.showCacheRead)
                    .help("Tokens reused from Claude's prompt cache. These are billed at a steep discount and reduce latency. Claude Code manages this automatically.")
                Toggle("Cache write",   isOn: $s.showCacheWrite)
                    .help("Tokens written into Claude's prompt cache for reuse in future requests. Slightly more expensive than regular input tokens, but saves cost over time on repeated context.")
            }

            Section("History Rows") {
                Toggle("Show 7-day totals under each metric",  isOn: $s.show7DayHistory)
                    .help("Adds a rolling 7-day total beneath each token count.")
                Toggle("Show 30-day totals under each metric", isOn: $s.show30DayHistory)
                    .help("Adds a rolling 30-day total beneath each token count.")
            }

            Section("Spend") {
                Toggle("Today's estimated spend",  isOn: $s.showSpend)
                    .help("Estimated cost for today based on Anthropic's published per-token pricing.")
                Toggle("7-day spend total",        isOn: $s.show7DaySpend)
                    .help("Rolling cost total for the last 7 days.")
                Toggle("30-day spend total",       isOn: $s.show30DaySpend)
                    .help("Rolling cost total for the last 30 days.")
                Toggle("Today's spend by model",   isOn: $s.showModelBreakdown)
                    .help("Breaks down today's cost by model — useful if you use multiple Claude models and want to see which is driving spend.")
            }

            Section("Charts") {
                Toggle("Show 7-day cost chart",  isOn: $s.show7DayChart)
                    .help("Bar chart showing your estimated daily spend over the last 7 days.")
                Toggle("Show 30-day cost chart", isOn: $s.show30DayChart)
                    .help("Bar chart showing your estimated daily spend over the last 30 days.")
            }

            Section("Menu Bar Style") {
                Picker("Style", selection: Binding(
                    get: { s.menuBarStyle },
                    set: { s.menuBarStyle = $0 }
                )) {
                    ForEach(MenuBarStyle.allCases, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Refresh") {
                Picker("Frequency", selection: Binding(
                    get: { s.refreshMode },
                    set: { s.refreshMode = $0 }
                )) {
                    ForEach(RefreshMode.allCases, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.radioGroup)
            }

        }
        .formStyle(.grouped)
        .frame(width: 340)
        .fixedSize()
        .safeAreaInset(edge: .bottom) {
            Text("Version 1.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
    }
}
