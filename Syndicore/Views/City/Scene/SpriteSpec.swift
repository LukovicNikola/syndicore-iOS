import CoreGraphics
import SpriteKit
import UIKit

/// Specifikacija jednog sprajta — kako se mapira iz izvornog PNG-a u scene units.
///
/// Izvorne dimenzije: svi sprajtovi su rendered prema **`sprite_spec_v2`** standardu:
/// - 1×1 building: 1024×1024 PNG, ground diamond u donjoj polovini
/// - 2×2 building (HQ): 2048×1536 PNG, ground diamond u donjoj polovini
/// - tile: 1024×512 PNG (full diamond, no building above)
///
/// Anchor pravila:
/// - Za sprajt sa "ground at bottom half", anchor = (0.5, 0.25)
/// - Za pure tile (full sprite je diamond), anchor = (0.5, 0.5)
struct SpriteSpec {
    /// Naziv asset-a u `Assets.xcassets` (bez ekstenzije).
    let assetName: String
    /// Footprint u broju tile-ova (cols × rows). 1×1 za većinu, 2×2 za HQ.
    let footprint: (cols: Int, rows: Int)
    /// Render visina sprajta u scene units (širinu računamo proporcionalno).
    /// Za "rises tall above ground" sprajt (1024×1024 source), visina = tileWidth × footprint.cols.
    let renderHeight: CGFloat
    /// Anchor point — gde u sprajtu sedi "kontaktna tačka" sa tile-om.
    let anchor: CGPoint

    /// Računa render size na osnovu footprint-a i izvornog aspect ratio-a (1:1).
    var renderSize: CGSize {
        // Za 1×1 footprint, ground diamond je tileWidth wide. Sprite je kvadratan (1:1),
        // pa je renderWidth = renderHeight (uniform proportional scaling).
        // Za 2×2, sve duplo.
        let width = renderHeight  // uniform 1:1 scaling — sprite je kvadrat
        return CGSize(width: width, height: renderHeight)
    }
}

/// Centralni katalog sprite spec-ova — single source of truth.
/// Kad se generiše nov sprajt, samo dodaj u ovaj enum.
enum SpriteCatalog {

    /// HQ — 2×2 footprint. Source: 2048×1536 PNG.
    /// Render: 2 × tileWidth wide × 2 × tileWidth tall (proporcionalno).
    static let hq = SpriteSpec(
        assetName: "hq_pyramid_v1",
        footprint: (cols: 2, rows: 2),
        renderHeight: Isometric.tileWidth * 2,  // 256
        anchor: CGPoint(x: 0.5, y: 0.25)         // ground at bottom quarter (per spec)
    )

    /// Standardna spec za 1×1 buildings. Sve buildings cited u SpriteCatalog.spec(for:) koriste ovo.
    static func standardBuilding(assetName: String) -> SpriteSpec {
        SpriteSpec(
            assetName: assetName,
            footprint: (cols: 1, rows: 1),
            renderHeight: Isometric.tileWidth,  // 128 — uniform 1:1
            anchor: CGPoint(x: 0.5, y: 0.25)
        )
    }

    /// Spec za dati BuildingType. Vraca nil ako asset ne postoji u bundle-u
    /// (BuildingNode tada može da koristi placeholder).
    static func spec(for buildingType: BuildingType) -> SpriteSpec {
        if buildingType == .HQ { return hq }
        return standardBuilding(assetName: "\(buildingType.rawValue.lowercased())_v1")
    }

    /// Provera da li asset za dati spec stvarno postoji u bundle-u.
    static func assetExists(_ spec: SpriteSpec) -> Bool {
        UIImage(named: spec.assetName) != nil
    }
}
