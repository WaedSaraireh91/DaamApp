import SwiftUI
import UniformTypeIdentifiers
import MapKit
import PhotosUI
import UIKit

struct LiveTutoringView: View {
  let account: AccountProfile
  let signOut: () -> Void
  @StateObject private var model: TutoringViewModel
  @EnvironmentObject private var app: AppModel
  init(account: AccountProfile, service: AuthenticationService, signOut: @escaping () -> Void) {
    self.account = account
    self.signOut = signOut
    _model = StateObject(wrappedValue: TutoringViewModel(service: service))
  }
  var body: some View {
    Group {
      if !model.loaded {
        ProgressView().task { model.run { try await model.load() } }
      } else if let profile = model.profile {
        TabView {
          NavigationStack { dashboard(profile) }.tabItem {
            Label(app.text(.home), systemImage: "house.fill")
          }
          NavigationStack { LiveLessonsView(model: model, profile: profile) }.tabItem {
            Label(app.text(.bookings), systemImage: "calendar")
          }
          if profile.isTeacher {
            NavigationStack { LiveNotificationsView(model: model, profile: profile) }
              .tabItem { Label(app.text(.notifications), systemImage: "bell") }
              .badge(model.notificationCount(for: profile))
          } else {
            NavigationStack { teacherList(favoritesOnly: true) }.tabItem {
              Label(app.text(.favorites), systemImage: "heart.fill")
            }
          }
          NavigationStack { LiveMessagesView(model: model) }
            .tabItem { Label(app.text(.messages), systemImage: "envelope.fill") }
          NavigationStack { LiveAccountView(model: model, account: account, signOut: signOut) }
            .tabItem { Label(app.text(.account), systemImage: "person.crop.circle") }
        }
      } else {
        NavigationStack { LiveProfileForm(model: model) }
      }
    }
    .overlay {
      if model.busy {
        ProgressView().padding().background(
          .regularMaterial, in: RoundedRectangle(cornerRadius: 16))
      }
    }
    .disabled(model.busy)
    .alert(
      app.text(.errorTitle),
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button(app.text(.retry)) { model.run { try await model.load() } }
      Button(app.text(.done), role: .cancel) { model.error = nil }
    } message: {
      Text(app.text(model.error ?? .authTryAgain))
    }
    .task(id: model.profile?.id) {
      guard model.profile != nil else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(45))
        guard !Task.isCancelled else { return }
        try? await model.refreshLessons()
      }
    }
  }
  @ViewBuilder private func dashboard(_ profile: LiveProfile) -> some View {
    if profile.isTeacher {
      Page {
        BrandHeader()
        NotificationSummaryBanner(model: model, profile: profile)
        Text(profile.displayName).font(.title.bold())
        AnimatedArtwork(artwork: .teaching, height: 150)
        NoticeCard(
          title: model.feePolicy?.firstFreeAvailable == true ? .firstFreeTitle : .cliqTitle,
          bodyKey: model.feePolicy?.firstFreeAvailable == true ? .firstFreeBody : .cliqBody,
          symbol: "creditcard.fill")
        NavigationLink(app.text(.schedule)) {
          LiveAvailabilityView(model: model, teacherID: profile.id)
        }.buttonStyle(DaamButtonStyle())
        NavigationLink(app.text(.profile)) { LiveProfileForm(model: model) }.buttonStyle(
          DaamButtonStyle(outlined: true))
      }.navigationTitle(app.text(.teacherDashboard))
    } else {
      if model.lessons.isEmpty {
        teacherList(favoritesOnly: false)
      } else {
        parentDashboard(profile)
      }
    }
  }
  private func parentDashboard(_ profile: LiveProfile) -> some View {
    let nextLesson = model.lessons
      .filter { ["PENDING", "ACCEPTED"].contains($0.status) && $0.endsAt > Date() }
      .sorted { $0.startsAt < $1.startsAt }
      .first
    let highlightedLesson = nextLesson ?? model.lessons.max { $0.startsAt < $1.startsAt }
    return Page {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 7) {
          Text(app.text(.parentGreeting)).font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
          Text(profile.displayName).font(.subheadline.weight(.medium))
            .foregroundStyle(DaamTheme.primary)
        }
        Spacer(minLength: 0)
        Image("ParentLearning").resizable().scaledToFit()
          .frame(width: 104, height: 96).accessibilityHidden(true)
      }.padding(.horizontal, 15).padding(.vertical, 10)
        .background(Color("Mint"), in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(DaamTheme.primary.opacity(0.16), lineWidth: 1))
      NotificationSummaryBanner(model: model, profile: profile)
      if let lesson = highlightedLesson {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(app.text(nextLesson == nil ? .latestLesson : .yourLesson))
              .font(.title3.bold())
            Spacer()
            StatusPill(
              text: app.text(L10n(rawValue: lesson.status.lowercased()) ?? .pending),
              status: lesson.status)
          }
          ParentLessonCard(lesson: lesson)
          if nextLesson == nil {
            Label(app.text(.noUpcomingLessons), systemImage: "calendar.badge.clock")
              .font(.footnote).foregroundStyle(DaamTheme.secondary)
          }
        }
      }
      NavigationLink {
        LiveLessonsView(model: model, profile: profile)
      } label: {
        Label(app.text(.viewBookings), systemImage: "calendar")
      }.buttonStyle(DaamButtonStyle())
      NavigationLink {
        teacherList(favoritesOnly: false)
      } label: {
        Label(app.text(.browseTeachers), systemImage: "magnifyingglass")
      }.buttonStyle(DaamButtonStyle(outlined: true))
      Label(app.text(.noBookingFee), systemImage: "banknote")
        .font(.footnote.weight(.medium)).foregroundStyle(DaamTheme.primary)
        .frame(maxWidth: .infinity, alignment: .center)
    }.navigationTitle(app.text(.home))
  }
  private func teacherList(favoritesOnly: Bool) -> some View {
    Page {
      if !favoritesOnly, let profile = model.profile {
        NotificationSummaryBanner(model: model, profile: profile)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text(app.text(favoritesOnly ? .favorites : .nearbyTeachers)).font(.largeTitle.bold())
        if !favoritesOnly, let profile = model.profile {
          Label(app.text(JordanArea(rawValue: profile.area)?.key ?? .location), systemImage: "mappin.and.ellipse")
            .font(.subheadline).foregroundStyle(DaamTheme.secondary)
        }
      }
      if !favoritesOnly {
        Label(app.text(.noBookingFee), systemImage: "banknote")
          .font(.footnote.weight(.medium)).foregroundStyle(DaamTheme.primary)
          .padding(.horizontal, 14).padding(.vertical, 10)
          .background(Color("Mint"), in: Capsule())
      }
      let teachers = favoritesOnly ? model.favoriteTeachers : model.teachers
      if teachers.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: favoritesOnly ? "heart" : "person.2")
            .font(.title2).foregroundStyle(DaamTheme.primary)
          Text(app.text(favoritesOnly ? .emptyFavorites : .emptySearch)).font(.headline)
          Text(app.text(favoritesOnly ? .emptyFavoritesBody : .noAreaMatches))
            .font(.subheadline).foregroundStyle(DaamTheme.secondary)
            .multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(24).daamCard(radius: 20)
      }
      ForEach(teachers) { teacher in
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            TeacherProfileAvatar(teacherID: teacher.id, name: teacher.displayName, size: 54)
            VStack(alignment: .leading, spacing: 5) {
              Text(teacher.displayName).font(.headline)
              Text(teacher.subjects.map { app.text(L10n(rawValue: $0) ?? .lesson) }.joined(separator: " • "))
                .font(.caption).foregroundStyle(DaamTheme.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { model.favorite(teacher) } label: {
              Image(systemName: model.favorites.contains(teacher.id) ? "heart.fill" : "heart")
                .font(.title3).foregroundStyle(model.favorites.contains(teacher.id) ? Color.red : DaamTheme.secondary)
                .frame(width: 42, height: 42).background(Color("Canvas"), in: Circle())
            }.accessibilityLabel(app.text(.favorites))
          }
          if !teacher.bio.isEmpty {
            Text(teacher.bio).font(.subheadline).foregroundStyle(DaamTheme.secondary).lineLimit(2)
          }
          HStack(spacing: 8) {
            Label(teacherAreaSummary(teacher.teachingAreas), systemImage: "mappin.and.ellipse")
              .font(.caption).foregroundStyle(DaamTheme.secondary).lineLimit(1)
            Spacer(minLength: 4)
          }
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(L10n.perHour.format(
              app.language,
              (teacher.hourlyRate ?? 0).formatted(.currency(code: "JOD"))))
              .font(.title3.bold()).foregroundStyle(DaamTheme.primary)
          }
          NavigationLink {
            LiveBookingView(model: model, teacher: teacher)
          } label: {
            Label(app.text(.bookLesson), systemImage: "arrow.forward")
              .font(.subheadline.bold()).frame(maxWidth: .infinity)
          }.buttonStyle(DaamButtonStyle())
        }.padding(16).daamCard(radius: 20)
      }
      if model.more.contains(favoritesOnly ? "favorites" : "teachers") {
        Button(app.text(.loadMore)) { model.loadMore(favoritesOnly ? "favorites" : "teachers") }
      }
    }.refreshable { model.run { try await model.load() } }
  }
  private func teacherAreaSummary(_ areas: [String]) -> String {
    var seen = Set<String>()
    let names = areas.filter { seen.insert($0).inserted }
      .map { app.text(JordanArea(rawValue: $0)?.key ?? .location) }
    let visible = names.prefix(2).joined(separator: " • ")
    let remaining = max(0, names.count - 2)
    return remaining == 0 ? visible : "\(visible) +\(remaining)"
  }
}

