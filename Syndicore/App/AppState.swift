import Foundation
import Observation

@Observable
final class AppState {
    // MARK: - API

    let api: APIClient
    let authManager: AuthManager
    let gameConstants: GameConstantsManager

    // MARK: - Auth state

    var currentPlayer: Player?

    // MARK: - Navigation state

    enum Screen {
        case loading
        case login
        case onboarding
        case main
    }

    var activeScreen: Screen = .loading

    // MARK: - Init

    init(
        apiBaseURL: URL = URL(string: "http://localhost:3000")!,
        supabaseURL: URL = SupabaseConfig.url,
        supabaseKey: String = SupabaseConfig.anonKey
    ) {
        let auth = AuthManager(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        let client = APIClient(baseURL: apiBaseURL, tokenProvider: auth)
        self.authManager = auth
        self.api = client
        self.gameConstants = GameConstantsManager(api: client)
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        await authManager.restoreSession()

        guard authManager.isAuthenticated else {
            activeScreen = .login
            return
        }

        do {
            let response = try await api.me()
            currentPlayer = response.player
            activeScreen = .main
        } catch let error as APIError {
            switch error {
            case .onboardingRequired:
                activeScreen = .onboarding
            case .unauthorized:
                activeScreen = .login
            default:
                activeScreen = .main
            }
        } catch {
            activeScreen = .main
        }
    }

    func signOut() async {
        await authManager.signOut()
        currentPlayer = nil
        activeScreen = .login
    }
}
