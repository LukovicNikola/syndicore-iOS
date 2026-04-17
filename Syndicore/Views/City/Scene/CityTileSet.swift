import SpriteKit

enum CityTileSet {
    static let tileSize = CGSize(width: 128, height: 64)

    static func build() -> SKTileSet {
        // Empty tile group
        let emptyTex = SKTexture(imageNamed: "tile_empty_v1")
        let emptyDef = SKTileDefinition(texture: emptyTex, size: tileSize)
        let emptyGroup = SKTileGroup(tileDefinition: emptyDef)
        emptyGroup.name = "empty"

        // Selected tile group
        let selectedTex = SKTexture(imageNamed: "tile_selected_v1")
        let selectedDef = SKTileDefinition(texture: selectedTex, size: tileSize)
        let selectedGroup = SKTileGroup(tileDefinition: selectedDef)
        selectedGroup.name = "selected"

        let tileSet = SKTileSet(tileGroups: [emptyGroup, selectedGroup],
                                tileSetType: .isometric)
        tileSet.defaultTileSize = tileSize
        return tileSet
    }

    static func emptyGroup(in tileSet: SKTileSet) -> SKTileGroup? {
        tileSet.tileGroups.first { $0.name == "empty" }
    }

    static func selectedGroup(in tileSet: SKTileSet) -> SKTileGroup? {
        tileSet.tileGroups.first { $0.name == "selected" }
    }
}
