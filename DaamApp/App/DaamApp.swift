import SwiftUI

@main
struct DaamApp: App {
    @StateObject private var app = AppModel(repository: LocalLessonRepository(), paymentConfiguration: PaymentConfiguration(recipientName: "TestAccount", cliqAlias: "TestAccount"))
    var body: some Scene {
        WindowGroup {
            AppRoot().environmentObject(app)
                .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
                .environment(\.locale, app.language.locale)
                .preferredColorScheme(.light)
                .tint(DaamTheme.primary)
        }
    }
}

struct AppRoot: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingLink: URL?
    @State private var showAuthentication = false
    @State private var service: AuthenticationService?
    @State private var profile: AccountProfile?
    @State private var sessionReady = false
    @State private var splashFinished = false
    @State private var sessionExpiresAt: Date?
    @State private var updatePolicy: AppUpdatePolicy?
    @State private var updateCheckReady = false
    @State private var updateChecking = false
    private var mustUpdate: Bool { updateCheckReady && updatePolicy?.forceUpdate == true }
    var body: some View {
        ZStack {
            if mustUpdate, let policy = updatePolicy {
                ForceUpdateView(policy: policy, checking: updateChecking) {
                    Task { await refreshUpdatePolicy() }
                }
            } else {
                PublicTeacherDashboard(isAuthenticated: profile != nil, sessionReady: sessionReady) {
                    showAuthentication = true
                }
                .fullScreenCover(
                    isPresented: Binding(
                        get: { showAuthentication && splashFinished && updateCheckReady },
                        set: { showAuthentication = $0 }
                    )
                ) {
                    Group {
                        if let configuration = BackendConfiguration.configured {
                            AuthenticationGateway(
                                configuration: configuration,
                                pendingLink: $pendingLink,
                                service: $service,
                                profile: $profile,
                                closeAuthentication: { showAuthentication = false },
                                onSignOut: { showAuthentication = false }
                            )
                        } else {
                            Page { BrandHeader(); Text(app.text(.backendConfigurationRequired)) }
                        }
                    }
                    .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
                }
                .opacity(splashFinished && updateCheckReady ? 1 : 0)
                .allowsHitTesting(splashFinished && updateCheckReady)
            }

            if !splashFinished || !updateCheckReady {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        splashFinished = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            await bootstrap()
        }
        .onOpenURL { pendingLink = $0; showAuthentication = true }
        .onChange(of: profile?.id) { _, userID in
            guard userID != nil, let service else {
                sessionExpiresAt = nil
                return
            }
            Task { sessionExpiresAt = await service.sessionExpiration() }
        }
        .task(id: sessionExpiresAt) {
            guard let expiry = sessionExpiresAt, profile != nil else { return }
            let remaining = expiry.timeIntervalSinceNow
            if remaining > 0 {
                do { try await Task.sleep(for: .seconds(remaining)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            await service?.expireSession()
            profile = nil
            sessionExpiresAt = nil
            showAuthentication = false
            withAnimation(.easeInOut(duration: 0.35)) {
                splashFinished = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, updateCheckReady else { return }
            Task { await refreshUpdatePolicy() }
        }
        .alert(
            app.text(.errorTitle),
            isPresented: Binding(
                get: { splashFinished && updateCheckReady && !mustUpdate && app.error != nil },
                set: { if !$0 { app.error = nil } }
            )
        ) {
            Button(app.text(.done), role: .cancel) { app.error = nil }
        } message: { Text(app.error.map { app.text($0) } ?? "") }
    }

    private func bootstrap() async {
        guard !updateCheckReady else { return }
        guard let configuration = BackendConfiguration.configured else {
            sessionReady = true
            updateCheckReady = true
            return
        }
        let value = AuthenticationService(configuration: configuration)
        service = value
        async let updateRequest = value.checkUpdatePolicy()
        async let restoredProfile = value.restore()
        updatePolicy = await updateRequest
        do {
            profile = try await restoredProfile
            sessionExpiresAt = await value.sessionExpiration()
            if profile != nil { showAuthentication = true }
        } catch {
            app.error = .authTryAgain
        }
        sessionReady = true
        updateCheckReady = true
    }

    private func refreshUpdatePolicy() async {
        guard let service else { return }
        updateChecking = true
        defer { updateChecking = false }
        if let refreshed = await service.checkUpdatePolicy() {
            updatePolicy = refreshed
        }
    }
}

struct RoleSelectionView: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            BrandHeader()
            Text(app.text(.chooseRole)).font(.largeTitle.bold())
            roleCard(.parent, .parent, .parentRole, .learning)
            roleCard(.teacher, .teacher, .teacherRole, .teaching)
            Text(app.text(.demoNotice)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }
    }
    private func roleCard(_ role: AccountRole, _ title: L10n, _ subtitle: L10n, _ art: Artwork) -> some View {
        Button { app.role = role } label: {
            VStack(alignment: .leading, spacing: 12) {
                AnimatedArtwork(artwork: art, height: 160)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.text(title)).font(.title3.bold())
                        Text(app.text(subtitle)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.forward.circle.fill").font(.title).foregroundStyle(DaamTheme.primary)
                }.padding([.horizontal, .bottom], 18)
            }.daamCard(radius: 24)
        }.buttonStyle(.plain)
    }
}

struct ParentTabs: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        TabView(selection: $app.parentTab) {
            NavigationStack { ParentHomeView() }.tag(AppTab.home).tabItem { Label(app.text(.home), systemImage: "house.fill") }
            NavigationStack { BookingsView() }.tag(AppTab.bookings).tabItem { Label(app.text(.bookings), systemImage: "calendar") }
            NavigationStack { TeacherSearchView(favoritesOnly: true) }.tag(AppTab.favorites).tabItem { Label(app.text(.favorites), systemImage: "heart.fill") }
            NavigationStack { AccountView() }.tag(AppTab.account).tabItem { Label(app.text(.account), systemImage: "person.crop.circle") }
        }
    }
}

