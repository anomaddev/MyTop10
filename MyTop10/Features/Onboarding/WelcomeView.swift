import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()

            // Atmospheric map-like pattern
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    for i in 0..<8 {
                        let y = h * (0.15 + CGFloat(i) * 0.1)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addQuadCurve(
                            to: CGPoint(x: w, y: y + 20),
                            control: CGPoint(x: w * 0.5, y: y - 30)
                        )
                    }
                }
                .stroke(Theme.lagoon.opacity(0.25), lineWidth: 1.2)
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                BrandTitle(size: 56)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 18)

                Text("Rank what matters.\nShare it with your people.")
                    .font(.custom("AvenirNext-Regular", size: 20))
                    .foregroundStyle(Theme.foam.opacity(0.88))
                    .padding(.top, 18)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                Spacer()

                VStack(spacing: 12) {
                    Button("Get Started") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            session.advanceOnboarding(to: .phone)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Sign In") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            session.advanceOnboarding(to: .phone)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                }
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appear = true
            }
        }
    }
}
