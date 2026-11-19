import SwiftUI

struct PublicTeacher: Decodable, Identifiable {
  let id: UUID
  let displayName: String
  let bio: String
  let hourlyRate: Decimal
  let subjects: [String]
  let teachingAreas: [String]
}

struct PublicTeacherDashboard: View {
  let isAuthenticated: Bool
  let sessionReady: Bool
  let authenticate: () -> Void
  @EnvironmentObject private var app: AppModel
  @State private var area: JordanArea = .amman
  @State private var subject = ""
  @State private var teachers: [PublicTeacher] = []
  @State private var loading = false
  @State private var failed = false
  @State private var page = 0
  @State private var hasMore = false
  @State private var selected: PublicTeacher?
  private var filterID: String { area.rawValue + subject }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          BrandHeader()
          Button(app.language == .arabic ? "EN" : "العربية") {
            app.language = app.language == .arabic ? .english : .arabic
          }.font(.subheadline.bold()).padding(12).background(.white, in: Capsule())
        }
        hero
        HStack(spacing: 12) {
          benefit(.cashBadge, "banknote")
          benefit(.flexibleTimes, "calendar")
        }
        VStack(alignment: .leading, spacing: 16) {
          Text(app.text(.findYourTeacher)).font(.title2.bold())
          HStack {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(DaamTheme.primary)
            Picker(app.text(.location), selection: $area) {
              ForEach(JordanArea.allCases) { Text(app.text($0.key)).tag($0) }
            }.tint(DaamTheme.text)
            Spacer()
          }.padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(["", "math", "english", "science"], id: \.self) { value in
                Button {
                  subject = value
                } label: {
                  Text(app.text(value.isEmpty ? .all : L10n(rawValue: value)!))
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 18).padding(
                      .vertical, 11
                    )
                    .foregroundStyle(subject == value ? .white : DaamTheme.text)
                    .background(subject == value ? DaamTheme.primary : .white, in: Capsule())
                }.buttonStyle(.plain)
              }
            }
          }
        }
        if loading && teachers.isEmpty {
          ProgressView().frame(maxWidth: .infinity).padding(40)
        } else if failed {
          VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(
              DaamTheme.primary)
            Text(app.text(.directoryUnavailable)).multilineTextAlignment(.center)
            Button(app.text(.retry)) { Task { await load(reset: true) } }
          }.padding(30).frame(maxWidth: .infinity).daamCard(radius: 24)
        } else if teachers.isEmpty {
          VStack(spacing: 14) {
            Image(systemName: "books.vertical").font(.system(size: 38)).foregroundStyle(
              DaamTheme.primary)
            Text(app.text(.teachersComingSoon)).font(.headline)
            Text(app.text(.directoryEmptyBody)).font(.subheadline).foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            if sessionReady && !isAuthenticated {
              Button(app.text(.joinDaam), action: authenticate).buttonStyle(DaamButtonStyle(outlined: true))
            }
          }.padding(28).frame(maxWidth: .infinity).daamCard(radius: 24)
        }
        ForEach(teachers) { teacher in
          Button {
            selected = teacher
          } label: {
            TeacherDiscoveryCard(teacher: teacher)
          }.buttonStyle(.plain)
        }
        if hasMore {
          Button(app.text(.loadMore)) { Task { await load(reset: false) } }.disabled(loading)
        }
      }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity)
    }
    .background(Color("Canvas").ignoresSafeArea())
    .safeAreaInset(edge: .bottom) {
      if sessionReady {
      VStack(spacing: 8) {
        Button(action: authenticate) {
          HStack {
            Text(app.text(isAuthenticated ? .account : .registerOrLogin))
            Spacer()
            Image(systemName: "arrow.forward")
          }
        }.buttonStyle(DaamButtonStyle())
        if !isAuthenticated { Text(app.text(.browseFreely)).font(.caption).foregroundStyle(.secondary) }
      }.padding(.horizontal, 22).padding(.vertical, 12).background(.regularMaterial)
      }
    }
    .task(id: filterID) { await load(reset: true) }
    .sheet(item: $selected) { teacher in
      NavigationStack {
        Page {
          TeacherDiscoveryCard(teacher: teacher)
          Text(app.text(.about)).font(.title2.bold())
          Text(teacher.bio).lineSpacing(5)
          NoticeCard(title: .noBookingFee, bodyKey: .cashPolicy)
          Button(app.text(isAuthenticated ? .account : .registerOrLogin)) {
            selected = nil
            authenticate()
          }.buttonStyle(DaamButtonStyle())
        }.toolbar { Button(app.text(.done)) { selected = nil } }
      }.environment(\.layoutDirection, app.language == .arabic ? .rightToLeft : .leftToRight)
    }
  }
  private var hero: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(app.text(.learningStartsHere), systemImage: "sparkle").font(.caption.weight(.bold))
        .foregroundStyle(DaamTheme.primary)
      Text(app.text(.discoveryHeadline)).font(.system(.title, design: .rounded, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)
      Text(app.text(.discoverySubtitle)).font(.subheadline).foregroundStyle(DaamTheme.secondary)
        .lineSpacing(4)
      HStack {
        Label(app.text(.localTeachers), systemImage: "mappin.circle.fill")
        Spacer()
        Image(systemName: "book.pages.fill").font(.system(size: 42, weight: .light))
          .foregroundStyle(DaamTheme.primary.opacity(0.65))
      }.font(.caption.weight(.semibold))
    }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(DaamTheme.text)
      .background(Color("Mint"), in: RoundedRectangle(cornerRadius: 24))
      .overlay(RoundedRectangle(cornerRadius: 24).stroke(DaamTheme.primary.opacity(0.08), lineWidth: 1))
  }
  private func benefit(_ title: L10n, _ symbol: String) -> some View {
    Label(app.text(title), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(
      DaamTheme.primary
    )
    .frame(maxWidth: .infinity).padding(.vertical, 16).background(
      Color("Mint"), in: RoundedRectangle(cornerRadius: 16))
  }
  @MainActor private func load(reset: Bool) async {
    guard let configuration = BackendConfiguration.configured else {
      failed = true
      return
    }
    let requestedFilter = filterID
    let requestedPage = reset ? 0 : page + 1
    if reset { teachers = [] }
    loading = true
    failed = false
    defer { if requestedFilter == filterID { loading = false } }
    do {
      let service = AuthenticationService(configuration: configuration)
      let rows: [PublicTeacher] =
        try await service.api(
          "public/teachers?area=\(area.rawValue)&subject=\(subject)&page=\(requestedPage)",
          authenticated: false) ?? []
      guard !Task.isCancelled, requestedFilter == filterID else { return }
      teachers = reset ? rows : teachers + rows
      page = requestedPage
      hasMore = rows.count == 30
    } catch {
      guard !Task.isCancelled, requestedFilter == filterID else { return }
      failed = true
    }
  }
}

