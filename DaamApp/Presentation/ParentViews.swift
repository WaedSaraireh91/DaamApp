import SwiftUI

struct ParentHomeView: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            BrandHeader()
            DashboardHero(title: .parentGreeting, subtitle: .parentSubtitle, artwork: .learning)
            NavigationLink { TeacherSearchView() } label: { Label(app.text(.search), systemImage: "magnifyingglass") }
                .buttonStyle(DaamButtonStyle())
            NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
            HStack { Text(app.text(.nearbyTeachers)).font(.title3.bold()); Spacer(); NavigationLink(app.text(.seeAll)) { TeacherSearchView() }.font(.subheadline) }
            if app.nearbyTeachers.isEmpty { Text(app.text(.noAreaMatches)).foregroundStyle(DaamTheme.secondary) }
            ForEach(app.nearbyTeachers) { teacher in
                NavigationLink { TeacherDetailView(teacher: teacher) } label: { TeacherTile(teacher: teacher) }.buttonStyle(.plain)
            }
        }.navigationTitle(app.text(.home))
    }
}

struct TeacherSearchView: View {
    var favoritesOnly = false
    @State private var query = ""
    @State private var nearbyOnly = true
    @EnvironmentObject private var app: AppModel
    private var results: [Teacher] {
        app.teachers.filter { teacher in
            (!nearbyOnly || app.matchesArea(app.snapshot.parentRegistration?.area, teacherID: teacher.id)) &&
            (!favoritesOnly || app.snapshot.favoriteTeacherIDs.contains(teacher.id)) &&
            (query.isEmpty || app.teacherName(teacher).localizedCaseInsensitiveContains(query) || app.subject(teacher).localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .teaching, height: 140)
            Toggle(app.text(.nearbyOnly), isOn: $nearbyOnly)
            Text(L10n.teachersCount.format(app.language, results.count)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
            if results.isEmpty { EmptyState(title: favoritesOnly ? .emptyFavorites : .emptySearch, message: favoritesOnly ? .emptyFavoritesBody : .emptySearchBody, artwork: .learning) }
            ForEach(results) { teacher in
                NavigationLink { TeacherDetailView(teacher: teacher) } label: { TeacherTile(teacher: teacher) }.buttonStyle(.plain)
            }
        }.navigationTitle(app.text(favoritesOnly ? .favorites : .results))
            .searchable(text: $query, prompt: app.text(.searchHint))
    }
}

struct TeacherDetailView: View {
    let teacher: Teacher
    @EnvironmentObject private var app: AppModel
    @State private var showBooking = false
    var body: some View {
        Page {
            AnimatedArtwork(artwork: teacher.id == "sarah" ? .learning : .teaching, height: 230)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.teacherName(teacher)).font(.title2.bold())
                    Text(app.subject(teacher)).foregroundStyle(DaamTheme.secondary)
                }
                Spacer()
                Button { app.toggleFavorite(teacher.id) } label: {
                    Image(systemName: app.snapshot.favoriteTeacherIDs.contains(teacher.id) ? "heart.fill" : "heart").font(.title2)
                        .foregroundStyle(app.snapshot.favoriteTeacherIDs.contains(teacher.id) ? Color.red : DaamTheme.secondary)
                }.accessibilityLabel(app.text(app.snapshot.favoriteTeacherIDs.contains(teacher.id) ? .saved : .save))
            }
            Label(teacher.rating, systemImage: "star.fill").foregroundStyle(DaamTheme.gold)
            SummaryRow(title: .teacherLocation, value: app.teacherLocation(teacher))
            Text(app.text(.about)).font(.headline)
            Text(app.snapshot.teacherProfiles[teacher.id]?.bio ?? app.text(.teacherBio)).foregroundStyle(DaamTheme.secondary)
            NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
            Text(L10n.perHour.format(app.language, app.money(app.hourlyRate(teacher)))).font(.title2.bold()).foregroundStyle(DaamTheme.primary)
            Button(app.text(.bookLesson)) { showBooking = true }.buttonStyle(DaamButtonStyle())
        }.navigationTitle(app.text(.profile))
            .sheet(isPresented: $showBooking) {
                BookingFlow(teacher: teacher)
                    .environmentObject(app)
                    .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
                    .environment(\.locale, app.language.locale)
            }
    }
}

struct BookingsView: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .schedule, height: 150)
            if app.snapshot.lessons.isEmpty { EmptyState(title: .emptyBookings, message: .emptyBookingsBody) }
            ForEach(app.snapshot.lessons.sorted { $0.date < $1.date }) { lesson in
                NavigationLink { BookingDetailView(lessonID: lesson.id) } label: { LessonTile(lesson: lesson) }.buttonStyle(.plain)
            }
        }.navigationTitle(app.text(.bookings))
    }
}

struct BookingDetailView: View {
    let lessonID: UUID
    @EnvironmentObject private var app: AppModel
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .schedule, height: 160)
            if let lesson = app.lesson(lessonID) {
                LessonTile(lesson: lesson)
                VStack(spacing: 12) {
                    SummaryRow(title: .studentName, value: lesson.student)
                    SummaryRow(title: .studentLocation, value: lesson.address)
                    SummaryRow(title: .notes, value: lesson.notes)
                    SummaryRow(title: .bookingFee, value: app.money(0))
                    SummaryRow(title: .dueNow, value: app.money(0))
                    SummaryRow(title: .lessonPrice, value: app.money(lesson.price))
                }.padding(18).daamCard()
                NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
            }
        }.navigationTitle(app.text(.bookingDetails))
    }
}
