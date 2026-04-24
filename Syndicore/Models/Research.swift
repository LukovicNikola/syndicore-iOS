import Foundation

// MARK: - GET /worlds/:worldId/research

struct ResearchResponse: Codable {
    var researchPoints: [String: Int]
    let modifiers: ResearchModifiers
    var pointsAvailable: Int
    var pointsUsed: Int
}

struct ResearchModifiers: Codable {
    let atkMultiplier: Double?
    let defMultiplier: Double?
    let spdMultiplier: Double?
    let productionMultiplier: Double?
    let marchSizeBonus: Int?
    let rallyCapacityBonus: Int?
}

// MARK: - POST /worlds/:worldId/research

struct ResearchUpgradeRequest: Codable, Sendable {
    let branch: String
}

struct ResearchUpgradeResponse: Codable {
    let result: ResearchResult
}

struct ResearchResult: Codable {
    let branch: String
    let previousLevel: Int
    let newLevel: Int
    let cost: [String: Int]
    let pointsUsed: Int
    let pointsRemaining: Int
}

// MARK: - POST /worlds/:worldId/research/respec

struct ResearchRespecResponse: Codable {
    let result: RespecResult
}

struct RespecResult: Codable {
    let penalty: [String: Int]
}