struct TeacherTabs: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        TabView(selection: $app.teacherTab) {
            NavigationStack { TeacherDashboardView() }.tag(AppTab.home).tabItem { Label(app.text(.home), systemImage: "house.fill") }
            NavigationStack { RequestsView() }.tag(AppTab.requests).tabItem { Label(app.text(.requests), systemImage: "tray.full.fill") }
            NavigationStack { ScheduleView() }.tag(AppTab.schedule).tabItem { Label(app.text(.schedule), systemImage: "calendar") }
            NavigationStack { AccountView() }.tag(AppTab.account).tabItem { Label(app.text(.account), systemImage: "person.crop.circle") }
        }
    }
}

struct AccountView: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        List {
            Section { BrandHeader(); AnimatedArtwork(artwork: app.role == .teacher ? .teaching : .learning, height: 160) }
            Section(app.text(.language)) {
                Picker(app.text(.language), selection: $app.language) {
                    Text(app.text(.arabic)).tag(AppLanguage.arabic)
                    Text(app.text(.englishLanguage)).tag(AppLanguage.english)
                }.pickerStyle(.segmented)
            }
            if app.role == .teacher {
                Section(app.text(.teacher)) {
                    NavigationLink(app.text(.hourlyRate)) { TeacherRateView() }
                    Picker(app.text(.teacher), selection: $app.selectedTeacherID) {
                        ForEach(app.teachers) { teacher in
                            Text(app.teacherName(teacher)).tag(teacher.id)
                        }
                    }
                }
            }
            Section { NavigationLink(app.text(.registrationTitle)) { RegistrationView(isTeacher: app.role == .teacher) } }
            Section {
                Button(app.text(.switchRole)) { app.role = nil }
            } footer: { Text(app.text(.localData)) }
            Section { NavigationLink(app.text(.ownerReview)) { OwnerPaymentsView() } } footer: { Text(app.text(.ownerDemo)) }
            Section { Text(app.text(.demoNotice)).font(.footnote).foregroundStyle(DaamTheme.secondary) }
        }.scrollContentBackground(.hidden).daamScreen().navigationTitle(app.text(.account))
    }
}