struct TeacherProfileAvatar: View {
  let teacherID: UUID?
  let name: String
  var size: CGFloat = 52
  var localData: Data?
  private var photoURL: URL? {
    guard let teacherID, let configuration = BackendConfiguration.configured else { return nil }
    return configuration.url.appendingPathComponent("api/v1/public/teachers/\(teacherID)/photo")
  }
  var body: some View {
    Group {
      if let localData, let image = UIImage(data: localData) {
        Image(uiImage: image).resizable().scaledToFill()
      } else if let photoURL {
        AsyncImage(url: photoURL) { phase in
          if let image = phase.image {
            image.resizable().scaledToFill()
          } else {
            placeholder
          }
        }
      } else {
        placeholder
      }
    }.frame(width: size, height: size)
      .background(Color("Mint"))
      .clipShape(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
        .stroke(.white.opacity(0.85), lineWidth: 2))
      .accessibilityLabel(name)
  }
  private var placeholder: some View {
    Text(String(name.prefix(1)).uppercased())
      .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
      .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(DaamTheme.primary.gradient)
  }
}

private struct ParentLessonCard: View {
  let lesson: LiveLesson
  @EnvironmentObject private var app: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 17) {
      HStack(spacing: 12) {
        TeacherProfileAvatar(teacherID: lesson.teacherId, name: lesson.teacherName, size: 54)
        VStack(alignment: .leading, spacing: 4) {
          Text(lesson.teacherName).font(.headline)
          Text(lesson.subject).font(.subheadline).foregroundStyle(DaamTheme.secondary)
        }
        Spacer(minLength: 4)
        Image(systemName: "books.vertical.fill").font(.title2)
          .foregroundStyle(DaamTheme.primary.opacity(0.55))
      }

      HStack(spacing: 12) {
        Image(systemName: "calendar")
          .font(.title3).foregroundStyle(DaamTheme.primary)
          .frame(width: 42, height: 42).background(.white, in: Circle())
        VStack(alignment: .leading, spacing: 4) {
          Text(lesson.startsAt, format: .dateTime.weekday(.wide).day().month().locale(app.language.locale))
            .font(.subheadline.bold())
          Text(lesson.startsAt, format: .dateTime.hour().minute().locale(app.language.locale))
            .font(.caption).foregroundStyle(DaamTheme.secondary)
        }
        Spacer()
      }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Mint"), in: RoundedRectangle(cornerRadius: 18))

      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "mappin.and.ellipse").foregroundStyle(DaamTheme.primary)
        VStack(alignment: .leading, spacing: 4) {
          Text(app.text(.studentLocation)).font(.caption).foregroundStyle(DaamTheme.secondary)
          Text(app.text(JordanArea(rawValue: lesson.area)?.key ?? .location) + " • " + lesson.address)
            .font(.subheadline).lineLimit(2)
        }
      }

      HStack {
        Label(
          lesson.total.formatted(.currency(code: "JOD").locale(app.language.locale)),
          systemImage: "banknote.fill")
          .font(.subheadline.bold()).foregroundStyle(DaamTheme.primary)
        Spacer()
        Text(app.text(.cashBadge)).font(.caption.weight(.medium))
          .foregroundStyle(DaamTheme.secondary).padding(.horizontal, 11).padding(.vertical, 7)
          .background(.white.opacity(0.8), in: Capsule())
      }.padding(12).background(Color("Peach"), in: RoundedRectangle(cornerRadius: 17))
    }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 23))
      .overlay(RoundedRectangle(cornerRadius: 23).stroke(DaamTheme.primary.opacity(0.18), lineWidth: 1))
      .shadow(color: DaamTheme.primary.opacity(0.06), radius: 12, y: 5)
  }
}

