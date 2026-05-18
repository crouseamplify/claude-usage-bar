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

struct ModelPricing {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite5m: Double
    let cacheWrite1h: Double

    static let table: [String: ModelPricing] = [
        // Opus 4 family — $5/$25
        "claude-opus-4-7":              .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00),
        "claude-opus-4-6":              .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00),
        "claude-opus-4-5":              .init(input:  5.00, output: 25.00, cacheRead: 0.50, cacheWrite5m:  6.25, cacheWrite1h: 10.00),

        // Opus 4.1 / Opus 4 — $15/$75
        "claude-opus-4-1":              .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00),
        "claude-opus-4-0":              .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00),

        // Sonnet 4 family — $3/$15
        "claude-sonnet-4-6":            .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),
        "claude-sonnet-4-5":            .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),
        "claude-sonnet-4-5-20250929":   .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),
        "claude-sonnet-4-0":            .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),
        "claude-sonnet-3-7":            .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),
        "claude-sonnet-3-7-20250219":   .init(input:  3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m:  3.75, cacheWrite1h:  6.00),

        // Haiku 4.5 — $1/$5
        "claude-haiku-4-5":             .init(input:  1.00, output:  5.00, cacheRead: 0.10, cacheWrite5m:  1.25, cacheWrite1h:  2.00),
        "claude-haiku-4-5-20251001":    .init(input:  1.00, output:  5.00, cacheRead: 0.10, cacheWrite5m:  1.25, cacheWrite1h:  2.00),

        // Haiku 3.5 — $0.80/$4
        "claude-haiku-3-5":             .init(input:  0.80, output:  4.00, cacheRead: 0.08, cacheWrite5m:  1.00, cacheWrite1h:  1.60),
        "claude-haiku-3-5-20241022":    .init(input:  0.80, output:  4.00, cacheRead: 0.08, cacheWrite5m:  1.00, cacheWrite1h:  1.60),

        // Legacy Opus 3 — $15/$75
        "claude-opus-3-20240229":       .init(input: 15.00, output: 75.00, cacheRead: 1.50, cacheWrite5m: 18.75, cacheWrite1h: 30.00),

        // Legacy Haiku 3 — $0.25/$1.25
        "claude-haiku-3":               .init(input:  0.25, output:  1.25, cacheRead: 0.03, cacheWrite5m:  0.30, cacheWrite1h:  0.50),
        "claude-haiku-3-20240307":      .init(input:  0.25, output:  1.25, cacheRead: 0.03, cacheWrite5m:  0.30, cacheWrite1h:  0.50),
    ]

    // Fall back to Sonnet pricing for unknown/future models
    static let `default` = ModelPricing(input: 3.00, output: 15.00, cacheRead: 0.30, cacheWrite5m: 3.75, cacheWrite1h: 6.00)

    static func forModel(_ model: String?) -> ModelPricing {
        guard let model else { return .default }
        return table[model] ?? .default
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
