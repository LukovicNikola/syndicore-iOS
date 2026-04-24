import Foundation

struct ErrorResponse: Codable {
    let error: String
    let details: [String: AnyCodableValue]?

    /// Parsed version of `error` kao structured enum — null ako je BE vratio
    /// code koji iOS klijent ne zna (nov feature, typo, itd).
    var code: BEErrorCode? { BEErrorCode(rawValue: error) }
}

/// Strongly-typed katalog BE error code-ova.
/// Dodaj nov case ovde kad BE uvede nov error code — lepše od string match-a.
enum BEErrorCode: String {
    case alreadyOnboarded      = "already_onboarded"
    case usernameTaken         = "username_taken"
    case onboardingRequired    = "onboarding_required"
    case insufficientResources = "insufficient_resources"
    case queueFull             = "queue_full"
    case buildingLocked        = "building_locked"
    case notAuthenticated      = "not_authenticated"
    case validationFailed      = "validation_failed"
    /// Returned kad REINFORCE/TRANSPORT cilja grad koji nije u istom syndikat-u
    /// niti ima PACT diplomatiju sa attacker-om.
    case notAllied             = "not_allied"
    /// Crystal Implosion: HQ nije na max level-u (20)
    case hqNotMaxLevel         = "hq_not_max_level"
    /// Crystal Implosion: igrač je već u NEXUS ringu, ne može dalje
    case alreadyNexus          = "already_nexus"
    /// Crystal Implosion: postoje aktivni troop movements (incoming ili outgoing)
    case activeMovements       = "active_movements"
    /// Crystal Implosion: postoji aktivna construction queue
    case activeConstruction    = "active_construction"
    /// Crystal Implosion: nema SETTLER jedinice u gradu
    case noSettler             = "no_settler"
    // Session enforcement
    case missingDeviceId       = "missing_device_id"
    case noActiveSession       = "no_active_session"
    case sessionInvalidated    = "session_invalidated"
    case invalidDeviceId       = "invalid_device_id"
    // Rally
    case insufficientRank      = "insufficient_rank"
    case rallyPointRequired    = "rally_point_required"
    case rallyPointLevelTooLow = "rally_point_level_too_low"
    case maxActiveRalliesReached = "max_active_rallies_reached"
    case insufficientTroops    = "insufficient_troops"
    case launchAtInPast        = "launch_at_in_past"
    case invalidTargetTile     = "invalid_target_tile"
    case notSameSyndikat       = "not_same_syndikat"
    case rallyNotForming       = "rally_not_forming"
    case rallyLaunchWindowClosed = "rally_launch_window_closed"
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden(ErrorResponse)
    case onboardingRequired(OnboardingRequiredResponse)
    case notFound
    case conflict(ErrorResponse)
    case badRequest(ErrorResponse)
    case server(ErrorResponse)
    case networkError(Error)
    case decodingError(Error)
    case unexpectedStatus(Int, Data)
    case timeout(TimeInterval)
    /// Session kicked — another device claimed this account
    case sessionKicked
    /// No active session — need to call POST /me/session/claim
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .unauthorized: "Unauthorized — please sign in again"
        case .sessionKicked: "Signed out — account opened on another device"
        case .noActiveSession: "Session not claimed"
        case .forbidden(let err): err.error
        case .onboardingRequired: "Onboarding required"
        case .notFound: "Not found"
        case .conflict(let err): err.error
        case .badRequest(let err): err.error
        case .server(let err): err.error
        case .networkError(let err): err.localizedDescription
        case .decodingError(let err): "Decoding error: \(err.localizedDescription)"
        case .unexpectedStatus(let code, _): "Unexpected status: \(code)"
        case .timeout(let seconds): "Request timed out after \(Int(seconds))s"
        }
    }
}

/// Type-erased Codable value for dynamic JSON fields.
/// Supports scalars + nested arrays/objects da BE `details` field može da
/// vrati bilo kakav JSON bez puknuća decode-a.
indirect enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode([AnyCodableValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: AnyCodableValue].self) { self = .object(v) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        case .array(let v):  try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}
