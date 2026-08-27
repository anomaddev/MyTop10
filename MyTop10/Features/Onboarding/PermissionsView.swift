import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var locationDone = false
    @State private var notificationsDone = false
    @State private var appear = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(alignment: .leading, spacing: 28) {
                BrandTitle(size: 32, light: false)

                Text("Stay in the loop")
                    .font(.custom("AvenirNext-Bold", size: 28))
                    .foregroundStyle(Theme.ink)

                Text("Enable location so you can pin restaurants and spots on your Top 10s. Notifications let us ask if you want to swing by when you’re nearby.")
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundStyle(Theme.mutedText)

                permissionRow(
                    icon: "location.fill",
                    title: "Location",
                    subtitle: "Pin Top 10 places on the map",
                    done: locationDone
                ) {
                    session.location.requestWhenInUse()
                    locationDone = true
                }

                permissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Nearby Top 10 spot prompts (coming soon)",
                    done: notificationsDone
                ) {
                    Task {
                        _ = await session.notifications.request()
                        notificationsDone = true
                    }
                }

                Spacer()

                Button("Enter MyTop10") {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        session.completeOnboarding()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Not now") {
                    session.completeOnboarding()
                }
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        subtitle: String,
        done: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.deepTeal)
                    .frame(width: 44, height: 44)
                    .background(Theme.lagoon.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("AvenirNext-DemiBold", size: 17))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(Theme.mutedText)
                }

                Spacer()

                Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(done ? Theme.lagoon : Theme.mutedText)
            }
            .padding(16)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
