import SwiftUI

struct SplashView: View {
    let complete: () -> Void
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 58

    var body: some View {
        ZStack {
            Color("Canvas").ignoresSafeArea()
            GeometryReader { proxy in
                Circle().fill(Color("Mint")).frame(width: 340, height: 340)
                    .position(x: proxy.size.width * 0.94, y: proxy.size.height * 0.05)
                Circle().stroke(DaamTheme.gold.opacity(0.22), lineWidth: 1.5)
                    .frame(width: 300, height: 300)
                    .position(x: proxy.size.width * 0.05, y: proxy.size.height * 0.95)
            }.ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(.white).frame(width: 220, height: 220)
                        .shadow(color: DaamTheme.primary.opacity(0.08), radius: 24, y: 10)
                    Circle().stroke(DaamTheme.primary.opacity(0.12), lineWidth: 1).frame(width: 250, height: 250)
                    Image(Artwork.logo.rawValue).resizable().scaledToFit().frame(width: 180, height: 180)
                }
                .scaleEffect(appeared || reduceMotion ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)
                Text(app.text(.brand)).font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(DaamTheme.primary)
                Text(app.text(.tagline)).font(.title3.weight(.medium))
                    .foregroundStyle(DaamTheme.text).multilineTextAlignment(.center)
                Text(app.text(.splashMessage)).font(.subheadline)
                    .foregroundStyle(DaamTheme.secondary).multilineTextAlignment(.center)
                Spacer()
                Button(app.text(.start), action: complete).buttonStyle(DaamButtonStyle()).padding(.bottom, 28)
            }.padding(.horizontal, 30)
        }
        .modifier(DaamPageSurface())
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.75)) { appeared = true }
        }
    }
}
