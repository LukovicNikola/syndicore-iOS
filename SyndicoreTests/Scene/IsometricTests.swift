import XCTest
@testable import Syndicore

/// Round-trip i bounds testovi za Isometric projection helpere.
final class IsometricTests: XCTestCase {

    func testRoundTrip_allGridCells() {
        for col in 0..<Isometric.gridSize {
            for row in 0..<Isometric.gridSize {
                let position = Isometric.scenePosition(col: col, row: row)
                let recovered = Isometric.tileCoord(at: position)

                XCTAssertNotNil(recovered, "Round-trip NIL za (\(col),\(row))")
                XCTAssertEqual(recovered?.col, col, "col mismatch na (\(col),\(row))")
                XCTAssertEqual(recovered?.row, row, "row mismatch na (\(col),\(row))")
            }
        }
    }

    func testTileCoord_outOfBounds_returnsNil() {
        let farPoint = CGPoint(x: 10_000, y: 10_000)
        XCTAssertNil(Isometric.tileCoord(at: farPoint))
    }

    func testHQCoord_isCenter() {
        XCTAssertEqual(Isometric.hqCoord.col, 2)
        XCTAssertEqual(Isometric.hqCoord.row, 2)
        XCTAssertTrue(Isometric.isHQ(col: 2, row: 2))
        XCTAssertFalse(Isometric.isHQ(col: 0, row: 0))
    }

    func testZDepth_increasesAwayFromCamera() {
        let front = Isometric.zDepth(col: 0, row: 0)
        let back  = Isometric.zDepth(col: 4, row: 4)
        XCTAssertLessThan(front, back, "Back tile treba viši zDepth za pravilan iso sort")
    }

    func testSlotRoundTrip_all24Slots() {
        var seen = Set<String>()
        for slot in 0..<24 {
            guard let coord = Isometric.coord(forSlot: slot) else {
                XCTFail("Slot \(slot) nije mapiran na coord")
                continue
            }
            XCTAssertFalse(Isometric.isHQ(col: coord.col, row: coord.row), "Slot \(slot) ne sme da mapira na HQ tile")
            let key = "\(coord.col),\(coord.row)"
            XCTAssertFalse(seen.contains(key), "Duplicate coord \(key) za slot \(slot)")
            seen.insert(key)

            let backSlot = Isometric.slot(forCoord: coord.col, row: coord.row)
            XCTAssertEqual(backSlot, slot, "slot↔coord round-trip fail na slot \(slot)")
        }
        XCTAssertEqual(seen.count, 24, "Svih 24 slotova mora da mapira na jedinstvene coord-e")
    }

    func testSlot_invalidBounds_returnsNil() {
        XCTAssertNil(Isometric.coord(forSlot: -1))
        XCTAssertNil(Isometric.coord(forSlot: 25))
    }
}
