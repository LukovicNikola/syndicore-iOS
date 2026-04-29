import Foundation

/// Centralizovani JSONDecoder/JSONEncoder za sve BE pozive.
/// BE šalje ISO8601 sa fractional seconds ("2026-05-01T00:00:00.000Z"),
/// sa fallback-om na bez fractional seconds za robusnost.
extension JSONDecoder {
    /// Default API decoder — ISO8601 sa fractional seconds + fallback.
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = customDateStrategy
        return decoder
    }()

    /// Alternativni decoder za game-constants.json — keyDecodingStrategy = snake_case
    /// + isti date handling kao `api`.
    static let apiSnakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = customDateStrategy
        return decoder
    }()

    private static let customDateStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoderCtx in
        let container = try decoderCtx.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = ISO8601DateCoder.dateWithFractionalSeconds(from: string) {
            return date
        }
        if let date = ISO8601DateCoder.dateWithoutFractionalSeconds(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(string)"
        )
    }
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoderCtx in
            var container = encoderCtx.singleValueContainer()
            try container.encode(ISO8601DateCoder.stringWithFractionalSeconds(from: date))
        }
        return encoder
    }()
}

/// Thread-safe ISO8601 formatter wrapper. ISO8601DateFormatter is documented
/// safe for concurrent use as long as formatOptions stays immutable — we hold
/// two instances (with/without fractional seconds) instead of mutating one.
/// Wrapped in @unchecked Sendable storage so static let satisfies Swift 6.
enum ISO8601DateCoder {
    private struct SendableFormatter: @unchecked Sendable {
        let formatter: ISO8601DateFormatter
    }

    private static let withFractional: SendableFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return SendableFormatter(formatter: f)
    }()

    private static let withoutFractional: SendableFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return SendableFormatter(formatter: f)
    }()

    static func dateWithFractionalSeconds(from string: String) -> Date? {
        withFractional.formatter.date(from: string)
    }

    static func dateWithoutFractionalSeconds(from string: String) -> Date? {
        withoutFractional.formatter.date(from: string)
    }

    static func stringWithFractionalSeconds(from date: Date) -> String {
        withFractional.formatter.string(from: date)
    }
}
