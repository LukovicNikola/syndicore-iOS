import Foundation
import Observation

@Observable
final class AppState {
    // MARK: - API

    let api: APIClient

    // MARK: - Auth state

    var currentPlayer: Player?
    var isAuthenticated = false

    // MARK: - Navigation state

    enum Screen {
        case loading
        case worldList
        case onboarding
    }

    var activeScreen: Screen = .loading

    // MARK: - Init

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.api = APIClient(baseURL: baseURL)
    }

    // MARK: - Bootstrap

    /// Called on app launch to determine initial screen.
    func bootstrap() async {
        do {
            let response = try await api.me()
            currentPlayer = response.player
            isAuthenticated = true
            activeScreen = .worldList
        } catch let error as APIError {
            switch error {
            case .onboardingRequired:
                isAuthenticated = true
                activeScreen = .onboarding
            case .unauthorized:
                isAuthenticated = false
                activeScreen = .worldList
            default:
                activeScreen = .worldList
            }
        } catch {
            activeScreen = .worldList
        }
    }
}
