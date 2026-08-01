import SwiftUI

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.custom("AvenirNext-Medium", size: 12))
            .tracking(1.1)
            .foregroundStyle(Theme.mutedText)
    }
}

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: title)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(textContentType)
            .font(.custom("AvenirNext-Medium", size: 17))
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.deepTeal.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

struct ProfileBubble: View {
    let profile: Profile?
    var size: CGFloat = 36
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initials
                    }
                } else {
                    initials
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    private var initials: some View {
        ZStack {
            Theme.deepTeal
            Text(initialsText)
                .font(.custom("AvenirNext-DemiBold", size: size * 0.38))
                .foregroundStyle(Theme.foam)
        }
    }

    private var initialsText: String {
        let name = profile?.fullName ?? "?"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.number")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.lagoon)
                .symbolEffect(.pulse)
            Text(title)
                .font(.custom("AvenirNext-Bold", size: 22))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.custom("AvenirNext-Regular", size: 15))
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VoteBookmarkBar: View {
    let score: Int
    let userVote: Int
    let isBookmarked: Bool
    var onUp: () -> Void
    var onDown: () -> Void
    var onBookmark: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onUp) {
                Label("\(max(score, 0))", systemImage: userVote == 1 ? "arrow.up.circle.fill" : "arrow.up.circle")
            }
            .foregroundStyle(userVote == 1 ? Theme.lagoon : Theme.mutedText)

            Button(action: onDown) {
                Image(systemName: userVote == -1 ? "arrow.down.circle.fill" : "arrow.down.circle")
            }
            .foregroundStyle(userVote == -1 ? Theme.coral : Theme.mutedText)

            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
            .foregroundStyle(isBookmarked ? Theme.amber : Theme.mutedText)

            Spacer()
        }
        .font(.custom("AvenirNext-DemiBold", size: 16))
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.custom("AvenirNext-Medium", size: 14))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.coral.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
