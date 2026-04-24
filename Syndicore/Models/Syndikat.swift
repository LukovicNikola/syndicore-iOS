import Foundation

// MARK: - Full Syndikat (from GET /syndikats/:id)

struct Syndikat: Codable, Identifiable {
    let id: String
    let name: String
    let tag: String
    let memberCount: Int?
    let createdAt: Date?
    let members: [SyndikatMember]?
}

struct SyndikatMember: Codable, Identifiable {
    var id: String { playerWorldId }
    let playerWorldId: String
    let playerId: String?
    let username: String
    let faction: Faction
    let role: SyndikatRole
}

// MARK: - API Responses

struct SyndikatsListResponse: Codable {
    let syndikats: [Syndikat]
}

struct SyndikatDetailResponse: Codable {
    let syndikat: Syndikat
}

struct CreateSyndikatResponse: Codable {
    let syndikat: Syndikat
}

struct JoinSyndikatResponse: Codable {
    let joined: Bool
}

struct LeaveSyndikatResponse: Codable {
    let left: Bool
}

struct UpdateRoleResponse: Codable {
    let updated: Bool
}

struct KickMemberResponse: Codable {
    let kicked: Bool
}

struct DiplomacyResponse: Codable {
    let updated: Bool
    let status: DiplomacyStatus
}

// MARK: - Request Bodies

struct CreateSyndikatRequest: Codable, Sendable {
    let name: String
    let tag: String
}

struct UpdateRoleRequest: Codable, Sendable {
    let targetPlayerWorldId: String
    let role: String
}

struct KickMemberRequest: Codable, Sendable {
    let targetPlayerWorldId: String
}

struct DiplomacyRequest: Codable, Sendable {
    let targetSyndikatId: String
    let status: String
}
