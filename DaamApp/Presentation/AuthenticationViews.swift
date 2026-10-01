import SwiftUI

struct OnboardingFlow: View {
    let complete: () -> Void
    @State private var step = 0
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            BrandHeader()
            AnimatedArtwork(artwork: step == 0 ? .learning : .schedule, height: 320)
            Text(app.text(step == 0 ? .onboardTitle1 : .onboardTitle2)).font(.largeTitle.bold())
            Text(app.text(step == 0 ? .onboardBody1 : .onboardBody2)).font(.body).foregroundStyle(DaamTheme.secondary)
            HStack(spacing: 8) {
                ForEach(0..<2) { index in Capsule().fill(index == step ? DaamTheme.primary : DaamTheme.border).frame(width: index == step ? 28 : 8, height: 8) }
            }.accessibilityHidden(true)
            Button(app.text(step == 0 ? .next : .start)) { if step == 0 { step = 1 } else { complete() } }
                .buttonStyle(DaamButtonStyle())
        }
    }
}

struct LoginView: View {
    let continueAction: () -> Void
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            BrandHeader()
            AnimatedArtwork(artwork: .learning, height: 230)
            Text(app.text(.welcome)).font(.largeTitle.bold())
            VStack(spacing: 20) {
                Field(title: app.text(.email), placeholder: app.text(.emailHint), text: $email)
                Field(title: app.text(.password), placeholder: app.text(.passwordHint), text: $password, secure: true)
            }
            Button(app.text(.login), action: continueAction).buttonStyle(DaamButtonStyle())
                .disabled(!CredentialsValidator.isValid(email: email, password: password))
            Button(app.text(.demoEntry), action: continueAction).buttonStyle(DaamButtonStyle(outlined: true))
            Text(app.text(.demoNotice)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }
    }
}
