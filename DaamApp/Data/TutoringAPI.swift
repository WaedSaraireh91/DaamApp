import Combine
import Foundation

struct LiveProfile: Codable, Identifiable {
  let userId: UUID
  let displayName: String
  let kind: String
  let area: String
  let bio: String
  let hourlyRate: Decimal?
  let subjects: [String]
  let teachingAreas: [String]
  let approved: Bool
  let certificateUploaded: Bool?
  let profilePhotoUploaded: Bool?
  var id: UUID { userId }
  var isTeacher: Bool { kind == "TEACHER" }
}
struct LiveProfileInput: Encodable {
  let kind: String
  let area: String
  let bio: String
  let hourlyRate: Decimal?
  let subjects: [String]
  let teachingAreas: [String]
  let declarationAccepted: Bool
}
struct LiveSlot: Decodable, Identifiable {
  let id: UUID
  let teacherId: UUID
  let startsAt: Date
  let endsAt: Date
}
struct LiveLesson: Decodable, Identifiable {
  let id: UUID
  let parentId: UUID
  let teacherId: UUID
  let parentName: String
  let teacherName: String
  let startsAt: Date
  let endsAt: Date
  let area: String
  let address: String
  let subject: String
  let studentName: String
  let hourlyRate: Decimal
  let total: Decimal
  let status: String
  let fee: Decimal
  let feeStatus: String
  let transferReference: String?
  let latitude: Double?
  let longitude: Double?
}
struct LiveFeePolicy: Decodable {
  let firstFreeAvailable: Bool
  let acceptanceFee: Decimal
  let currency: String
  let cliqAlias: String
}
struct LiveSupport: Decodable, Identifiable {
  let id: UUID
  let message: String
  let reply: String?
  let status: String
  let createdAt: Date
}
struct AccountUpdate: Encodable {
  let firstName: String
  let lastName: String
  let phoneNumber: String?
}
struct BookingPayload: Encodable {
  let slotId: UUID
  let area: String
  let address: String
  let subject: String
  let studentName: String
  let latitude: Double?
  let longitude: Double?
}

