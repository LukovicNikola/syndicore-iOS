import Foundation

struct ErrorResponse: Codable {
    let error: String
    let details: [String: AnyCodableValue]?
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case onboardingRequired(OnboardingRequiredResponse)
    case notFound
    case conflict(ErrorResponse)
    case badRequest(ErrorResponse)
    case server(ErrorResponse)
    case networkError(Error)
    case decodingError(Error)
    case unexpectedStatus(Int, Data)
    case timeout(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .unauthorized: "Unauthorized — please sign in again"
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
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
