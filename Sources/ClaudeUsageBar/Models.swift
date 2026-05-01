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

struct TokenUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens                = "input_tokens"
        case outputTokens               = "output_tokens"
        case cacheReadInputTokens       = "cache_read_input_tokens"
        case cacheCreationInputTokens   = "cache_creation_input_tokens"
    }
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
        inputTokens      += tokenUsage.inputTokens              ?? 0
        outputTokens     += tokenUsage.outputTokens             ?? 0
        cacheReadTokens  += tokenUsage.cacheReadInputTokens     ?? 0
        cacheWriteTokens += tokenUsage.cacheCreationInputTokens ?? 0
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

// MARK: - Multi-period summary (all built in a single file-scan pass)

struct UsageSummary {
    var today     = DayUsage()
    var sevenDay  = DayUsage()   // rolling 7 days including today
    var thirtyDay = DayUsage()   // rolling 30 days including today
    var dailyPoints: [DailyPoint] = []  // 30 days sorted oldest→newest, every day present
    var todayByModel: [String: ModelCost] = [:]
}

// MARK: - Pricing table (per million tokens, USD)

struct ModelPricing {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite: Double

    static let table: [String: ModelPricing] = [
        "claude-opus-4-7":             .init(input: 15.00, output: 75.00, cacheRead: 1.50,  cacheWrite: 18.75),
        "claude-sonnet-4-6":           .init(input:  3.00, output: 15.00, cacheRead: 0.30,  cacheWrite:  3.75),
        "claude-sonnet-4-5-20250929":  .init(input:  3.00, output: 15.00, cacheRead: 0.30,  cacheWrite:  3.75),
        "claude-haiku-4-5-20251001":   .init(input:  0.80, output:  4.00, cacheRead: 0.08,  cacheWrite:  1.00),
    ]

    // Fall back to Sonnet pricing for unknown/future models
    static let `default` = ModelPricing(input: 3.00, output: 15.00, cacheRead: 0.30, cacheWrite: 3.75)

    static func forModel(_ model: String?) -> ModelPricing {
        guard let model else { return .default }
        return table[model] ?? .default
    }

    func cost(usage: TokenUsage) -> Double {
        let M = 1_000_000.0
        return Double(usage.inputTokens              ?? 0) / M * input
             + Double(usage.outputTokens             ?? 0) / M * output
             + Double(usage.cacheReadInputTokens     ?? 0) / M * cacheRead
             + Double(usage.cacheCreationInputTokens ?? 0) / M * cacheWrite
    }
}
