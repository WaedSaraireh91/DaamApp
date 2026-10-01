import SwiftUI

struct TeacherDashboardView: View {
    @EnvironmentObject private var app: AppModel
    private var accepted: [Lesson] { app.teacherLessons.filter { $0.status == .accepted } }
    var body: some View {
        Page {
            BrandHeader()
            DashboardHero(title: .teacherGreeting, subtitle: .teacherSubtitle, artwork: .teaching)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric(.newRequests, "\(app.teacherLessons.filter { $0.status == .pending }.count)")
                metric(.confirmedLessons, "\(accepted.count)")
                metric(.students, "\(Set(accepted.map(\.student)).count)")
                metric(.feeTotal, app.money(accepted.compactMap(\.acceptanceFee).reduce(0, +)))
            }
            NoticeCard(title: .firstFreeTitle, bodyKey: .firstFreeBody, symbol: "gift.fill")
            Text(app.text(.quickActions)).font(.title3.bold())
            VStack(spacing: 12) {
                NavigationLink { RequestsView() } label: { row(.requests, "tray.full.fill") }
                NavigationLink { ScheduleView() } label: { row(.schedule, "calendar") }
                NavigationLink { StudentsView() } label: { row(.students, "person.2.fill") }
                NavigationLink { FeeHistoryView() } label: { row(.feeLedger, "list.bullet.rectangle") }
            }
        }.navigationTitle(app.text(.teacherDashboard))
    }
    private func metric(_ title: L10n, _ value: String) -> some View {
        VStack(spacing: 8) {
            Text(value).font(.title.bold()).foregroundStyle(DaamTheme.primary)
            Text(app.text(title)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }.frame(maxWidth: .infinity, minHeight: 94).daamCard(radius: 20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DaamTheme.primary.opacity(0.3), lineWidth: 1.5))
    }
    private func row(_ title: L10n, _ symbol: String) -> some View {
        HStack { Label(app.text(title), systemImage: symbol).font(.headline); Spacer(); Image(systemName: "chevron.forward") }
            .padding(20).daamCard(radius: 18)
    }
}

struct RequestsView: View {
    @State private var nearbyOnly = true
    @EnvironmentObject private var app: AppModel
    private var requests: [Lesson] { app.teacherLessons.filter { $0.status == .pending && (!nearbyOnly || app.matchesArea($0.area, teacherID: app.selectedTeacherID)) }.sorted { $0.date < $1.date } }
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .teaching, height: 150)
            NoticeCard(title: .firstFreeTitle, bodyKey: .firstFreeBody, symbol: "gift.fill")
            Toggle(app.text(.nearbyOnly), isOn: $nearbyOnly)
            Text(app.text(.areaMatchingNote)).font(.caption).foregroundStyle(DaamTheme.secondary)
            if requests.isEmpty { EmptyState(title: .emptyRequests, message: .emptyRequestsBody, artwork: .teaching) }
            ForEach(requests) { lesson in
                NavigationLink { RequestDetailView(lessonID: lesson.id) } label: { LessonTile(lesson: lesson) }.buttonStyle(.plain)
            }
        }.navigationTitle(app.text(.requests))
    }
}

