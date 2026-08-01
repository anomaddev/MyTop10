import Foundation

enum AppConfig {
    private static let plist: [String: Any] = {
        let names = ["Config", "Config.example"]
        for name in names {
            if
                let url = Bundle.main.url(forResource: name, withExtension: "plist"),
                let data = try? Data(contentsOf: url),
                let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            {
                return dict
            }
        }
        return [:]
    }()

    static var supabaseURL: URL {
        URL(string: string("SUPABASE_URL") ?? "https://YOUR_PROJECT.supabase.co")!
    }

    static var supabaseAnonKey: String {
        string("SUPABASE_ANON_KEY") ?? ""
    }

    static var firebaseProjectID: String {
        string("FIREBASE_PROJECT_ID") ?? ""
    }

    static var admobBannerUnitID: String {
        string("ADMOB_BANNER_UNIT_ID") ?? "ca-app-pub-3940256099942544/2934735716"
    }

    static var admobInterstitialUnitID: String {
        string("ADMOB_INTERSTITIAL_UNIT_ID") ?? "ca-app-pub-3940256099942544/4411468910"
    }

    static var passwordEmailDomain: String {
        string("PASSWORD_EMAIL_DOMAIN") ?? "users.mytop10.app"
    }

    /// Synthetic email used to attach Email/Password to a phone-authenticated Firebase user.
    static func passwordEmail(forPhoneE164 phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        return "phone+\(digits)@\(passwordEmailDomain)"
    }

    private static func string(_ key: String) -> String? {
        guard let value = plist[key] as? String, !value.isEmpty, !value.contains("YOUR_") else {
            return nil
        }
        return value
    }

    static var isConfigured: Bool {
        string("SUPABASE_URL") != nil && string("SUPABASE_ANON_KEY") != nil
    }
}
