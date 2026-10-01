import SwiftUI

enum BookingStep: Int, CaseIterable { case details, schedule, review }

struct BookingFlow: View {
    let teacher: Teacher
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BookingDraft()
    @State private var step: BookingStep = .details
    @State private var completedID: UUID?
    @State private var bookingError: L10n?
    private var validDetails: Bool {
        !draft.student.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        NavigationStack {
            Group {
                if let id = completedID { success(id) }
                else {
                    Page(framed: false) {
                        progress
                        Text(app.text(step == .details ? .bookingDetailsIntro : step == .schedule ? .scheduleIntro : .reviewIntro))
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        switch step {
                        case .details: details
                        case .schedule: schedule
                        case .review: review
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button(app.text(step == .review ? .confirmBooking : .continueAction)) {
                            switch step {
                            case .details: step = .schedule
                            case .schedule: step = .review
                            case .review:
                                completedID = app.book(draft, teacher: teacher)
                                if completedID == nil {
                                    bookingError = app.error
                                    app.error = nil
                                }
                            }
                        }.buttonStyle(DaamButtonStyle())
                            .disabled(step == .details ? !validDetails : draft.date <= Date() || draft.address.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                            .padding(20).background(DaamTheme.background)
                    }
                }
            }
            .daamScreen()
            .navigationTitle(app.text(completedID != nil ? .successTitle : step == .details ? .bookingDetails : step == .schedule ? .dateTime : .review))
            .navigationBarTitleDisplayMode(.inline)
            .alert(app.text(.errorTitle), isPresented: Binding(get: { bookingError != nil }, set: { if !$0 { bookingError = nil } })) {
                Button(app.text(.done), role: .cancel) { bookingError = nil }
            } message: { Text(bookingError.map { app.text($0) } ?? "") }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(app.text(completedID != nil ? .done : .cancel)) { dismiss() }
                }
                if step != .details && completedID == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { step = step == .review ? .schedule : .details } label: { Image(systemName: "chevron.backward") }
                    }
                }
            }
        }
        .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, app.language.locale)
        .multilineTextAlignment(.leading)
    }
    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(BookingStep.allCases, id: \.rawValue) { item in
                Text(app.text(item == .details ? .stepDetails : item == .schedule ? .stepTime : .stepReview))
                    .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(item == step ? DaamTheme.primary : Color("Mint"), in: Capsule())
                    .foregroundStyle(item == step ? .white : DaamTheme.primary)
            }
        }
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 20) {
            TeacherTile(teacher: teacher)
            input(.studentName, hint: .studentHint, value: $draft.student)
            HStack {
                Text(app.text(.grade)).font(.subheadline.bold())
                Spacer()
                Picker(app.text(.grade), selection: $draft.grade) {
                    ForEach(1...12, id: \.self) { grade in Text(L10n.gradeFormat.format(app.language, grade)).tag(grade) }
                }.pickerStyle(.menu).labelsHidden()
            }.padding(16).daamCard(radius: 14)
            input(.notes, hint: .notesHint, value: $draft.notes)
            Label(app.text(.cashBadge), systemImage: "checkmark.shield").font(.footnote).foregroundStyle(DaamTheme.primary)
        }
    }
    private var schedule: some View {
        VStack(alignment: .leading, spacing: 20) {
            DatePicker(app.text(.date), selection: $draft.date, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical).padding(12).daamCard()
            DatePicker(app.text(.time), selection: $draft.date, in: Date()..., displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact).padding(16).daamCard()
            input(.studentLocation, hint: .addressHint, value: $draft.address)
            SummaryRow(title: .duration, value: app.text(.oneHour))
            Text(app.text(.availabilityNote)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }
    }
    private var review: some View {
        VStack(spacing: 18) {
            TeacherTile(teacher: teacher)
            VStack(spacing: 12) {
                SummaryRow(title: .studentName, value: draft.student)
                SummaryRow(title: .grade, value: L10n.gradeFormat.format(app.language, draft.grade))
                SummaryRow(title: .dateTime, value: draft.date.formatted(.dateTime.day().month().hour().minute().locale(app.language.locale)))
                SummaryRow(title: .teacherLocation, value: app.teacherLocation(teacher))
                SummaryRow(title: .studentLocation, value: draft.address)
                Divider()
                Text(app.text(.paymentSummary)).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                SummaryRow(title: .lessonPrice, value: app.money(app.hourlyRate(teacher)))
                SummaryRow(title: .bookingFee, value: app.money(0))
                SummaryRow(title: .dueNow, value: app.money(0))
            }.padding(18).daamCard()
            NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
        }
    }
    private func input(_ title: L10n, hint: L10n, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(app.text(title)).font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
            LocalizedTextField(placeholder: app.text(hint), text: value)
                .frame(height: 26)
                .padding(16).daamCard(radius: 14)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func success(_ id: UUID) -> some View {
        Page(framed: false) {
            AnimatedArtwork(artwork: .schedule, height: 240)
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(DaamTheme.primary).frame(maxWidth: .infinity)
            Text(app.text(.successTitle)).font(.largeTitle.bold())
            Text(app.text(.successBody)).foregroundStyle(DaamTheme.secondary)
            if let lesson = app.lesson(id) { LessonTile(lesson: lesson) }
            NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
            Button(app.text(.done)) { dismiss() }.buttonStyle(DaamButtonStyle())
        }
    }
}
