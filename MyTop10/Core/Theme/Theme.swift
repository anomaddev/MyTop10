import SwiftUI

enum Theme {
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.14)
    static let deepTeal = Color(red: 0.05, green: 0.28, blue: 0.30)
    static let lagoon = Color(red: 0.10, green: 0.55, blue: 0.52)
    static let foam = Color(red: 0.93, green: 0.97, blue: 0.96)
    static let amber = Color(red: 0.93, green: 0.62, blue: 0.18)
    static let coral = Color(red: 0.90, green: 0.35, blue: 0.28)
    static let mist = Color(red: 0.78, green: 0.86, blue: 0.85)
    static let mutedText = Color(red: 0.35, green: 0.45, blue: 0.46)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [deepTeal, ink, Color(red: 0.12, green: 0.22, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var softGradient: LinearGradient {
        LinearGradient(
            colors: [foam, mist.opacity(0.55), foam],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct BrandTitle: View {
    var size: CGFloat = 48
    var light: Bool = true

    var body: some View {
        Text("MyTop10")
            .font(.custom("AvenirNext-Heavy", size: size))
            .foregroundStyle(light ? Theme.foam : Theme.ink)
            .tracking(-1.2)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: 17))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if filled {
                        Theme.amber.opacity(configuration.isPressed ? 0.85 : 1)
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundStyle(filled ? Theme.ink : Theme.foam)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(filled ? Color.clear : Theme.foam.opacity(0.55), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct AtmosphereBackground: View {
    var body: some View {
        ZStack {
            Theme.softGradient
            Circle()
                .fill(Theme.lagoon.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 40)
                .offset(x: -120, y: -220)
            Circle()
                .fill(Theme.amber.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 140, y: 260)
        }
        .ignoresSafeArea()
    }
}
