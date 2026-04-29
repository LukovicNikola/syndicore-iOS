import Foundation

// MARK: - GET /worlds/:worldId/research

struct ResearchResponse: Codable, Sendable {
    var researchPoints: [String: Int]
    let modifiers: ResearchModifiers
    var pointsAvailable: Int
    var pointsUsed: Int
}

struct ResearchModifiers: Codable, Sendable {
    let atkMultiplier: Double?
    let defMultiplier: Double?
    let spdMultiplier: Double?
    let productionMultiplier: Double?
    let marchSizeBonus: Int?
    let rallyCapacityBonus: Int?
}

// MARK: - POST /worlds/:worldId/research

struct ResearchUpgradeRequest: Codable, Sendable {
    let branch: ResearchBranch
}

struct ResearchUpgradeResponse: Codable, Sendable {
    let result: ResearchResult
}

struct ResearchResult: Codable, Sendable {
    let branch: ResearchBranch
    let previousLevel: Int
    let newLevel: Int
    let cost: [String: Int]
    let pointsUsed: Int
    let pointsRemaining: Int
}

// MARK: - POST /worlds/:worldId/research/respec

struct ResearchRespecResponse: Codable, Sendable {
    let result: RespecResult
}

struct RespecResult: Codable, Sendable {
    let penalty: [String: Int]
}
