import Foundation

// MARK: - JSONL decoding

struct SessionMessage: Decodable {
    let type: String?
    let timestamp: String?
    let message: APIMessage?
}

struct APIMessage: Decodable {
    let model: String?
    let usage: TokenUsage?
}

struct CacheCreation: Decodable {
    let ephemeral5mInputTokens: Int?
    let ephemeral1hInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
        case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
    }
}

struct TokenUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheCreation: CacheCreation?

    enum CodingKeys: String, CodingKey {
        case inputTokens                = "input_tokens"
        case outputTokens               = "output_tokens"
        case cacheReadInputTokens       = "cache_read_input_tokens"
        case cacheCreationInputTokens   = "cache_creation_input_tokens"
        case cacheCreation              = "cache_creation"
    }

    var cacheWrite5mTokens: Int { cacheCreation?.ephemeral5mInputTokens ?? cacheCreationInputTokens ?? 0 }
    var cacheWrite1hTokens: Int { cacheCreation?.ephemeral1hInputTokens ?? 0 }
}

// MARK: - Aggregated result

struct DayUsage {
    var inputTokens: Int        = 0
    var outputTokens: Int       = 0
    var cacheReadTokens: Int    = 0
    var cacheWriteTokens: Int   = 0
    var messageCount: Int       = 0
    var estimatedCost: Double   = 0.0

    var totalTokens: Int { inputTokens + outputTokens }

    static let empty = DayUsage()

    mutating func add(tokenUsage: TokenUsage, pricing: ModelPricing) {
        inputTokens      += tokenUsage.inputTokens          ?? 0
        outputTokens     += tokenUsage.outputTokens         ?? 0
        cacheReadTokens  += tokenUsage.cacheReadInputTokens ?? 0
        cacheWriteTokens += tokenUsage.cacheWrite5mTokens + tokenUsage.cacheWrite1hTokens
        estimatedCost    += pricing.cost(usage: tokenUsage)
        messageCount     += 1
    }
}

// MARK: - Per-day chart point

struct DailyPoint: Identifiable {
    let date: Date
    var usage: DayUsage = .empty
    var id: Date { date }
}

// MARK: - Per-model cost breakdown (today only)

struct ModelCost {
    var cost: Double = 0.0
    var messageCount: Int = 0

    mutating func add(tokenUsage: TokenUsage, pricing: ModelPricing) {
        cost += pricing.cost(usage: tokenUsage)
        messageCount += 1
    }
}

// MARK: - Per-project summary

struct ProjectSummary {
    var displayName: String
    var today       = DayUsage()
    var sevenDay    = DayUsage()
    var thirtyDay   = DayUsage()
    var todayByModel: [String: ModelCost] = [:]
}

// MARK: - Multi-period summary (all built in a single file-scan pass)

struct UsageSummary {
    var today     = DayUsage()
    var sevenDay  = DayUsage()   // rolling 7 days including today
    var thirtyDay = DayUsage()   // rolling 30 days including today
    var dailyPoints: [DailyPoint] = []  // 30 days sorted oldest→newest, every day present
    var todayByModel: [String: ModelCost] = [:]
    var byProject:  [String: ProjectSummary] = [:]  // key = sanitized folder name
}

// MARK: - Pricing table (per million tokens, USD)
//
// Source: https://platform.claude.com/docs/en/about-claude/pricing (fetched 2026-07-14)

struct ModelPricing {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite5m: Double
    let cacheWrite1h: Double
}

/// A pricing tier effective starting `effectiveFrom`. Per-model tier lists are sorted
/// ascending by `effectiveFrom`; lookups use the latest tier whose `effectiveFrom` is on
/// or before the *message's* timestamp — so a rate change (e.g. Sonnet 5's Sept 1, 2026
/// step up from introductory pricing) only applies to usage recorded from that date
/// forward and never rewrites the cost of past messages.
private struct PricingTier {
    let effectiveFrom: Date
    let pricing: ModelPricing
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

extension ModelPricing {

