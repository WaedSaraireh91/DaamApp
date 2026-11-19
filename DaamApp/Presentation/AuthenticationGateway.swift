import SwiftUI

struct AuthenticationGateway: View {
  let configuration: BackendConfiguration
  @Binding var pendingLink: URL?
  @EnvironmentObject private var app: AppModel
  @Binding var service: AuthenticationService?
  @Binding var profile: AccountProfile?
  let closeAuthentication: () -> Void
  let onSignOut: () -> Void
  @State private var signup = false
  @State private var phoneMode = false
  @State private var recovery = false
  @State private var verifying = false
  @State private var resetToken: String?
  @State private var busy = false
  @State private var email = ""
  @State private var phone = ""
  @State private var password = ""
  @State private var confirmation = ""
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var code = ""
  @State private var challenge: AuthenticationService.PhoneChallenge?
  @State private var resendAt = Date.distantPast
  @State private var failure: L10n?
  @State private var notice: L10n?
  private var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
  var body: some View {
    Group {
      if let profile, let service {
        if profile.role == "ADMIN" {
          LiveOwnerView(service: service) {
            perform {
              try await $0.logout()
              self.profile = nil
              onSignOut()
            }
          }
        } else {
          LiveTutoringView(account: profile, service: service) {
            perform {
              try await $0.logout()
              self.profile = nil
              onSignOut()
            }
          }
        }
      } else {
        form
      }
    }
    .disabled(busy)
    .task { handleLink() }
    .onChange(of: service != nil) { _, _ in handleLink() }
    .onChange(of: pendingLink) { _, _ in handleLink() }
  }
  private var form: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 0) {
          Image("DaamMark").resizable().scaledToFit().frame(width: 68, height: 68).clipShape(
            RoundedRectangle(cornerRadius: 20))
          Spacer()
          if !signup && !verifying && !recovery && resetToken == nil {
            Button(action: closeAuthentication) {
              Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DaamTheme.secondary)
                .frame(width: 42, height: 42)
                .background(.white, in: Circle())
                .overlay(Circle().stroke(DaamTheme.primary.opacity(0.15), lineWidth: 1))
            }
            .accessibilityLabel(app.text(.dismissAction))
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: 10) {
          Text(
            app.text(
              resetToken != nil
                ? .resetPasswordTitle
                : recovery
                  ? .forgotPasswordTitle
                  : verifying ? .verifyEmail : signup ? .createAccount : .welcomeBack)
          ).font(.largeTitle.bold())
          Text(app.text(.authNewSubtitle)).font(.subheadline).foregroundStyle(.secondary)
            .lineSpacing(4)
        }
        VStack(alignment: .leading, spacing: 20) {
          if verifying {
            Label(
              app.text(.verificationInstructions), systemImage: "envelope.badge.shield.half.filled")
            Text(cleanEmail).font(.subheadline).textSelection(.enabled)
            Button(app.text(.resendCode)) {
              perform {
                try await $0.resend(email: cleanEmail)
                notice = .authEmailResent
              }
            }
          } else {
            if resetToken == nil && !recovery {
              HStack(spacing: 5) {
                methodButton(.email, selected: !phoneMode) { phoneMode = false }
                methodButton(.phoneNumber, selected: phoneMode) { phoneMode = true }
              }
              .padding(5)
              .background(DaamTheme.background, in: RoundedRectangle(cornerRadius: 16))
              .onChange(of: phoneMode) { _, _ in
                challenge = nil
                failure = nil
                notice = nil
                code = ""
              }
            }
            if signup {
              Field(
                title: app.text(.firstName), placeholder: app.text(.firstName), text: $firstName)
              Field(title: app.text(.lastName), placeholder: app.text(.lastName), text: $lastName)
            }
            if phoneMode && resetToken == nil && !recovery {
              phoneFields
            } else {
              if resetToken == nil {
                Field(
                  title: app.text(.email), placeholder: app.text(.emailHint), text: $email,
                  keyboard: .emailAddress)
              }
              if !recovery {
                Field(
                  title: app.text(.password), placeholder: app.text(.passwordHint), text: $password,
                  secure: true)
              }
              if signup || resetToken != nil {
                Field(
                  title: app.text(.confirmPassword), placeholder: app.text(.confirmPassword),
                  text: $confirmation, secure: true)
                Text(app.text(.passwordRule)).font(.caption).foregroundStyle(.secondary)
              }
            }
            if let failure {
              Label(app.text(failure), systemImage: "exclamationmark.circle").font(.footnote)
                .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            if let notice {
              Text(app.text(notice)).font(.footnote).foregroundStyle(DaamTheme.primary)
            }
            Button(action: submit) {
              HStack {
                Text(app.text(submitTitle))
                Spacer()
                if busy { ProgressView().tint(.white) } else { Image(systemName: "arrow.forward") }
              }
            }.buttonStyle(DaamButtonStyle())
            if !signup && !phoneMode && resetToken == nil && !recovery {
              Button(app.text(.forgotPasswordTitle)) {
                recovery = true
                failure = nil
              }
              .font(.subheadline).frame(maxWidth: .infinity)
            }
          }
        }.padding(22).daamCard(radius: 26)
        Button(
          app.text(
            signup || verifying || recovery || resetToken != nil ? .backToLogin : .createAccount)
        ) {
          if verifying || recovery || resetToken != nil {
            signup = false
            verifying = false
            recovery = false
            resetToken = nil
          } else {
            signup.toggle()
          }
          password = ""
          confirmation = ""
          challenge = nil
          code = ""
          failure = nil
          notice = nil
        }.font(.subheadline.bold()).frame(maxWidth: .infinity)
        Label(app.text(.noBookingFee), systemImage: "checkmark.shield").font(.caption)
          .foregroundStyle(.secondary).frame(maxWidth: .infinity)
      }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
    }.background(Color("Canvas").ignoresSafeArea())
  }
  @ViewBuilder private var phoneFields: some View {
    NoticeCard(title: .localPhoneTitle, bodyKey: .localPhoneBody, symbol: "testtube.2")
    if let challenge {
      Text(phone).font(.headline).environment(\.layoutDirection, .leftToRight)
      Text(app.text(.localCodeLabel) + " " + challenge.localTestCode).font(
        .headline.monospacedDigit()
      ).textSelection(.enabled)
      Field(
        title: app.text(.phoneVerificationCode), placeholder: "000000", text: $code, keyboard: .numberPad
      )
      Text(app.text(.codeExpiry)).font(.caption).foregroundStyle(.secondary)
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Button(app.text(.resendPhoneCode)) {
          perform {
            self.challenge = try await $0.sendPhoneCode(phone, signup: signup)
            resendAt = Date().addingTimeInterval(60)
            code = ""
          }
        }
        .disabled(context.date < resendAt)
      }
      Button(app.text(.changePhone)) {
        self.challenge = nil
        code = ""
      }
    } else {
      Field(
        title: app.text(.phoneNumber), placeholder: "+962 7X XXX XXXX", text: $phone,
        keyboard: .phonePad)
    }
  }
  private var submitTitle: L10n {
    if resetToken != nil { return .resetPasswordTitle }
    if recovery { return .sendResetLink }
    if phoneMode { return challenge == nil ? .sendPhoneCode : .verifyAndContinue }
    return signup ? .createAccount : .login
  }
  private func methodButton(_ title: L10n, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(app.text(title))
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .foregroundStyle(selected ? .white : DaamTheme.secondary)
        .background(selected ? DaamTheme.primary : .clear, in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func submit() {
    if signup
      && (firstName.trimmingCharacters(in: .whitespaces).isEmpty
        || lastName.trimmingCharacters(in: .whitespaces).isEmpty)
    {
      failure = .authNameRequired
      return
    }
    if phoneMode && !recovery && resetToken == nil {
      guard !phone.isEmpty else {
        failure = .invalidPhone
        return
      }
      code = code.trimmingCharacters(in: .whitespacesAndNewlines).map { character in
        character.wholeNumberValue.map(String.init) ?? String(character)
      }.joined()
      if challenge != nil && (code.count != 6 || !code.allSatisfy({ $0.isASCII && $0.isNumber })) {
        failure = .invalidPhoneCode
        return
      }
      perform { service in
        if let challenge {
          profile = try await service.verifyPhone(
            challenge.challengeId, code: code, firstName: signup ? firstName : nil,
            lastName: signup ? lastName : nil)
          self.challenge = nil
          code = ""
        } else {
          challenge = try await service.sendPhoneCode(phone, signup: signup)
          resendAt = Date().addingTimeInterval(60)
        }
      }
      return
    }
    if resetToken == nil && (!cleanEmail.contains("@") || !cleanEmail.contains(".")) {
      failure = .authEmailRequired
      return
    }
    if !recovery
      && (password.isEmpty || ((signup || resetToken != nil) && !Self.validPassword(password)))
    {
      failure = .authPasswordRequired
      return
    }
    if (signup || resetToken != nil) && password != confirmation {
      failure = .authPasswordMismatch
      return
    }
    perform { service in
      if let resetToken {
        try await service.resetPassword(token: resetToken, password: password)
        self.resetToken = nil
        notice = .passwordResetDone
      } else if recovery {
        try await service.forgotPassword(email: cleanEmail)
        notice = .resetEmailSent
      } else if signup {
        try await service.signup(
          email: cleanEmail, password: password, firstName: firstName, lastName: lastName)
        verifying = true
      } else {
        profile = try await service.login(email: cleanEmail, password: password)
      }
      password = ""
      confirmation = ""
    }
  }
  static func validPassword(_ value: String) -> Bool {
    value.utf16.count >= 6 && value.utf8.count <= 72
      && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  private func handleLink() {
    guard service != nil, !busy, let url = pendingLink, let link = AuthenticationLink(url: url)
    else { return }
    pendingLink = nil
    signup = false
    recovery = false
    verifying = false
    phoneMode = false
    switch link.action {
    case .reset:
      profile = nil
      resetToken = link.token
    case .verify:
      perform {
        try await $0.verify(token: link.token)
        notice = .emailVerifiedDone
      }
    }
  }
  private func perform(_ action: @escaping @MainActor (AuthenticationService) async throws -> Void)
  {
    guard !busy, let service else { return }
    busy = true
    failure = nil
    notice = nil
    Task { @MainActor in
      defer { busy = false }
      do { try await action(service) } catch AuthenticationError.server(let code) {
        failure = TutoringViewModel.message(code)
      } catch AuthenticationError.throttled { failure = .authThrottled } catch {
        failure = .authTryAgain
      }
    }
  }
}
