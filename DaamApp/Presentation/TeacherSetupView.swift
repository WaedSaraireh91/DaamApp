import SwiftUI
import UniformTypeIdentifiers

struct TeacherRateView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var rate = ""
    var body: some View {
        Page {
            BrandHeader()
            AnimatedArtwork(artwork: .teaching, height: 210)
            Text(app.text(.rateSetupTitle)).font(.largeTitle.bold())
            Text(app.text(.rateSetupBody)).foregroundStyle(DaamTheme.secondary)
            Text(app.teacherName(app.teacher(app.selectedTeacherID))).font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                Text(app.text(.hourlyRate)).font(.subheadline.bold())
                LocalizedTextField(placeholder: app.text(.rateHint), text: $rate, keyboard: .numberPad)
                    .frame(height: 28).padding(16).daamCard()
            }
            Button(app.text(.saveRate)) {
                if app.saveHourlyRate(rate) { dismiss() }
            }.buttonStyle(DaamButtonStyle()).disabled(rate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text(app.text(.demoNotice)).font(.caption).foregroundStyle(DaamTheme.secondary)
        }
        .navigationTitle(app.text(.hourlyRate))
        .onAppear { if let saved = app.snapshot.hourlyRates[app.selectedTeacherID] { rate = String(saved) } }
    }
}

