import Foundation

/// Učitava app secrets (Supabase + BE URL) iz Config.plist.
/// Struktura se pre-loaduje u SyndicoreApp i injektuje u APIClient / SupabaseManager.
/// Ako fajl fali ili je nevalidan, `AppConfigError` se propagira do UI sloja.
struct AppConfig: Sendable {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let apiBaseURL: URL

    static func load(bundle: Bundle = .main) throws -> AppConfig {
        guard let path = bundle.path(forResource: "Config", ofType: "plist") else {
            throw AppConfigError.fileMissing
        }
        guard let dict = NSDictionary(contentsOfFile: path) else {
            throw AppConfigError.fileUnreadable(path: path)
        }

        guard let supabaseURLString = dict["SUPABASE_URL"] as? String,
              let supabaseURL = URL(string: supabaseURLString) else {
            throw AppConfigError.missingKey("SUPABASE_URL")
        }
        guard let supabaseAnonKey = dict["SUPABASE_ANON_KEY"] as? String,
              !supabaseAnonKey.isEmpty else {
            throw AppConfigError.missingKey("SUPABASE_ANON_KEY")
        }
        guard let apiBaseURLString = dict["API_BASE_URL"] as? String,
              let apiBaseURL = URL(string: apiBaseURLString) else {
            throw AppConfigError.missingKey("API_BASE_URL")
        }

        return AppConfig(
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey,
            apiBaseURL: apiBaseURL
        )
    }
}

enum AppConfigError: LocalizedError {
    case fileMissing
    case fileUnreadable(path: String)
    case missingKey(String)

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Config.plist nije pronađen u app bundle-u. Kopiraj Config.example.plist u Config.plist i popuni vrednosti."
        case .fileUnreadable(let path):
            return "Config.plist nije moguće pročitati (\(path))."
        case .missingKey(let key):
            return "Config.plist nema validan ključ \"\(key)\". Vidi Config.example.plist za template."
        }
    }
}