struct TeacherDiscoveryCard: View {
  let teacher: PublicTeacher
  @EnvironmentObject private var app: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 14) {
        TeacherProfileAvatar(teacherID: teacher.id, name: teacher.displayName, size: 58)
        VStack(alignment: .leading, spacing: 6) {
          Text(teacher.displayName).font(.headline)
        }
        Spacer()
      }
      Text(
        teacher.subjects.map { app.text(L10n(rawValue: $0) ?? .lesson) }.joined(separator: " • ")
      ).font(.subheadline.weight(.semibold))
      Text(teacher.bio).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
      Label(areaSummary, systemImage: "mappin")
        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      Divider()
      HStack {
        Text(L10n.perHour.format(
          app.language, teacher.hourlyRate.formatted(.currency(code: "JOD"))))
          .font(.title3.bold()).foregroundStyle(DaamTheme.primary)
        Spacer()
        Label(app.text(.viewTeacher), systemImage: "arrow.forward").font(.subheadline.bold())
      }
    }.padding(18).daamCard(radius: 20)
  }
  private var areaSummary: String {
    var seen = Set<String>()
    let names = teacher.teachingAreas.filter { seen.insert($0).inserted }
      .map { app.text(JordanArea(rawValue: $0)?.key ?? .location) }
    let visible = names.prefix(2).joined(separator: "، ")
    let remaining = max(0, names.count - 2)
    return remaining == 0 ? visible : "\(visible) +\(remaining)"
  }
}
