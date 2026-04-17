import XCTest
@testable import Syndicore

/// Unit testovi za JSON decoding svih Codable modela.
/// Fixtures su u SyndicoreTests/Fixtures/ i moraju biti dodati u test target bundle.
final class DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json")
        guard let url else {
            XCTFail("Fixture \(name).json nije pronađen u test bundle-u. Proveri da li je fajl dodat u target.")
            return Data()
        }
        return try Data(contentsOf: url)
    }

    // MARK: - City

    func testDecode_CityResponse_fullPayload() throws {
        let data = try loadFixture("city")
        let response = try JSONDecoder.api.decode(CityResponse.self, from: data)

        XCTAssertEqual(response.city.id, "city-uuid-123")
        XCTAssertEqual(response.city.name, "Test Base")

        let resources = try XCTUnwrap(response.city.resources)
        XCTAssertEqual(resources.credits, 1500.5, accuracy: 0.01)
        XCTAssertEqual(resources.energy, 100.0)

        let buildings = try XCTUnwrap(response.city.buildings)
        XCTAssertEqual(buildings.count, 2)
        let barracks = try XCTUnwrap(buildings.first { $0.type == .BARRACKS })
        XCTAssertTrue(barracks.isUpgrading, "BARRACKS sa targetLevel+endsAt treba da je isUpgrading")
        XCTAssertEqual(barracks.targetLevel, 4)
    }

    // MARK: - Battle Report (ArmySnapshot sa [UnitType: Int])

    func testDecode_BattleReport_armySnapshot() throws {
        let data = try loadFixture("battle_report")
        let report = try JSONDecoder.api.decode(BattleReport.self, from: data)

        XCTAssertTrue(report.attackerWon)
        XCTAssertEqual(report.attackerUnits.before[.GRUNT], 50)
        XCTAssertEqual(report.attackerUnits.lost[.GRUNT], 15)
        XCTAssertEqual(report.defenderUnits.after[.GRUNT], 0)
    }

    // MARK: - Date decoding

    func testDecode_ISO8601WithFractionalSeconds() throws {
        let json = #"{"date":"2026-05-01T12:34:56.789Z"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let date: Date }
        let wrapper = try JSONDecoder.api.decode(Wrapper.self, from: json)

        let expected = ISO8601DateFormatter().date(from: "2026-05-01T12:34:56Z")!
        XCTAssertEqual(wrapper.date.timeIntervalSince(expected), 0.789, accuracy: 0.01)
    }

    func testDecode_ISO8601WithoutFractionalSeconds_fallback() throws {
        let json = #"{"date":"2026-05-01T12:34:56Z"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let date: Date }
        XCTAssertNoThrow(try JSONDecoder.api.decode(Wrapper.self, from: json))
    }

    func testDecode_InvalidDate_throws() throws {
        let json = #"{"date":"not-a-date"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let date: Date }
        XCTAssertThrowsError(try JSONDecoder.api.decode(Wrapper.self, from: json))
    }
}
