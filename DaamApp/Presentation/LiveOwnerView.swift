import QuickLook
import SwiftUI

/// Owner controls use server-enforced ADMIN authorization.
struct LiveOwnerView: View {
  let service: AuthenticationService
  let signOut: () -> Void
  @EnvironmentObject private var app: AppModel
  @State private var teachers: [LiveProfile] = []
  @State private var transfers: [LiveLesson] = []
  @State private var tickets: [LiveSupport] = []
  @State private var replies: [UUID: String] = [:]
  @State private var pages: [String: Int] = [:]
  @State private var more: Set<String> = []
  @State private var busy = false
  @State private var error: L10n?
  @State private var certificateURL: URL?
  @State private var openedFiles: [URL] = []
  var body: some View {
    NavigationStack {
      Page {
        BrandHeader()
        Text(app.text(.teacherReviewPending)).font(.title2.bold())
        ForEach(teachers) { teacher in
          VStack(alignment: .leading, spacing: 12) {
            Text(teacher.displayName).font(.headline)
            Text(teacher.bio)
            Button(app.text(.privateCertificate)) {
              run {
                let url = try await service.certificate(teacherID: teacher.id)
                openedFiles.append(url)
                certificateURL = url
              }
            }
            HStack {
              Button(app.text(.approveTeacher)) { reviewTeacher(teacher, true) }
              Button(app.text(.declineLesson)) { reviewTeacher(teacher, false) }
            }
          }.padding().daamCard()
        }
        if more.contains("teachers") { Button(app.text(.loadMore)) { nextPage("teachers") } }
        Text(app.text(.ownerReview)).font(.title2.bold())
        ForEach(transfers) { lesson in
          VStack(alignment: .leading, spacing: 12) {
            Text(lesson.teacherName).font(.headline)
            Text(lesson.transferReference ?? "").textSelection(.enabled)
            Text(lesson.fee.formatted(.currency(code: "JOD")))
            Text(app.text(.approveTransferMessage)).font(.footnote)
            HStack {
              Button(app.text(.approveTransfer)) { reviewTransfer(lesson, true) }
              Button(app.text(.rejectTransfer)) { reviewTransfer(lesson, false) }
            }
          }.padding().daamCard()
        }
        if more.contains("payments") { Button(app.text(.loadMore)) { nextPage("payments") } }
        Text(app.text(.supportTitle)).font(.title2.bold())
        ForEach(tickets) { ticket in
          VStack(alignment: .leading, spacing: 12) {
            Text(ticket.message)
            if let reply = ticket.reply { Text(reply).foregroundStyle(.secondary) }
            Field(
              title: app.text(.replyTitle), placeholder: app.text(.replyTitle),
              text: Binding(get: { replies[ticket.id] ?? "" }, set: { replies[ticket.id] = $0 }))
            Button(app.text(.sendMessage)) {
              run {
                let _: EmptyResponse? = try await service.api(
                  "admin/tutoring/support/\(ticket.id)/reply", method: "PUT",
                  body: JSONEncoder().encode(["message": replies[ticket.id] ?? ""]))
                replies[ticket.id] = nil
                try await load()
              }
            }.disabled((replies[ticket.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
          }.padding().daamCard()
        }
        if more.contains("support") { Button(app.text(.loadMore)) { nextPage("support") } }
        Button(app.text(.signOut), action: signOut)
        if busy { ProgressView() }
        if let error { Text(app.text(error)).foregroundStyle(.red) }
      }.navigationTitle(app.text(.ownerReview)).disabled(busy)
        .refreshable { run { try await load() } }
    }
    .quickLookPreview($certificateURL)
    .onDisappear { for url in openedFiles { try? FileManager.default.removeItem(at: url) } }
    .task { run { try await load() } }
  }
  private func run(_ action: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }
    busy = true
    error = nil
    Task { @MainActor in
      defer { busy = false }
      do { try await action() } catch { self.error = .authTryAgain }
    }
  }
  private func load() async throws {
    pages = [:]
    more = []
    teachers = try await service.api("admin/tutoring/teachers") ?? []
    transfers = try await service.api("admin/tutoring/payments") ?? []
    tickets = try await service.api("admin/tutoring/support") ?? []
    if teachers.count == 30 { more.insert("teachers") }
    if transfers.count == 30 { more.insert("payments") }
    if tickets.count == 30 { more.insert("support") }
  }
  private func nextPage(_ section: String) {
    run {
      let page = (pages[section] ?? 0) + 1
      var count = 0
      switch section {
      case "teachers":
        let rows: [LiveProfile] =
          try await service.api("admin/tutoring/teachers?page=\(page)") ?? []
        teachers += rows
        count = rows.count
      case "payments":
        let rows: [LiveLesson] = try await service.api("admin/tutoring/payments?page=\(page)") ?? []
        transfers += rows
        count = rows.count
      default:
        let rows: [LiveSupport] = try await service.api("admin/tutoring/support?page=\(page)") ?? []
        tickets += rows
        count = rows.count
      }
      pages[section] = page
      if count < 30 { more.remove(section) }
    }
  }
  private func reviewTeacher(_ teacher: LiveProfile, _ approved: Bool) {
    run {
      let _: EmptyResponse? = try await service.api(
        "admin/tutoring/teachers/\(teacher.id)/review", method: "PUT",
        body: JSONEncoder().encode(["approved": approved]))
      try await load()
    }
  }
  private func reviewTransfer(_ lesson: LiveLesson, _ approved: Bool) {
    run {
      let _: EmptyResponse? = try await service.api(
        "admin/tutoring/payments/\(lesson.id)/review", method: "PUT",
        body: JSONEncoder().encode(["approved": approved]))
      try await load()
    }
  }
}
