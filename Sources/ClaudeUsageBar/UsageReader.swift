import Foundation

struct UsageReader {

    static func read() -> UsageSummary {
        let buckets = DateBuckets()
        let projectsURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/projects")

        // Pre-fill daily points so every day in the 30-day window is present
        var perDay: [String: DayUsage] = [:]
        for key in buckets.allKeys { perDay[key] = .empty }

        var summary = UsageSummary()

        if let enumerator = FileManager.default.enumerator(
            at: projectsURL, includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                parseJSONL(at: url, buckets: buckets, summary: &summary, perDay: &perDay)
            }
        }

        // Build sorted daily points
        summary.dailyPoints = buckets.allKeys
            .sorted()
            .compactMap { key -> DailyPoint? in
                guard let date = buckets.dateFor(key: key),
                      let usage = perDay[key] else { return nil }
                return DailyPoint(date: date, usage: usage)
            }

        return summary
    }

    // MARK: - Private

    private static func parseJSONL(
        at url: URL,
        buckets: DateBuckets,
        summary: inout UsageSummary,
        perDay: inout [String: DayUsage]
    ) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let decoder = JSONDecoder()

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let data = Data(line.utf8)
            guard let msg = try? decoder.decode(SessionMessage.self, from: data),
                  msg.type == "assistant",
                  let ts = msg.timestamp,
                  let apiMsg = msg.message,
                  let tokenUsage = apiMsg.usage
            else { continue }

            let day = String(ts.prefix(10))
            let pricing = ModelPricing.forModel(apiMsg.model)

            if day == buckets.today {
                summary.today.add(tokenUsage: tokenUsage, pricing: pricing)
                summary.sevenDay.add(tokenUsage: tokenUsage, pricing: pricing)
                summary.thirtyDay.add(tokenUsage: tokenUsage, pricing: pricing)
                perDay[day]?.add(tokenUsage: tokenUsage, pricing: pricing)
                let modelKey = apiMsg.model ?? "unknown"
                summary.todayByModel[modelKey, default: ModelCost()]
                    .add(tokenUsage: tokenUsage, pricing: pricing)
            } else if buckets.sevenDaySet.contains(day) {
                summary.sevenDay.add(tokenUsage: tokenUsage, pricing: pricing)
                summary.thirtyDay.add(tokenUsage: tokenUsage, pricing: pricing)
                perDay[day]?.add(tokenUsage: tokenUsage, pricing: pricing)
            } else if buckets.thirtyDaySet.contains(day) {
                summary.thirtyDay.add(tokenUsage: tokenUsage, pricing: pricing)
                perDay[day]?.add(tokenUsage: tokenUsage, pricing: pricing)
            }
        }
    }
}

// MARK: - Date helpers

struct DateBuckets {
    let today: String
    let sevenDaySet: Set<String>
    let thirtyDaySet: Set<String>
    let allKeys: [String]
    private let keyToDate: [String: Date]

    init() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        let cal = Calendar.current
        let now = Date()

        func key(_ offset: Int) -> String {
            fmt.string(from: cal.date(byAdding: .day, value: offset, to: now)!)
        }

        let todayKey   = key(0)
        let sevenKeys  = (1...6).map  { key(-$0) }
        let thirtyKeys = (7...29).map { key(-$0) }
        let all        = [todayKey] + sevenKeys + thirtyKeys

        today        = todayKey
        sevenDaySet  = Set(sevenKeys)
        thirtyDaySet = Set(thirtyKeys)
        allKeys      = all
        keyToDate    = Dictionary(uniqueKeysWithValues: all.compactMap { k in
            fmt.date(from: k).map { (k, $0) }
        })
    }

    func dateFor(key: String) -> Date? { keyToDate[key] }
}