struct LiveProfileForm: View {
  @ObservedObject var model: TutoringViewModel
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var kind = "PARENT"
  @State private var area = JordanArea.amman
  @State private var bio = ""
  @State private var rate = ""
  @State private var areas: Set<String> = []
  @State private var subjects: Set<String> = []
  @State private var declaration = false
  @State private var showImporter = false
  @State private var certificate: Data?
  @State private var certificateType = "application/pdf"
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var profilePhotoData: Data?
  @State private var loadingPhoto = false
  var body: some View {
    Page {
      BrandHeader()
      Picker(app.text(.chooseRole), selection: $kind) {
        Text(app.text(.parent)).tag("PARENT")
        Text(app.text(.teacher)).tag("TEACHER")
      }.pickerStyle(.segmented).disabled(model.profile != nil)
      Picker(app.text(.location), selection: $area) {
        ForEach(JordanArea.allCases) { Text(app.text($0.key)).tag($0) }
      }
      if kind == "TEACHER" {
        HStack(spacing: 14) {
          TeacherProfileAvatar(
            teacherID: model.profile?.id, name: model.profile?.displayName ?? app.text(.teacher),
            size: 76, localData: profilePhotoData)
          VStack(alignment: .leading, spacing: 6) {
            Text(app.text(.teacherPhoto)).font(.headline)
            Text(app.text(.teacherPhotoHint)).font(.footnote).foregroundStyle(DaamTheme.secondary)
              .fixedSize(horizontal: false, vertical: true)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
              Label(
                app.text(
                  profilePhotoData != nil || model.profile?.profilePhotoUploaded == true
                    ? .changeTeacherPhoto : .addTeacherPhoto),
                systemImage: "camera.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(DaamTheme.primary)
            }
          }
          Spacer(minLength: 0)
        }.padding(14).background(Color("Sky"), in: RoundedRectangle(cornerRadius: 20))
          .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.blue.opacity(0.18), lineWidth: 1))
        Field(title: app.text(.experienceBrief), placeholder: app.text(.experienceHint), text: $bio)
        Field(
          title: app.text(.hourlyRate), placeholder: app.text(.rateHint), text: $rate,
          keyboard: .decimalPad)
        Text(app.text(.teachingAreas)).font(.headline)
        ForEach(JordanArea.allCases) { value in
          Toggle(app.text(value.key), isOn: membership(value.rawValue, in: $areas))
        }
        Text(app.text(.subjectsTitle)).font(.headline)
        ForEach(["math", "english", "science"], id: \.self) { subject in
          Toggle(app.text(L10n(rawValue: subject)!), isOn: membership(subject, in: $subjects))
        }
VStack(alignment: .leading, spacing: 10) {
          Label(app.text(.privateCertificate), systemImage: "lock.doc.fill").font(.headline)
          Text(app.text(.certificateNotice)).font(.footnote).foregroundStyle(.secondary)
          if certificate != nil || model.profile?.certificateUploaded == true {
            Label(app.text(.certificateStored), systemImage: "doc.badge.checkmark")
              .font(.subheadline).foregroundStyle(DaamTheme.primary)
          }
          Button(app.text(certificate == nil ? .chooseCertificate : .certificateStored)) {
            showImporter = true
          }.buttonStyle(DaamButtonStyle(outlined: true))
        }.padding().daamCard()
      }
      if model.profile == nil {
        Text(app.text(kind == "TEACHER" ? .teacherDeclaration : .parentDeclaration)).font(.footnote)
        Toggle(app.text(.acceptDeclaration), isOn: $declaration)
      }
      Button(app.text(.save)) { save() }.buttonStyle(DaamButtonStyle()).disabled(!valid || loadingPhoto)
    }
    .navigationTitle(app.text(.profile))
    .onAppear {
      if let p = model.profile {
        kind = p.kind
        area = JordanArea(rawValue: p.area) ?? .amman
        bio = p.bio
        rate = p.hourlyRate.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        areas = Set(p.teachingAreas)
        subjects = Set(p.subjects)
        declaration = true
      }
    }
    .onChange(of: selectedPhoto) { _, item in
      guard let item else { return }
      Task {
        loadingPhoto = true
        defer { loadingPhoto = false }
        do {
          guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data), let compressed = Self.profilePhotoJPEG(image)
          else {
            model.error = .profilePhotoError
            return
          }
          profilePhotoData = compressed
        } catch {
          model.error = .profilePhotoError
        }
      }
    }
    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .png, .jpeg]) { result in
      do {
        let url = try result.get()
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 5 * 1024 * 1024 else {
          model.error = .certificateError
          return
        }
        certificate = try Data(contentsOf: url)
        certificateType =
          UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/pdf"
      } catch { model.error = .certificateError }
    }
  }
    private var valid: Bool {
        guard model.profile != nil || declaration else {
            return false
        }

        if kind == "TEACHER" {
            return !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && Decimal(string: rate) != nil
                && !areas.isEmpty
                && !subjects.isEmpty
                && (certificate != nil || model.profile?.certificateUploaded == true)
        }

        return true
    }
  private func membership(_ value: String, in set: Binding<Set<String>>) -> Binding<Bool> {
    Binding(
      get: { set.wrappedValue.contains(value) },
      set: { selected in
        if selected { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) }
      })
  }
  private func save() {
    model.run {
      let input = LiveProfileInput(
        kind: kind, area: area.rawValue, bio: bio,
        hourlyRate: kind == "TEACHER" ? Decimal(string: rate) : nil, subjects: Array(subjects),
        teachingAreas: Array(areas), declarationAccepted: declaration)
      let _: LiveProfile? = try await model.service.api(
        "tutoring/profile", method: "PUT", body: JSONEncoder().encode(input))
      if kind == "TEACHER", let certificate {
        let _: EmptyResponse? = try await model.service.api(
          "tutoring/certificate", method: "PUT", body: certificate, contentType: certificateType)
      }
      if kind == "TEACHER", let profilePhotoData {
        let _: EmptyResponse? = try await model.service.api(
          "tutoring/profile/photo", method: "PUT", body: profilePhotoData,
          contentType: "image/jpeg")
      }
      try await model.load()
      dismiss()
    }
  }
  private static func profilePhotoJPEG(_ image: UIImage) -> Data? {
    let size = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: size)
    let square = renderer.image { _ in
      let scale = max(size.width / image.size.width, size.height / image.size.height)
      let rect = CGRect(
        x: (size.width - image.size.width * scale) / 2,
        y: (size.height - image.size.height * scale) / 2,
        width: image.size.width * scale,
        height: image.size.height * scale)
      image.draw(in: rect)
    }
    return square.jpegData(compressionQuality: 0.78)
  }
}

