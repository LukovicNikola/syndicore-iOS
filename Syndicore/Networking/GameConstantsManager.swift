import Foundation
import Observation

@Observable
final class GameConstantsManager {
    private let api: APIClient

    private(set) var isLoaded = false
    private(set) var rawJSON: Data?
    private(set) var gameData: GameData?
    private var etag: String?

    private let etagKey = "gameConstants.etag"
    private let dataKey = "gameConstants.data"

    init(api: APIClient) {
        self.api = api
        self.etag = UserDefaults.standard.string(forKey: etagKey)
        if let data = UserDefaults.standard.data(forKey: dataKey) {
            self.rawJSON = data
            self.gameData = Self.decode(data)
            self.isLoaded = gameData != nil
        }
    }

    func refresh() async {
        do {
            let result = try await api.gameConstants(etag: etag)
            switch result {
            case .notModified:
                if gameData == nil, let data = rawJSON {
                    gameData = Self.decode(data)
                }
                isLoaded = gameData != nil
            case .updated(let data, let newEtag):
                gameData = Self.decode(data)
                if gameData != nil {
                    rawJSON = data
                    etag = newEtag
                    UserDefaults.standard.set(newEtag, forKey: etagKey)
                    UserDefaults.standard.set(data, forKey: dataKey)
                }
                isLoaded = gameData != nil
            }
        } catch {
            // Cached data still valid if available
        }
    }

    private static func decode(_ data: Data) -> GameData? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(GameData.self, from: data)
    }
}
