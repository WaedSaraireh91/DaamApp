import SwiftUI

struct SplashView: View {
  let complete: () -> Void

  @EnvironmentObject private var app: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var logoVisible = false
  @State private var titleVisible = false
  @State private var ringProgress: CGFloat = 0
  @State private var orbitRotation = 0.0
  @State private var didFinish = false

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.015, green: 0.20, blue: 0.17),
          Color(red: 0.00, green: 0.34, blue: 0.29),
          Color(red: 0.015, green: 0.24, blue: 0.21)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      GeometryReader { proxy in
        Circle()
          .fill(Color(red: 0.13, green: 0.62, blue: 0.52).opacity(0.24))
          .frame(width: proxy.size.width * 0.92)
          .blur(radius: 55)
          .offset(x: proxy.size.width * 0.43, y: -proxy.size.height * 0.27)
        Circle()
          .fill(DaamTheme.gold.opacity(0.13))
          .frame(width: proxy.size.width * 0.72)
          .blur(radius: 60)
          .offset(x: -proxy.size.width * 0.42, y: proxy.size.height * 0.40)
      }
      .ignoresSafeArea()
      .accessibilityHidden(true)

      VStack(spacing: 0) {
        Spacer(minLength: 30)

        ZStack {
          Circle()
            .stroke(.white.opacity(0.12), lineWidth: 1)
            .frame(width: 276, height: 276)
            .scaleEffect(logoVisible ? 1 : 0.76)

          Circle()
            .trim(from: 0, to: ringProgress)
            .stroke(
              AngularGradient(
                colors: [DaamTheme.gold, .white.opacity(0.86), DaamTheme.gold],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
              ),
              style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 244, height: 244)
            .rotationEffect(.degrees(-90))

          Circle()
            .fill(.white.opacity(0.08))
            .frame(width: 208, height: 208)
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))

          Image(Artwork.logo.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
            .scaleEffect(logoVisible ? 1 : 0.72)
            .rotationEffect(.degrees(logoVisible ? 0 : -9))
            .opacity(logoVisible ? 1 : 0)

          Circle()
            .fill(DaamTheme.gold)
            .frame(width: 9, height: 9)
            .shadow(color: DaamTheme.gold.opacity(0.9), radius: 10)
            .offset(y: -136)
            .rotationEffect(.degrees(orbitRotation))
            .opacity(logoVisible ? 1 : 0)
        }
        .frame(height: 290)
        .accessibilityHidden(true)

        VStack(spacing: 10) {
          Text(app.text(.brand))
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(.white)

          Text(app.text(.tagline))
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)

          Text(app.text(.splashMessage))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.68))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: 310)
            .padding(.top, 2)
        }
        .opacity(titleVisible ? 1 : 0)
        .offset(y: titleVisible ? 0 : 14)
        .padding(.top, 30)

        Spacer()

        Button(action: finish) {
          HStack(spacing: 9) {
            Text(app.text(.skipIntro))
            Image(systemName: app.language == .arabic ? "arrow.left" : "arrow.right")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.8))
          .padding(.vertical, 14)
          .padding(.horizontal, 20)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 18)
      }
      .padding(.horizontal, 28)
    }
    .ignoresSafeArea()
    .statusBarHidden(true)
    .task {
      reveal()
      try? await Task.sleep(for: .seconds(3.1))
      guard !Task.isCancelled else { return }
      finish()
    }
  }

  private func reveal() {
    guard !reduceMotion else {
      logoVisible = true
      titleVisible = true
      ringProgress = 1
      return
    }
    withAnimation(.spring(response: 0.82, dampingFraction: 0.72)) {
      logoVisible = true
    }
    withAnimation(.easeInOut(duration: 1.25).delay(0.18)) {
      ringProgress = 1
    }
    withAnimation(.easeOut(duration: 0.7).delay(0.62)) {
      titleVisible = true
    }
    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
      orbitRotation = 360
    }
  }

  private func finish() {
    guard !didFinish else { return }
    didFinish = true
    complete()
  }
}

struct ForceUpdateView: View {
  let policy: AppUpdatePolicy
  let checking: Bool
  let checkAgain: () -> Void
  @EnvironmentObject private var app: AppModel
  @Environment(\.openURL) private var openURL

  private var storeURL: URL? {
    guard let raw = policy.storeUrl, let url = URL(string: raw),
      url.scheme == "https", url.host != nil
    else { return nil }
    return url
  }

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      Image(Artwork.logo.rawValue)
        .resizable().scaledToFit().frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: DaamTheme.primary.opacity(0.18), radius: 24, y: 10)
      Image(systemName: "arrow.down.app.fill")
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(DaamTheme.primary)
        .padding(.top, 4)
      Text(app.text(.forceUpdateTitle))
        .font(.system(.largeTitle, design: .rounded, weight: .bold))
        .multilineTextAlignment(.center)
      Text(app.text(.forceUpdateBody))
        .font(.body)
        .foregroundStyle(DaamTheme.secondary)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .frame(maxWidth: 340)
      Spacer()
      if let storeURL {
        Button(app.text(.updateNow)) { openURL(storeURL) }
          .buttonStyle(DaamButtonStyle())
      }
      Button(action: checkAgain) {
        HStack(spacing: 9) {
          if checking { ProgressView().tint(DaamTheme.primary) }
          Text(app.text(.checkAgain))
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
      }
      .disabled(checking)
      .padding(.bottom, 16)
    }
    .padding(.horizontal, 28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("Canvas").ignoresSafeArea())
  }
}
