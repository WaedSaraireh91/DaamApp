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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var hasEntered = false
    @State private var hasShownSplash = false
    var body: some View {
        Group {
            if !hasShownSplash { SplashView { hasShownSplash = true } }
            else if !hasSeenOnboarding { OnboardingFlow { hasSeenOnboarding = true } }
            else if !hasEntered { LoginView { hasEntered = true } }
            else if let role = app.role {
                if role == .parent {
                    if app.snapshot.parentRegistration == nil { RegistrationView(isTeacher: false) }
                    else { ParentTabs().id(app.language) }
                }
                else if app.snapshot.teacherProfiles[app.selectedTeacherID] == nil { RegistrationView(isTeacher: true) }
                else if app.snapshot.hourlyRates[app.selectedTeacherID] == nil { TeacherRateView() }
                else { TeacherTabs().id(app.language) }
            } else { RoleSelectionView() }
        }
        .alert(app.text(.errorTitle), isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })) {
            Button(app.text(.done), role: .cancel) { app.error = nil }
        } message: { Text(app.error.map { app.text($0) } ?? "") }
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