struct LiveAvailabilityView: View {
  @ObservedObject var model: TutoringViewModel
  let teacherID: UUID
  @EnvironmentObject private var app: AppModel
  @State private var slots: [LiveSlot] = []
  @State private var start = Date().addingTimeInterval(86400)
  @State private var duration = 60
  var body: some View {
    Page {
      DatePicker(app.text(.dateTime), selection: $start, in: Date()...)
      Picker(app.text(.duration), selection: $duration) {
        ForEach([30, 60, 90, 120], id: \.self) {
          Text(Duration.seconds($0 * 60).formatted(.units(allowed: [.hours, .minutes]))).tag($0)
        }
      }
      Button(app.text(.addAvailability)) {
        model.run {
          let formatter = ISO8601DateFormatter()
          try await model.mutate(
            "tutoring/slots",
            payload: [
              "startsAt": formatter.string(from: start),
              "endsAt": formatter.string(from: start.addingTimeInterval(Double(duration * 60))),
            ])
          try await load()
        }
      }.buttonStyle(DaamButtonStyle())
      ForEach(slots) { slot in
        Text(slot.startsAt.formatted(date: .abbreviated, time: .shortened)).padding().daamCard()
      }
    }.navigationTitle(app.text(.schedule)).task { model.run { try await load() } }
  }
  private func load() async throws {
    slots = try await model.service.api("tutoring/teachers/\(teacherID)/slots") ?? []
  }
}

struct LiveBookingView: View {
  @ObservedObject var model: TutoringViewModel
  let teacher: LiveProfile
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var slots: [LiveSlot] = []
  @State private var slotID: UUID?
  @State private var subject: String
  @State private var student = ""
  @State private var address = ""
  @State private var location: LessonMapLocation?
  @State private var showLocationPicker = false
  @State private var confirm = false
  init(model: TutoringViewModel, teacher: LiveProfile) {
    self.model = model
    self.teacher = teacher
    _subject = State(initialValue: teacher.subjects.first ?? "")
  }
  var body: some View {
    Page {
      VStack(alignment: .leading, spacing: 6) {
        Text(teacher.displayName).font(.title2.bold())
        Text(teacher.bio).font(.subheadline).foregroundStyle(DaamTheme.secondary).lineLimit(2)
      }
      Label(app.text(.noBookingFee), systemImage: "banknote")
        .font(.footnote.weight(.medium)).foregroundStyle(DaamTheme.primary)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color("Mint"), in: Capsule())
      Field(title: app.text(.studentName), placeholder: app.text(.studentHint), text: $student)
      VStack(alignment: .leading, spacing: 10) {
        Button { showLocationPicker = true } label: {
          Label(app.text(.selectOnMap), systemImage: "map.fill")
            .frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(DaamButtonStyle(outlined: true))
        if let location {
          Label(location.address, systemImage: "mappin.and.ellipse")
            .font(.subheadline).foregroundStyle(DaamTheme.primary)
        }
      }
      Field(title: app.text(.address), placeholder: app.text(.addressHint), text: $address)
      if let profile = model.profile {
        SummaryRow(
          title: .studentArea, value: app.text(JordanArea(rawValue: profile.area)?.key ?? .location)
        )
      }
      if teacher.subjects.count > 1 {
        Picker(app.text(.subjectsTitle), selection: $subject) {
          ForEach(teacher.subjects, id: \.self) {
            Text(app.text(L10n(rawValue: $0) ?? .lesson)).tag($0)
          }
        }
      } else if let onlySubject = teacher.subjects.first {
        SummaryRow(title: .subjectsTitle, value: app.text(L10n(rawValue: onlySubject) ?? .lesson))
      }
      if slots.isEmpty { Text(app.text(.emptySchedule)) }
      ForEach(slots) { slot in
        Button {
          slotID = slot.id
        } label: {
          HStack {
            Text(slot.startsAt.formatted(date: .abbreviated, time: .shortened))
            Spacer()
            Image(systemName: slotID == slot.id ? "checkmark.circle.fill" : "circle")
          }
        }.padding().daamCard()
      }
      if let slot = slots.first(where: { $0.id == slotID }) {
        SummaryRow(title: .lessonPrice, value: total(slot).formatted(.currency(code: "JOD")))
      }
      Button(app.text(.review)) { confirm = true }.buttonStyle(DaamButtonStyle()).disabled(
        slotID == nil || student.trimmingCharacters(in: .whitespaces).isEmpty
          || address.trimmingCharacters(in: .whitespaces).isEmpty || location == nil)
    }.navigationTitle(app.text(.bookLesson))
      .sheet(isPresented: $showLocationPicker) {
        LessonLocationPickerView(area: model.profile?.area ?? "amman") { selection in
          location = selection
          address = selection.address
          showLocationPicker = false
        }
        .environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
      }
      .confirmationDialog(
        app.text(.confirmBooking), isPresented: $confirm, titleVisibility: .visible
      ) {
        Button(app.text(.confirmBooking)) {
          guard let slotID, let profile = model.profile else { return }
          model.run {
            try await model.mutate(
              "tutoring/lessons",
              payload: BookingPayload(
                slotId: slotID, area: profile.area, address: address, subject: subject,
                studentName: student, latitude: location?.latitude, longitude: location?.longitude))
            try await model.load()
            dismiss()
          }
        }
      } message: {
        Text(app.text(.cashPolicy))
      }
      .task {
        subject = teacher.subjects.first ?? ""
        model.run {
          slots = try await model.service.api("tutoring/teachers/\(teacher.id)/slots") ?? []
        }
      }
  }
  private func total(_ slot: LiveSlot) -> Decimal {
    (teacher.hourlyRate ?? 0) * Decimal(slot.endsAt.timeIntervalSince(slot.startsAt) / 3600)
  }
}

