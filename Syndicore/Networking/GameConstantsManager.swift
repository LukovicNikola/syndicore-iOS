import Foundation
import Observation

@Observable
final class GameConstantsManager {
    private let api: APIClient

    private(set) var isLoaded = false
    private(set) var rawJSON: Data?
    private var etag: String?

    private let etagKey = "gameConstants.etag"
    private let dataKey = "gameConstants.data"

    init(api: APIClient) {
        self.api = api
        self.etag = UserDefaults.standard.string(forKey: etagKey)
        self.rawJSON = UserDefaults.standard.data(forKey: dataKey)
        self.isLoaded = rawJSON != nil
    }

    func refresh() async {
        do {
            let result = try await api.gameConstants(etag: etag)
            switch result {
            case .notModified:
                isLoaded = true
            case .updated(let data, let newEtag):
                rawJSON = data
                etag = newEtag
                UserDefaults.standard.set(newEtag, forKey: etagKey)
                UserDefaults.standard.set(data, forKey: dataKey)
                isLoaded = true
            }
        } catch {
            // Cached data still valid if available
        }
    }
}