struct CliQPaymentView: View {
    let lessonID: UUID
    @EnvironmentObject private var app: AppModel
    @State private var reference = ""
    var body: some View {
        Page {
            AnimatedArtwork(artwork: .schedule, height: 150)
            Text(app.text(.cliqTitle)).font(.title.bold())
            Text(app.text(.cliqBody)).foregroundStyle(DaamTheme.secondary)
            DashboardPanel {
                SummaryRow(title: .feeTotal, value: app.money(1))
                if app.paymentConfiguration.isConfigured {
                    SummaryRow(title: .cliqRecipient, value: app.paymentConfiguration.recipientName ?? "")
                    SummaryRow(title: .cliqAlias, value: app.paymentConfiguration.cliqAlias ?? "")
                } else {
                    Text(app.text(.cliqNotConfigured)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
                }
            }
            if let transfer = app.transfer(for: lessonID), transfer.status != .rejected {
                NoticeCard(title: transfer.status == .verified ? .paymentVerified : .awaitingVerification, bodyKey: .verificationBody, symbol: "clock.fill")
                SummaryRow(title: .transferReference, value: transfer.reference)
                if transfer.status == .verified {
                    NavigationLink { RequestDetailView(lessonID: lessonID) } label: { Text(app.text(.continueAction)) }.buttonStyle(DaamButtonStyle())
                }
            } else {
                if app.transfer(for: lessonID)?.status == .rejected {
                    NoticeCard(title: .transferRejected, bodyKey: .transferRejectedBody, symbol: "exclamationmark.circle")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(app.text(.transferReference)).font(.subheadline.bold())
                    LocalizedTextField(placeholder: app.text(.referenceHint), text: $reference)
                        .frame(height: 28).padding(16).daamCard()
                }
                Button(app.text(.submitTransfer)) { _ = app.submitTransfer(for: lessonID, reference: reference) }
                    .buttonStyle(DaamButtonStyle())
                    .disabled(!app.paymentConfiguration.isConfigured || reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(app.text(.demoNoTransfers)).font(.footnote).foregroundStyle(DaamTheme.secondary)
        }.navigationTitle(app.text(.cliqTitle))
    }
}

/// Registration documents are private local records, never part of the public teacher view.
struct RegistrationView: View {
    let isTeacher: Bool
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var bio = ""
    @State private var areas: Set<JordanArea> = []
    @State private var parentArea: JordanArea = .jubeiha
    @State private var certificate = ""
    @State private var accepted = false
    @State private var importing = false
    @State private var showDisclaimer = false
    @AppStorage("daam.disclaimer.parent.v1") private var parentDisclaimerShown = false
    @AppStorage("daam.disclaimer.teacher.v1") private var teacherDisclaimerShown = false
    private var canContinue: Bool {
        accepted && (!isTeacher || ((20...1000).contains(bio.trimmingCharacters(in: .whitespacesAndNewlines).count) && !areas.isEmpty && !certificate.isEmpty))
    }
    var body: some View {
        Page {
            BrandHeader()
            Text(app.text(.registrationTitle)).font(.largeTitle.bold())
            if isTeacher {
                DashboardPanel {
                    Text(app.text(.experienceBrief)).font(.headline)
                    Text(app.text(.experienceHint)).font(.caption).foregroundStyle(DaamTheme.secondary)
                    TextEditor(text: $bio).frame(minHeight: 120)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel(app.text(.experienceBrief))
                }
                DashboardPanel {
                    Text(app.text(.teachingAreas)).font(.headline)
                    Text(app.text(.areaMatchingNote)).font(.caption).foregroundStyle(DaamTheme.secondary)
                    ForEach(JordanArea.allCases) { area in
                        Toggle(app.text(area.key), isOn: Binding(get: { areas.contains(area) }, set: { if $0 { areas.insert(area) } else { areas.remove(area) } }))
                    }
                }
//                DashboardPanel {
//                    Label(app.text(.privateCertificate), systemImage: "lock.doc").font(.headline)
//                    Text(app.text(.certificateNotice)).font(.footnote).foregroundStyle(DaamTheme.secondary)
//                    if !certificate.isEmpty { Label(app.text(.certificateStored), systemImage: "doc.badge.checkmark") }
//                    Button(app.text(.chooseCertificate)) { importing = true }.buttonStyle(DaamButtonStyle(outlined: true))
//                }
            } else {
                Picker(app.text(.studentArea), selection: $parentArea) {
                    ForEach(JordanArea.allCases) { Text(app.text($0.key)).tag($0) }
                }.padding(16).daamCard()
                Text(app.text(.areaMatchingNote)).font(.footnote).foregroundStyle(DaamTheme.secondary)
            }
            DashboardPanel {
                Text(app.text(.declarationTitle)).font(.headline)
                Text(app.text(isTeacher ? .teacherDeclaration : .parentDeclaration)).font(.subheadline)
                Toggle(app.text(.acceptDeclaration), isOn: $accepted)
            }
            Button(app.text(.continueAction)) {
                let saved = isTeacher
                    ? app.saveTeacherRegistration(bio: bio, areas: areas, certificate: certificate, accepted: accepted)
                    : app.saveParentRegistration(area: parentArea, accepted: accepted)
                if saved {
                    if isTeacher ? !teacherDisclaimerShown : !parentDisclaimerShown { showDisclaimer = true }
                    else { dismiss() }
                }
            }.buttonStyle(DaamButtonStyle()).disabled(!canContinue)
        }
        .onAppear {
            if let profile = app.snapshot.teacherProfiles[app.selectedTeacherID], isTeacher {
                bio = profile.bio; areas = profile.areas; certificate = profile.certificateFile
            }
            parentArea = app.snapshot.parentRegistration?.area ?? .jubeiha
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= 10 * 1024 * 1024 else { app.error = .certificateError; return }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count <= 10 * 1024 * 1024 else { app.error = .certificateError; return }
                var directory = AppModel.certificateDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true
                try directory.setResourceValues(values)
                let name = UUID().uuidString + "." + url.pathExtension.lowercased()
                try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
                // Remove an unsaved replacement; retain the currently committed record until save succeeds.
                if !certificate.isEmpty, certificate != app.snapshot.teacherProfiles[app.selectedTeacherID]?.certificateFile {
                    try? FileManager.default.removeItem(at: directory.appendingPathComponent(certificate))
                }
                certificate = name
            } catch { app.error = .certificateError }
        }
        .sheet(isPresented: $showDisclaimer) {
            RegistrationDisclaimerView(isTeacher: isTeacher) {
                if isTeacher { teacherDisclaimerShown = true } else { parentDisclaimerShown = true }
                showDisclaimer = false
                dismiss()
            } onDismiss: {
                showDisclaimer = false
                dismiss()
            }
            .environmentObject(app)
            .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
            .environment(\.locale, app.language.locale)
        }
    }
}

struct RegistrationDisclaimerView: View {
    let isTeacher: Bool
    let onAgree: () -> Void
    let onDismiss: () -> Void
    @EnvironmentObject private var app: AppModel
    @State private var checked = false
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.secondary.opacity(0.18)).frame(width: 52, height: 6).padding(.top, 12)
            VStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 28)).foregroundStyle(DaamTheme.primary)
                Text(app.text(.declarationTitle)).font(.title2.bold())
                Text(app.text(isTeacher ? .teacher : .parent)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(app.text(.termsTitle)).font(.headline)
                    Text(app.text(isTeacher ? .teacherDeclaration : .parentDeclaration)).foregroundStyle(DaamTheme.secondary).lineSpacing(5)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }.frame(maxHeight: 300)
            Divider()
            Toggle(isOn: $checked) { Text(app.text(.acceptDeclaration)).font(.subheadline) }.padding(.horizontal, 20).padding(.vertical, 14)
            Button(app.text(.agreeContinue)) { onAgree() }.buttonStyle(DaamButtonStyle()).disabled(!checked).padding(.horizontal, 20)
            Button(app.text(.dismissAction), action: onDismiss).buttonStyle(DaamButtonStyle(outlined: true)).padding(20)
        }.presentationDetents([.large]).presentationDragIndicator(.hidden)
    }
}