struct LiveLessonsView: View {
  @ObservedObject var model: TutoringViewModel
  let profile: LiveProfile
  @EnvironmentObject private var app: AppModel
  @State private var payment: LiveLesson?
  @State private var reference = ""
  var body: some View {
    Page {
      if model.lessons.isEmpty { EmptyState(title: .emptyBookings, message: .emptyBookingsBody) }
      ForEach(model.lessons) { lesson in
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .top, spacing: 12) {
            if profile.isTeacher {
              Text(String(lesson.parentName.prefix(1)).uppercased())
                .font(.title3.bold()).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(DaamTheme.primary.gradient, in: RoundedRectangle(cornerRadius: 16))
            } else {
              TeacherProfileAvatar(teacherID: lesson.teacherId, name: lesson.teacherName, size: 48)
            }
            VStack(alignment: .leading, spacing: 5) {
              Text(profile.isTeacher ? lesson.parentName : lesson.teacherName).font(.headline)
              Text(lesson.subject).font(.subheadline).foregroundStyle(DaamTheme.secondary)
            }
            Spacer(minLength: 4)
            StatusPill(text: app.text(L10n(rawValue: lesson.status.lowercased()) ?? .pending), status: lesson.status)
          }
          Label(lesson.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
            .font(.subheadline.weight(.medium)).foregroundStyle(DaamTheme.text)
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(DaamTheme.primary)
            VStack(alignment: .leading, spacing: 3) {
              Text(app.text(.studentLocation)).font(.caption).foregroundStyle(DaamTheme.secondary)
              Text(app.text(JordanArea(rawValue: lesson.area)?.key ?? .location) + " • " + lesson.address)
                .font(.subheadline).lineLimit(3)
            }
          }
          HStack {
            Label(lesson.total.formatted(.currency(code: "JOD")), systemImage: "banknote")
              .font(.subheadline.bold()).foregroundStyle(DaamTheme.primary)
            Spacer()
            Text(app.text(.cashPolicy)).font(.caption).foregroundStyle(DaamTheme.secondary)
          }
          if profile.isTeacher, let url = directionsURL(for: lesson) {
            Link(destination: url) {
              Label(app.text(.openDirections), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline.weight(.semibold)).foregroundStyle(DaamTheme.primary)
          }
          if profile.isTeacher && lesson.status == "PENDING" {
            if model.feePolicy?.firstFreeAvailable == true {
              Text(app.text(.firstFreeBody)).font(.footnote).foregroundStyle(.secondary)
              Button(app.text(.acceptLesson)) { model.transition(lesson, "accept") }
                .buttonStyle(DaamButtonStyle())
            } else if lesson.feeStatus == "APPROVED" {
              Label(app.text(.paymentVerified), systemImage: "checkmark.circle.fill")
                .foregroundStyle(DaamTheme.primary)
              Button(app.text(.acceptLesson)) { model.transition(lesson, "accept") }
                .buttonStyle(DaamButtonStyle())
            } else if lesson.feeStatus == "SUBMITTED" {
              NoticeCard(title: .awaitingVerification, bodyKey: .verificationBody)
            } else {
              NoticeCard(title: .cliqTitle, bodyKey: .cliqBody)
              Button(app.text(.payAcceptanceFee)) {
                reference = ""
                payment = lesson
              }.buttonStyle(DaamButtonStyle())
            }
            Button(app.text(.declineLesson)) { model.transition(lesson, "decline") }
              .buttonStyle(DaamButtonStyle(outlined: true))
          }
          if ["PENDING", "ACCEPTED"].contains(lesson.status), lesson.startsAt > Date() {
            Button(app.text(.cancel), role: .destructive) { model.transition(lesson, "cancel") }
          }
          if profile.isTeacher && lesson.status == "ACCEPTED" && lesson.endsAt <= Date() {
            Button(app.text(.completeLesson)) { model.transition(lesson, "complete") }
          }
        }.padding().daamCard()
      }
      if model.more.contains("lessons") {
        Button(app.text(.loadMore)) { model.loadMore("lessons") }
      }
    }.navigationTitle(app.text(.bookings)).refreshable { model.run { try await model.refreshLessons() } }
      .sheet(item: $payment) { lesson in
        NavigationStack {
          Page {
            NoticeCard(title: .cliqTitle, bodyKey: .cliqBody, symbol: "creditcard.fill")
            Label(
              (model.feePolicy?.acceptanceFee ?? 1).formatted(
                .currency(code: model.feePolicy?.currency ?? "JOD")),
              systemImage: "banknote.fill")
              .font(.title2.bold()).foregroundStyle(DaamTheme.primary)
            Text(model.feePolicy?.cliqAlias ?? "").font(.title2.bold()).textSelection(.enabled)
            Field(
              title: app.text(.transferReference), placeholder: app.text(.referenceHint),
              text: $reference)
            Button(app.text(.submitTransfer)) {
              model.run {
                try await model.mutate(
                  "tutoring/lessons/\(lesson.id)/transfer", payload: ["reference": reference])
                try await model.load()
                payment = nil
              }
            }.buttonStyle(DaamButtonStyle()).disabled(
              reference.trimmingCharacters(in: .whitespaces).isEmpty || model.busy)
            if let error = model.error { Text(app.text(error)).foregroundStyle(.red) }
          }.toolbar { Button(app.text(.done)) { payment = nil } }
        }.environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
      }
  }
  private func directionsURL(for lesson: LiveLesson) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "maps.apple.com"
    components.queryItems = [
      URLQueryItem(name: "daddr", value: lesson.latitude.flatMap { latitude in
        lesson.longitude.map { "\(latitude),\($0)" }
      } ?? "\(lesson.address), \(app.text(JordanArea(rawValue: lesson.area)?.key ?? .location)), Jordan"),
      URLQueryItem(name: "dirflg", value: "d")
    ]
    return components.url
  }
}

