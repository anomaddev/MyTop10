import Foundation
import FirebaseAuth
import FirebaseCore

enum AuthError: LocalizedError {
    case notConfigured
    case invalidPhone
    case missingVerification
    case usernameTaken
    case profileIncomplete
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Firebase is not configured. Add GoogleService-Info.plist."
        case .invalidPhone: return "Enter a valid phone number with country code."
        case .missingVerification: return "Start phone verification again."
        case .usernameTaken: return "That username is already taken."
        case .profileIncomplete: return "Finish setting up your profile."
        case .unknown(let message): return message
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private(set) var verificationID: String?
    private(set) var pendingPhoneE164: String?
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        if FirebaseApp.app() != nil {
            user = Auth.auth().currentUser
            handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in
                    self?.user = user
                }
            }
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var isSignedIn: Bool { user != nil }
    var uid: String? { user?.uid }

    func normalizedPhone(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return nil }
        if trimmed.hasPrefix("+") {
            let digits = trimmed.dropFirst().filter(\.isNumber)
            return digits.count >= 8 ? "+\(digits)" : nil
        }
        let digits = trimmed.filter(\.isNumber)
        return digits.count >= 8 ? "+\(digits)" : nil
    }

    func sendOTP(to rawPhone: String) async throws {
        guard FirebaseApp.app() != nil else { throw AuthError.notConfigured }
        guard let phone = normalizedPhone(rawPhone) else { throw AuthError.invalidPhone }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil)
            verificationID = id
            pendingPhoneE164 = phone
        } catch {
            errorMessage = error.localizedDescription
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func verifyOTP(_ code: String) async throws {
        guard let verificationID else { throw AuthError.missingVerification }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let result = try await Auth.auth().signIn(with: credential)
            user = result.user
            // Force-refresh so Cloud Function / blocking function role claim is present.
            _ = try await result.user.getIDTokenResult(forcingRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
        verificationID = nil
        pendingPhoneE164 = nil
    }

    func idToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.unknown("Not signed in")
        }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }
}