    private static let schedule: [String: [PricingTier]] = [
        // Claude Fable 5 / Claude Mythos 5 — $10/$50
        "claude-fable-5":               [.init(effectiveFrom: .distantPast, pricing: .init(input: 10.00, output: 50.00, cacheRead: 1.00, cacheWrite5m: 12.50, cacheWrite1h: 20.00))],
        "claude-mythos-5":              [.init(effectiveFrom: .distantPast, pricing: .init(input: 10.00, output: 50.00, cacheRead: 1.00, cacheWrite5m: 12.50, cacheWrite1h: 20.00))],

        // Opus 4 family — $5/$25
        "claude-opus-4-8":              [.init(effectiveFrom: .distantPast, pricing: .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00))],
        "claude-opus-4-7":              [.init(effectiveFrom: .distantPast, pricing: .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00))],
        "claude-opus-4-6":              [.init(effectiveFrom: .distantPast, pricing: .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00))],
        "claude-opus-4-5":              [.init(effectiveFrom: .distantPast, pricing: .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00))],

        // Opus 4.1 / Opus 4 — $15/$75
        "claude-opus-4-1":              [.init(effectiveFrom: .distantPast, pricing: .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00))],
        "claude-opus-4-0":              [.init(effectiveFrom: .distantPast, pricing: .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00))],

        // Claude Sonnet 5 — introductory $2/$10 through 2026-08-31, then standard $3/$15
        "claude-sonnet-5": [
            .init(effectiveFrom: .distantPast,        pricing: .init(input: 2.00, output: 10.00, cacheRead: 0.20, cacheWrite5m: 2.50, cacheWrite1h: 4.00)),
            .init(effectiveFrom: utcDate(2026, 9, 1),  pricing: .init(input: 3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m: 3.75, cacheWrite1h: 6.00)),
        ],

        // Sonnet 4 family — $3/$15
        "claude-sonnet-4-6":            [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],
        "claude-sonnet-4-5":            [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],
        "claude-sonnet-4-5-20250929":   [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],
        "claude-sonnet-4-0":            [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],
        "claude-sonnet-3-7":            [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],
        "claude-sonnet-3-7-20250219":   [.init(effectiveFrom: .distantPast, pricing: .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00))],

        // Haiku 4.5 — $1/$5
        "claude-haiku-4-5":             [.init(effectiveFrom: .distantPast, pricing: .init(input:  1.00, output:  5.00, cacheRead: 0.10, cacheWrite5m:  1.25, cacheWrite1h:  2.00))],
        "claude-haiku-4-5-20251001":    [.init(effectiveFrom: .distantPast, pricing: .init(input:  1.00, output:  5.00, cacheRead: 0.10, cacheWrite5m:  1.25, cacheWrite1h:  2.00))],

        // Haiku 3.5 — $0.80/$4
        "claude-haiku-3-5":             [.init(effectiveFrom: .distantPast, pricing: .init(input:  0.80, output:  4.00, cacheRead: 0.08, cacheWrite5m:  1.00, cacheWrite1h:  1.60))],
        "claude-haiku-3-5-20241022":    [.init(effectiveFrom: .distantPast, pricing: .init(input:  0.80, output:  4.00, cacheRead: 0.08, cacheWrite5m:  1.00, cacheWrite1h:  1.60))],

        // Legacy Opus 3 — $15/$75
        "claude-opus-3-20240229":       [.init(effectiveFrom: .distantPast, pricing: .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00))],

        // Legacy Haiku 3 — $0.25/$1.25
        "claude-haiku-3":               [.init(effectiveFrom: .distantPast, pricing: .init(input:  0.25, output:  1.25, cacheRead: 0.03, cacheWrite5m:  0.30, cacheWrite1h:  0.50))],
        "claude-haiku-3-20240307":      [.init(effectiveFrom: .distantPast, pricing: .init(input:  0.25, output:  1.25, cacheRead: 0.03, cacheWrite5m:  0.30, cacheWrite1h:  0.50))],
    ]

    // Fall back to Sonnet pricing for unknown/future models
    static let `default` = ModelPricing(input: 3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m: 3.75, cacheWrite1h: 6.00)

    /// - Parameter messageDate: the timestamp of the message being priced (defaults to
    ///   now). Determines which pricing tier applies for models with scheduled rate
    ///   changes, so re-scanning old sessions never reprices them at today's rate.
    static func forModel(_ model: String?, messageDate: Date = Date()) -> ModelPricing {
        guard let model, let tiers = schedule[model] else { return .default }
        var result = tiers[0].pricing
        for tier in tiers where tier.effectiveFrom <= messageDate {
            result = tier.pricing
        }
        return result
    }

    func cost(usage: TokenUsage) -> Double {
        let M = 1_000_000.0
        return Double(usage.inputTokens          ?? 0) / M * input
             + Double(usage.outputTokens         ?? 0) / M * output
             + Double(usage.cacheReadInputTokens ?? 0) / M * cacheRead
             + Double(usage.cacheWrite5mTokens)        / M * cacheWrite5m
             + Double(usage.cacheWrite1hTokens)        / M * cacheWrite1h
    }
}