private struct LessonMapLocation {
  let latitude: Double
  let longitude: Double
  let address: String
}

private struct LessonLocationPickerView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var camera: MapCameraPosition
  @State private var latitude: Double?
  @State private var longitude: Double?
  @State private var address = ""
  @State private var lookingUpAddress = false
  let onSelect: (LessonMapLocation) -> Void
  init(area: String, onSelect: @escaping (LessonMapLocation) -> Void) {
    self.onSelect = onSelect
    let center: CLLocationCoordinate2D
    switch area {
    case "jubeiha": center = CLLocationCoordinate2D(latitude: 32.03, longitude: 35.87)
    case "khalda": center = CLLocationCoordinate2D(latitude: 31.99, longitude: 35.84)
    case "shmeisani": center = CLLocationCoordinate2D(latitude: 31.96, longitude: 35.90)
    case "irbid": center = CLLocationCoordinate2D(latitude: 32.55, longitude: 35.85)
    case "zarqa": center = CLLocationCoordinate2D(latitude: 32.07, longitude: 36.09)
    case "balqa": center = CLLocationCoordinate2D(latitude: 32.03, longitude: 35.72)
    case "madaba": center = CLLocationCoordinate2D(latitude: 31.72, longitude: 35.80)
    case "jerash": center = CLLocationCoordinate2D(latitude: 32.28, longitude: 35.90)
    case "ajloun": center = CLLocationCoordinate2D(latitude: 32.33, longitude: 35.75)
    case "mafraq": center = CLLocationCoordinate2D(latitude: 32.34, longitude: 36.21)
    case "tafilah": center = CLLocationCoordinate2D(latitude: 30.83, longitude: 35.60)
    case "aqaba": center = CLLocationCoordinate2D(latitude: 29.53, longitude: 35.00)
    case "maan": center = CLLocationCoordinate2D(latitude: 30.20, longitude: 35.73)
    case "karak": center = CLLocationCoordinate2D(latitude: 31.18, longitude: 35.70)
    default: center = CLLocationCoordinate2D(latitude: 31.9539, longitude: 35.9106)
    }
    _camera = State(initialValue: .region(MKCoordinateRegion(
      center: center, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))))
  }
  private var coordinate: CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text(app.text(.tapMapToChoose)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        MapReader { proxy in
          Map(position: $camera) {
            if let coordinate {
              Annotation(app.text(.studentLocation), coordinate: coordinate) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 34))
                  .foregroundStyle(DaamTheme.primary).background(.white, in: Circle())
              }
            }
          }
          .onTapGesture(coordinateSpace: .local) { point in
            guard let coordinate = proxy.convert(point, from: .local) else { return }
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            lookingUpAddress = true
            Task { await lookupAddress(coordinate) }
          }
        }
        .frame(height: 440).clipShape(RoundedRectangle(cornerRadius: 22))
        if lookingUpAddress {
          Label(app.text(.findingAddress), systemImage: "location.magnifyingglass")
            .font(.subheadline).foregroundStyle(DaamTheme.secondary)
        } else if !address.isEmpty {
          Label(address, systemImage: "mappin.and.ellipse")
            .font(.subheadline).foregroundStyle(DaamTheme.primary).frame(maxWidth: .infinity, alignment: .leading)
        }
        Button {
          guard let latitude, let longitude, !address.isEmpty else { return }
          onSelect(LessonMapLocation(latitude: latitude, longitude: longitude, address: address))
          dismiss()
        } label: {
          Text(app.text(.confirmLocation)).frame(maxWidth: .infinity)
        }.buttonStyle(DaamButtonStyle()).disabled(coordinate == nil || address.isEmpty || lookingUpAddress)
      }.padding(18).background(Color("Canvas").ignoresSafeArea())
        .navigationTitle(app.text(.selectOnMap)).toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(app.text(.cancel)) { dismiss() }
          }
        }
    }
  }
  private func lookupAddress(_ coordinate: CLLocationCoordinate2D) async {
    defer { lookingUpAddress = false }
    let geocoder = CLGeocoder()
    do {
      let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
      let place = placemarks.first
      let parts = [place?.subThoroughfare, place?.thoroughfare, place?.subLocality, place?.locality]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
      address = parts.isEmpty
        ? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        : parts.joined(separator: ", ")
    } catch {
      address = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
  }
}

private struct StatusPill: View {
  let text: String
  let status: String
  private var color: Color {
    switch status {
    case "ACCEPTED": return DaamTheme.primary
    case "COMPLETED": return .blue
    case "CANCELLED", "DECLINED": return .red
    default: return .orange
    }
  }
  var body: some View {
    Text(text).font(.caption.weight(.semibold)).foregroundStyle(color)
      .padding(.horizontal, 11).padding(.vertical, 7)
      .background(color.opacity(0.1), in: Capsule())
  }
}

