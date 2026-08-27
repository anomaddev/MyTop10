import Foundation
import Supabase
import FirebaseAuth

struct MissingFirebaseTokenError: Error {}

enum SupabaseManager {
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    accessToken: {
                        guard let token = try? await Auth.auth().currentUser?.getIDToken() else {
                            throw MissingFirebaseTokenError()
                        }
                        return token
                    }
                )
            )
        )
    }()
}
