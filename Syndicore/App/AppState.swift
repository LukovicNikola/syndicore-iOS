import Foundation
import Observation

@Observable
final class AppState {
    // MARK: - API

    let api: APIClient
    let authManager: AuthManager

    // MARK: - Auth state

    var currentPlayer: Player?

    // MARK: - Navigation state

    enum Screen {
        case loading
        case login
        case worldList
        case onboarding
    }

    var activeScreen: Screen = .loading

    // MARK: - Init

    init(
        apiBaseURL: URL = URL(string: "http://localhost:3000")!,
        supabaseURL: URL = SupabaseConfig.url,
        supabaseKey: String = SupabaseConfig.anonKey
    ) {
        let auth = AuthManager(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        self.authManager = auth
        self.api = APIClient(baseURL: apiBaseURL, tokenProvider: auth)
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
            activeScreen = .worldList
        } catch let error as APIError {
            switch error {
            case .onboardingRequired:
                activeScreen = .onboarding
            case .unauthorized:
                activeScreen = .login
            default:
                activeScreen = .worldList
            }
        } catch {
            activeScreen = .worldList
        }
    }

    func signOut() async {
        await authManager.signOut()
        currentPlayer = nil
        activeScreen = .login
    }
}