private struct NotificationSummaryBanner: View {
  @ObservedObject var model: TutoringViewModel
  let profile: LiveProfile
  @EnvironmentObject private var app: AppModel
  private var latest: LiveLesson? {
    model.lessons.first(where: { profile.isTeacher ? $0.status == "PENDING" : $0.status != "PENDING" })
      ?? model.lessons.first
  }
  var body: some View {
    NavigationLink {
      LiveNotificationsView(model: model, profile: profile)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(.blue)
          .frame(width: 42, height: 42).background(.white.opacity(0.85), in: Circle())
        VStack(alignment: .leading, spacing: 4) {
          Text(app.text(.notifications)).font(.subheadline.bold()).foregroundStyle(DaamTheme.text)
          Text(latest.map { notificationText(for: $0) } ?? app.text(.noNotifications))
            .font(.caption).foregroundStyle(DaamTheme.secondary).lineLimit(2)
        }
        Spacer(minLength: 4)
        if model.notificationCount(for: profile) > 0 {
          Text("\(model.notificationCount(for: profile))").font(.caption.bold())
            .foregroundStyle(.white).frame(minWidth: 23, minHeight: 23)
            .background(DaamTheme.primary, in: Circle())
        }
        Image(systemName: "chevron.forward").font(.caption.bold()).foregroundStyle(DaamTheme.secondary)
      }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Sky"), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.blue.opacity(0.18), lineWidth: 1))
    }.buttonStyle(.plain)
  }
  private func notificationText(for lesson: LiveLesson) -> String {
    let key: L10n
    if lesson.status == "PENDING" && lesson.feeStatus == "SUBMITTED" { key = .notificationTransferWaiting }
    else if lesson.status == "PENDING" && lesson.feeStatus == "APPROVED" { key = .notificationTransferVerified }
    else if lesson.status == "PENDING" && lesson.feeStatus == "REJECTED" { key = .notificationTransferRejected }
    else if lesson.status == "PENDING" { key = profile.isTeacher ? .notificationNewRequest : .notificationRequestPending }
    else if lesson.status == "ACCEPTED" { key = .notificationLessonAccepted }
    else if lesson.status == "DECLINED" { key = .notificationLessonDeclined }
    else if lesson.status == "CANCELLED" { key = .notificationLessonCancelled }
    else { key = .notificationLessonCompleted }
    return app.text(key)
  }
}

private struct LiveNotificationsView: View {
  @ObservedObject var model: TutoringViewModel
  let profile: LiveProfile
  @EnvironmentObject private var app: AppModel
  var body: some View {
    Page {
      if model.lessons.isEmpty {
        EmptyState(title: .notifications, message: .noNotifications)
      }
      ForEach(model.lessons) { lesson in
        let key = notificationKey(for: lesson)
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: notificationSymbol(for: lesson))
            .font(.title3).foregroundStyle(notificationColor(for: lesson))
            .frame(width: 42, height: 42).background(Color("Mint"), in: Circle())
          VStack(alignment: .leading, spacing: 6) {
            Text(app.text(key)).font(.subheadline.bold())
            Text(profile.isTeacher ? lesson.parentName : lesson.teacherName)
              .font(.caption).foregroundStyle(DaamTheme.secondary)
            Text(lesson.startsAt.formatted(date: .abbreviated, time: .shortened))
              .font(.caption).foregroundStyle(DaamTheme.secondary)
            if profile.isTeacher && lesson.status == "PENDING" {
              NavigationLink(app.text(.bookings)) {
                LiveLessonsView(model: model, profile: profile)
              }.font(.caption.weight(.semibold)).foregroundStyle(DaamTheme.primary)
            }
          }
          Spacer(minLength: 0)
          StatusPill(text: app.text(L10n(rawValue: lesson.status.lowercased()) ?? .pending), status: lesson.status)
        }.padding(15).daamCard(radius: 18)
      }
      if model.more.contains("lessons") {
        Button(app.text(.loadMore)) { model.loadMore("lessons") }
      }
    }.navigationTitle(app.text(.notifications)).refreshable { model.run { try await model.refreshLessons() } }
  }
  private func notificationKey(for lesson: LiveLesson) -> L10n {
    if lesson.status == "PENDING" && lesson.feeStatus == "SUBMITTED" { return .notificationTransferWaiting }
    if lesson.status == "PENDING" && lesson.feeStatus == "APPROVED" { return .notificationTransferVerified }
    if lesson.status == "PENDING" && lesson.feeStatus == "REJECTED" { return .notificationTransferRejected }
    switch lesson.status {
    case "PENDING": return profile.isTeacher ? .notificationNewRequest : .notificationRequestPending
    case "ACCEPTED": return .notificationLessonAccepted
    case "DECLINED": return .notificationLessonDeclined
    case "CANCELLED": return .notificationLessonCancelled
    default: return .notificationLessonCompleted
    }
  }
  private func notificationSymbol(for lesson: LiveLesson) -> String {
    switch lesson.status {
    case "ACCEPTED": return "checkmark.circle.fill"
    case "DECLINED", "CANCELLED": return "xmark.circle.fill"
    case "COMPLETED": return "checkmark.seal.fill"
    default: return profile.isTeacher ? "book.badge.plus" : "clock.fill"
    }
  }
  private func notificationColor(for lesson: LiveLesson) -> Color {
    lesson.status == "DECLINED" || lesson.status == "CANCELLED" ? .red : DaamTheme.primary
  }
}