struct RequestDetailView: View {
    let lessonID: UUID
    @EnvironmentObject private var app: AppModel
    @State private var confirmAccept = false
    @State private var confirmDecline = false
    @State private var showSuccess = false
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .teaching, height: 170)
            if let lesson = app.lesson(lessonID) {
                LessonTile(lesson: lesson)
                VStack(spacing: 12) {
                    SummaryRow(title: .grade, value: L10n.gradeFormat.format(app.language, lesson.grade))
                    SummaryRow(title: .studentLocation, value: lesson.address)
                    if !lesson.notes.isEmpty { SummaryRow(title: .notes, value: lesson.notes) }
                    SummaryRow(title: .lessonPrice, value: app.money(lesson.price))
                }.padding(18).daamCard()
                if lesson.status == .pending {
                    NoticeCard(title: .nextFee, bodyKey: app.nextAcceptanceFee == 0 ? .acceptFree : .acceptPaid, symbol: "info.circle.fill")
                    if app.nextAcceptanceFee == 0 || app.transfer(for: lessonID)?.status == .verified {
                        Button(app.text(.acceptLesson)) { confirmAccept = true }.buttonStyle(DaamButtonStyle())
                    } else {
                        NavigationLink { CliQPaymentView(lessonID: lessonID) } label: {
                            Text(app.text(app.transfer(for: lessonID) == nil ? .cliqTitle : .awaitingVerification))
                        }.buttonStyle(DaamButtonStyle())
                    }
                    Button(app.text(.declineLesson), role: .destructive) { confirmDecline = true }.buttonStyle(DaamButtonStyle(outlined: true))
                } else if lesson.status == .accepted {
                    SummaryRow(title: .feeTotal, value: app.money(lesson.acceptanceFee ?? 0))
                    NoticeCard(title: .accepted, bodyKey: .feeRecorded)
                }
            }
        }.navigationTitle(app.text(.requestDetails))
            .confirmationDialog(app.text(.confirmAccept), isPresented: $confirmAccept, titleVisibility: .visible) {
                Button(app.text(.confirmAccept)) { showSuccess = app.accept(lessonID) }
                Button(app.text(.cancel), role: .cancel) { }
            } message: { Text(app.text(app.nextAcceptanceFee == 0 ? .acceptFree : .acceptPaid)) }
            .confirmationDialog(app.text(.declineLesson), isPresented: $confirmDecline, titleVisibility: .visible) {
                Button(app.text(.declineLesson), role: .destructive) { app.decline(lessonID) }
                Button(app.text(.cancel), role: .cancel) { }
            } message: { Text(app.text(.declineConfirmation)) }
            .alert(app.text(.accepted), isPresented: $showSuccess) { Button(app.text(.done), role: .cancel) { } } message: { Text(app.text(.feeRecorded)) }
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var app: AppModel
    @State private var day = Date()
    private var lessons: [Lesson] { app.teacherLessons.filter { $0.status == .accepted && Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date } }
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .schedule, height: 135)
            DatePicker(app.text(.date), selection: $day, displayedComponents: .date).datePickerStyle(.graphical).padding(12).daamCard()
            if lessons.isEmpty { EmptyState(title: .emptySchedule, message: .emptyScheduleBody) }
            ForEach(lessons) { lesson in
                NavigationLink { RequestDetailView(lessonID: lesson.id) } label: { LessonTile(lesson: lesson) }.buttonStyle(.plain)
            }
        }.navigationTitle(app.text(.schedule))
    }
}

struct StudentsView: View {
    @EnvironmentObject private var app: AppModel
    private var groups: [(String, [Lesson])] {
        Dictionary(grouping: app.teacherLessons.filter { $0.status == .accepted }, by: \.student).sorted { $0.key < $1.key }
    }
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .learning, height: 170)
            if groups.isEmpty { EmptyState(title: .emptyStudents, message: .emptyStudentsBody, artwork: .learning) }
            ForEach(groups, id: \.0) { name, lessons in
                VStack(alignment: .leading, spacing: 10) {
                    Text(name).font(.headline)
                    SummaryRow(title: .confirmedLessons, value: "\(lessons.count)")
                    if let next = lessons.sorted(by: { $0.date < $1.date }).first {
                        Text(next.date, format: .dateTime.day().month().hour().minute().locale(app.language.locale)).font(.footnote).foregroundStyle(DaamTheme.secondary)
                    }
                }.padding(18).daamCard()
            }
        }.navigationTitle(app.text(.students))
    }
}

struct FeeHistoryView: View {
    @EnvironmentObject private var app: AppModel
    private var accepted: [Lesson] { app.teacherLessons.filter { $0.status == .accepted } }
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .schedule, height: 150)
            NoticeCard(title: .firstFreeTitle, bodyKey: .firstFreeBody, symbol: "gift.fill")
            if accepted.isEmpty { Text(app.text(.noFeesYet)).foregroundStyle(DaamTheme.secondary) }
            ForEach(accepted) { lesson in
                VStack(alignment: .leading, spacing: 10) {
                    Text(lesson.student).font(.headline)
                    SummaryRow(title: .feeTotal, value: app.money(lesson.acceptanceFee ?? 0))
                    Text(lesson.date, format: .dateTime.day().month().locale(app.language.locale)).font(.footnote)
                }.padding(18).daamCard()
            }
            Text(app.text(.demoNotice)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }.navigationTitle(app.text(.feeLedger))
    }
}
