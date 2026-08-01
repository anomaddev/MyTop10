import Foundation

enum PasswordValidator {
    static func requirements(password: String, username: String, phone: String) -> [PasswordRequirement] {
        let digits = phone.filter(\.isNumber)
        let lower = password.lowercased()
        return [
            .init(label: "At least 12 characters", isMet: password.count >= 12),
            .init(label: "One uppercase letter", isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil),
            .init(label: "One lowercase letter", isMet: password.rangeOfCharacter(from: .lowercaseLetters) != nil),
            .init(label: "One number", isMet: password.rangeOfCharacter(from: .decimalDigits) != nil),
            .init(label: "One symbol (!@#$%…)", isMet: password.rangeOfCharacter(from: .symbols.union(.punctuationCharacters)) != nil),
            .init(
                label: "Does not contain your username",
                isMet: username.isEmpty || !lower.contains(username.lowercased())
            ),
            .init(
                label: "Does not contain your phone number",
                isMet: digits.isEmpty || !password.contains(digits)
            )
        ]
    }

    static func isStrong(_ password: String, username: String, phone: String) -> Bool {
        requirements(password: password, username: username, phone: phone).allSatisfy(\.isMet)
    }
}