@MainActor
final class TutoringViewModel: ObservableObject {
  let service: AuthenticationService
  @Published var profile: LiveProfile?
  @Published var favoriteTeachers: [LiveProfile] = []
  private var pages: [String: Int] = [:]
  @Published var more: Set<String> = []
  @Published var teachers: [LiveProfile] = []
  @Published var lessons: [LiveLesson] = []
  @Published var favorites: Set<UUID> = []
  @Published var support: [LiveSupport] = []
  @Published var feePolicy: LiveFeePolicy?
  @Published var busy = false
  @Published var loaded = false
  @Published var error: L10n?
  init(service: AuthenticationService) { self.service = service }
  func notificationCount(for profile: LiveProfile) -> Int {
    lessons.filter { lesson in
      if profile.isTeacher {
        return lesson.status == "PENDING" || lesson.feeStatus == "SUBMITTED" || lesson.feeStatus == "REJECTED"
      }
      return lesson.status == "PENDING" || lesson.feeStatus == "SUBMITTED"
        || lesson.feeStatus == "APPROVED" || lesson.feeStatus == "REJECTED"
    }.count
  }
  func load() async throws {
    profile = try await service.api("tutoring/profile")
    loaded = true
    guard let profile else { return }
    pages = [:]
    more = []
    lessons = try await service.api("tutoring/lessons") ?? []
    if lessons.count == 30 { more.insert("lessons") }
    support = try await service.api("tutoring/support") ?? []
    if support.count == 30 { more.insert("support") }
    if profile.isTeacher { feePolicy = try await service.api("tutoring/fee-policy") }
    if !profile.isTeacher {
      let ids: [UUID] = try await service.api("tutoring/favorites") ?? []
      favorites = Set(ids)
      // Query values come from the closed JordanArea catalog.
      teachers = try await service.api("tutoring/teachers?area=" + profile.area) ?? []
      favoriteTeachers = try await service.api("tutoring/favorites/teachers") ?? []
      if teachers.count == 30 { more.insert("teachers") }
      if favoriteTeachers.count == 30 { more.insert("favorites") }
    }
  }
  func refreshLessons() async throws {
    let refreshed: [LiveLesson] = try await service.api("tutoring/lessons") ?? []
    let refreshedIDs = Set(refreshed.map(\.id))
    lessons = refreshed + lessons.filter { !refreshedIDs.contains($0.id) }
    if refreshed.count < 30 { more.remove("lessons") } else { more.insert("lessons") }
  }
  func refreshSupport() async throws {
    let refreshed: [LiveSupport] = try await service.api("tutoring/support") ?? []
    support = refreshed
    if refreshed.count < 30 { more.remove("support") } else { more.insert("support") }
  }
  func loadMore(_ section: String) {
    run {
      let page = (self.pages[section] ?? 0) + 1
      var count = 0
      switch section {
      case "teachers", "favorites":
        let path =
          section == "teachers"
          ? "teachers?area=\(self.profile?.area ?? "amman")&" : "favorites/teachers?"
        let rows: [LiveProfile] =
          try await self.service.api("tutoring/" + path + "page=\(page)") ?? []
        if section == "teachers" { self.teachers += rows } else { self.favoriteTeachers += rows }
        count = rows.count
      case "lessons":
        let rows: [LiveLesson] = try await self.service.api("tutoring/lessons?page=\(page)") ?? []
        self.lessons += rows
        count = rows.count
      case "support":
        let rows: [LiveSupport] = try await self.service.api("tutoring/support?page=\(page)") ?? []
        self.support += rows
        count = rows.count
      default: return
      }
      self.pages[section] = page
      if count < 30 { self.more.remove(section) }
    }
  }
  func run(_ action: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do { try await action() } catch AuthenticationError.server(let code) {
        self.error = Self.message(code)
      } catch { self.error = .authTryAgain }
    }
  }
  func mutate<T: Encodable>(_ path: String, method: String = "POST", payload: T) async throws {
    let _: EmptyResponse? = try await service.api(
      path, method: method, body: JSONEncoder().encode(payload))
  }
  func transition(_ lesson: LiveLesson, _ action: String) {
    run {
      try await self.mutate("tutoring/lessons/\(lesson.id)/\(action)", payload: [String: String]())
      try await self.load()
    }
  }
  func favorite(_ teacher: LiveProfile) {
    run {
      try await self.mutate(
        "tutoring/favorites/\(teacher.id)",
        method: self.favorites.contains(teacher.id) ? "DELETE" : "PUT", payload: [String: String]())
      try await self.load()
    }
  }
  static func message(_ code: String) -> L10n {
    switch code {
    case "INVALID_PERSON_NAME": return .invalidPersonName
    case "INVALID_PHONE": return .invalidPhone
    case "INVALID_PHONE_CODE": return .invalidPhoneCode
    case "PHONE_COOLDOWN": return .phoneCooldown
    case "PHONE_ALREADY_REGISTERED": return .phoneAlreadyRegistered
    case "PHONE_REGISTRATION_REQUIRED": return .phoneRegistrationRequired
    case "PAYMENT_REQUIRED": return .paymentRequired
    case "CERTIFICATE_REQUIRED", "INVALID_CERTIFICATE": return .certificateError
    case "INVALID_PROFILE_PHOTO": return .profilePhotoError
    case "TIME_UNAVAILABLE", "DUPLICATE_BOOKING": return .timeUnavailable
    case "TEACHER_NOT_APPROVED", "TEACHER_UNAVAILABLE": return .teacherReviewPending
    case "DUPLICATE_REFERENCE": return .duplicateReference
    case "INVALID_CREDENTIALS": return .authRejected
    case "EMAIL_NOT_VERIFIED": return .verificationInstructions
    case "EMAIL_ALREADY_EXISTS", "USER_ALREADY_EXISTS": return .emailAlreadyUsed
    case "INVALID_TOKEN", "TOKEN_EXPIRED": return .linkExpired
    case "VALIDATION_FAILED", "VALIDATION_ERROR", "INVALID_SLOT", "TEACHER_DETAILS_REQUIRED",
      "INVALID_AREA", "INVALID_SUBJECT", "INVALID_LOCATION":
      return .checkDetails
    default: return .authTryAgain
    }
  }
}
