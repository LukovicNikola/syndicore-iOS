import XCTest
@testable import Syndicore

/// Round-trip i bounds testovi za Isometric projection helpere.
final class IsometricTests: XCTestCase {

    func testRoundTrip_buildableCells() {
        // Cutout tiles (uglovi) namerno vracaju nil iz tileCoord — preskoci ih.
        for col in 0..<Isometric.gridSize {
            for row in 0..<Isometric.gridSize {
                guard !Isometric.isCutout(col: col, row: row) else { continue }
                let position = Isometric.scenePosition(col: col, row: row)
                let recovered = Isometric.tileCoord(at: position)

                XCTAssertNotNil(recovered, "Round-trip NIL za (\(col),\(row))")
                XCTAssertEqual(recovered?.col, col, "col mismatch na (\(col),\(row))")
                XCTAssertEqual(recovered?.row, row, "row mismatch na (\(col),\(row))")
            }
        }
    }

    func testRoundTrip_cutoutCells_returnNil() {
        for cutout in Isometric.cornerCutouts {
            let position = Isometric.scenePosition(col: cutout.col, row: cutout.row)
            XCTAssertNil(Isometric.tileCoord(at: position), "Cutout (\(cutout.col),\(cutout.row)) treba da vrati nil")
        }
    }

    func testTileCoord_outOfBounds_returnsNil() {
        let farPoint = CGPoint(x: 10_000, y: 10_000)
        XCTAssertNil(Isometric.tileCoord(at: farPoint))
    }

    func testHQRegion_2x2_centered() {
        // HQ origin je top-left od 2×2 regiona — pokriva (2,2)(3,2)(2,3)(3,3)
        XCTAssertEqual(Isometric.hqOriginCoord.col, 2)
        XCTAssertEqual(Isometric.hqOriginCoord.row, 2)
        XCTAssertTrue(Isometric.isHQ(col: 2, row: 2))
        XCTAssertTrue(Isometric.isHQ(col: 3, row: 2))
        XCTAssertTrue(Isometric.isHQ(col: 2, row: 3))
        XCTAssertTrue(Isometric.isHQ(col: 3, row: 3))
        XCTAssertFalse(Isometric.isHQ(col: 1, row: 1))
        XCTAssertFalse(Isometric.isHQ(col: 4, row: 4))
    }

    func testCornerCutouts_12tilesRemoved() {
        XCTAssertEqual(Isometric.cornerCutouts.count, 12, "Octagonal trim treba da skine 12 tile-ova (3 po uglu)")
        XCTAssertTrue(Isometric.isCutout(col: 0, row: 0))
        XCTAssertTrue(Isometric.isCutout(col: 5, row: 5))
        XCTAssertFalse(Isometric.isCutout(col: 2, row: 2))  // HQ tile, ne cutout
    }

    func testBuildableCount_is20() {
        XCTAssertEqual(Isometric.buildableSlotCount, 20, "6×6 (36) - 4 HQ - 12 cutouts = 20")
    }

    func testZDepth_increasesAwayFromCamera() {
        let front = Isometric.zDepth(col: 0, row: 0)
        let back  = Isometric.zDepth(col: 4, row: 4)
        XCTAssertLessThan(front, back, "Back tile treba viši zDepth za pravilan iso sort")
    }

    func testSlotRoundTrip_all20Slots() {
        var seen = Set<String>()
        for slot in 0..<Isometric.buildableSlotCount {
            guard let coord = Isometric.coord(forSlot: slot) else {
                XCTFail("Slot \(slot) nije mapiran na coord")
                continue
            }
            XCTAssertTrue(Isometric.isBuildable(col: coord.col, row: coord.row), "Slot \(slot) mora biti buildable")
            let key = "\(coord.col),\(coord.row)"
            XCTAssertFalse(seen.contains(key), "Duplicate coord \(key) za slot \(slot)")
            seen.insert(key)

            let backSlot = Isometric.slot(forCoord: coord.col, row: coord.row)
            XCTAssertEqual(backSlot, slot, "slot↔coord round-trip fail na slot \(slot)")
        }
        XCTAssertEqual(seen.count, 20)
    }

    func testSlot_invalidBounds_returnsNil() {
        XCTAssertNil(Isometric.coord(forSlot: -1))
        XCTAssertNil(Isometric.coord(forSlot: 100))
    }

    func testHQCenterPosition_isBetweenFourTiles() {
        let center = Isometric.hqCenterPosition
        let tile22 = Isometric.scenePosition(col: 2, row: 2)
        let tile33 = Isometric.scenePosition(col: 3, row: 3)
        XCTAssertEqual(center.x, (tile22.x + tile33.x) / 2, accuracy: 0.01)
        XCTAssertEqual(center.y, (tile22.y + tile33.y) / 2, accuracy: 0.01)
    }
}