struct LiveAccountView: View {
  @ObservedObject var model: TutoringViewModel
  let account: AccountProfile
  let signOut: () -> Void
  @EnvironmentObject private var app: AppModel
  var body: some View {
    Page {
      HStack(spacing: 14) {
        Image(systemName: "person.crop.circle.fill").font(.system(size: 42))
          .foregroundStyle(DaamTheme.primary)
        VStack(alignment: .leading, spacing: 4) {
          Text(account.displayName).font(.headline)
          Text(app.text(model.profile?.isTeacher == true ? .teacher : .parent))
            .font(.subheadline).foregroundStyle(DaamTheme.secondary)
        }
      }.padding(16).frame(maxWidth: .infinity, alignment: .leading).daamCard(radius: 20)
      Picker(app.text(.language), selection: $app.language) {
        Text(app.text(.arabic)).tag(AppLanguage.arabic)
        Text(app.text(.englishLanguage)).tag(AppLanguage.english)
      }.pickerStyle(.segmented)
      NavigationLink {
        AccountDetailsView(model: model, account: account)
      } label: {
        accountRow(.profile, symbol: "person.text.rectangle")
      }.buttonStyle(.plain)
      Button(app.text(.signOut), action: signOut).buttonStyle(DaamButtonStyle(outlined: true))
    }.navigationTitle(app.text(.account))
  }
  private func accountRow(_ title: L10n, symbol: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: symbol).foregroundStyle(DaamTheme.primary).frame(width: 28)
      Text(app.text(title)).font(.subheadline.weight(.semibold))
      Spacer()
      Image(systemName: "chevron.forward").font(.caption.bold()).foregroundStyle(DaamTheme.secondary)
    }.padding(16).daamCard(radius: 16)
  }
}

struct AccountDetailsView: View {
  @ObservedObject var model: TutoringViewModel
  let account: AccountProfile
  @EnvironmentObject private var app: AppModel
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var phone = ""
  var body: some View {
    Page {
      Field(title: app.text(.firstName), placeholder: app.text(.firstName), text: $firstName)
      Field(title: app.text(.lastName), placeholder: app.text(.lastName), text: $lastName)
      Field(title: app.text(.phoneNumber), placeholder: app.text(.phoneNumber), text: $phone, keyboard: .phonePad)
      Button(app.text(.save)) {
        model.run {
          try await model.mutate(
            "users/me", method: "PUT",
            payload: AccountUpdate(firstName: firstName, lastName: lastName, phoneNumber: phone.isEmpty ? nil : phone))
          try await model.load()
        }
      }.buttonStyle(DaamButtonStyle())
      NavigationLink(app.text(.profile)) { LiveProfileForm(model: model) }
        .buttonStyle(DaamButtonStyle(outlined: true))
    }.navigationTitle(app.text(.profile)).task {
      firstName = account.firstName
      lastName = account.lastName
      phone = account.phoneNumber ?? ""
      model.run {
        let latest: AccountProfile? = try await model.service.api("users/me")
        if let latest {
          firstName = latest.firstName
          lastName = latest.lastName
          phone = latest.phoneNumber ?? ""
        }
      }
    }
  }
}

private enum MessageFolder: String, CaseIterable {
  case inbox, new, sent
}

struct LiveMessagesView: View {
  @ObservedObject var model: TutoringViewModel
  @EnvironmentObject private var app: AppModel
  @State private var message = ""
  @State private var folder = MessageFolder.inbox

  var body: some View {
    Page {
      Picker(app.text(.messages), selection: $folder) {
        Text(app.text(.inbox)).tag(MessageFolder.inbox)
        Text(app.text(.newMessage)).tag(MessageFolder.new)
        Text(app.text(.sent)).tag(MessageFolder.sent)
      }
      .pickerStyle(.segmented)

      switch folder {
      case .inbox:
        inbox
      case .new:
        compose
      case .sent:
        sent
      }
    }
    .navigationTitle(app.text(.messages))
    .task { model.run { try await model.refreshSupport() } }
    .refreshable { model.run { try await model.refreshSupport() } }
  }

  @ViewBuilder private var inbox: some View {
    let replies = model.support.filter { $0.reply != nil }
    if replies.isEmpty {
      EmptyState(title: .inbox, message: .noInboxMessages)
    } else {
      ForEach(replies) { ticket in
        VStack(alignment: .leading, spacing: 10) {
          Label(app.text(.supportAnswered), systemImage: "bubble.left.and.bubble.right.fill")
            .font(.caption.weight(.semibold)).foregroundStyle(DaamTheme.primary)
          Text(ticket.reply ?? "").font(.body)
          Text(ticket.message).font(.caption).foregroundStyle(DaamTheme.secondary)
          Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
            .font(.caption2).foregroundStyle(DaamTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(Color("Sky"), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.blue.opacity(0.16), lineWidth: 1))
      }
    }
  }

  private var compose: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(app.text(.supportIntro)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
      Label(app.text(.supportRecipient), systemImage: "paperplane.fill")
        .font(.caption.weight(.semibold)).foregroundStyle(DaamTheme.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
      TextEditor(text: $message)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 150)
        .padding(10)
        .background(Color("Canvas"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DaamTheme.primary.opacity(0.16), lineWidth: 1))
        .overlay(alignment: .topLeading) {
          if message.isEmpty {
            Text(app.text(.messageText))
              .font(.body)
              .foregroundStyle(DaamTheme.secondary.opacity(0.72))
              .padding(.horizontal, 16)
              .padding(.vertical, 18)
              .allowsHitTesting(false)
          }
        }
      Button {
        let outgoing = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }
        model.run {
          let _: UUID? = try await model.service.api(
            "tutoring/support", method: "POST",
            body: JSONEncoder().encode(["message": outgoing]))
          message = ""
          try await model.refreshSupport()
          folder = .sent
          model.error = nil
        }
      } label: {
        Label(app.text(.sendMessage), systemImage: "paperplane.fill")
      }
      .buttonStyle(DaamButtonStyle())
      .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(DaamTheme.primary.opacity(0.14), lineWidth: 1))
  }

  @ViewBuilder private var sent: some View {
    if model.support.isEmpty {
      EmptyState(title: .sent, message: .noSentMessages)
    } else {
      ForEach(model.support) { ticket in
        VStack(alignment: .leading, spacing: 9) {
          HStack {
            Text(ticket.status == "ANSWERED" ? app.text(.supportAnswered) : app.text(.supportPending))
              .font(.caption.weight(.semibold)).foregroundStyle(DaamTheme.primary)
            Spacer()
            Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
              .font(.caption2).foregroundStyle(DaamTheme.secondary)
          }
          Text(ticket.message).font(.body)
          if let reply = ticket.reply {
            Divider()
            Text(reply).font(.subheadline).foregroundStyle(DaamTheme.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).daamCard(radius: 18)
      }
    }
  }
}
