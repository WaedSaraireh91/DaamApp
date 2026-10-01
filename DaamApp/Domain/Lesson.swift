import Foundation

enum AccountRole: String, Codable { case parent, teacher }
enum LessonStatus: String, Codable { case pending, accepted, declined }

struct Lesson: Identifiable, Codable, Equatable {
    let id: UUID
    let teacherID: String
    let student: String
    let grade: Int
    let date: Date
    let address: String
    let notes: String
    let price: Int
    var status: LessonStatus = .pending
    var acceptanceFee: Int?
    var area: JordanArea?
}

struct BookingDraft {
    var student = ""
    var grade = 6
    var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var address = ""
    var notes = ""
    func validate(now: Date = Date()) throws {
        guard !student.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8,
              date > now else { throw LessonError.invalidBooking }
    }
}

enum LessonError: Error, Equatable { case invalidBooking, alreadyHandled, timeUnavailable, storage, paymentRequired }

/// First acceptance is free for each teacher, not for each student or session.
struct AcceptancePolicy {
    func fee(previousAcceptances: Int) -> Int { previousAcceptances == 0 ? 0 : 1 }
    func accept(_ lesson: Lesson, previousAcceptances: Int, paymentVerified: Bool = false) throws -> Lesson {
        guard lesson.status == .pending else { throw LessonError.alreadyHandled }
        guard fee(previousAcceptances: previousAcceptances) == 0 || paymentVerified else { throw LessonError.paymentRequired }
        var accepted = lesson
        accepted.status = .accepted
        accepted.acceptanceFee = fee(previousAcceptances: previousAcceptances)
        return accepted
    }
}

enum TransferStatus: String, Codable { case submitted, verified, rejected }
struct AcceptanceTransfer: Codable {
    let reference: String
    let recipientAlias: String
    let amount: Int
    var status: TransferStatus = .submitted
}

struct DemoSnapshot: Codable {
    var lessons: [Lesson] = []
    var favoriteTeacherIDs: Set<String> = []
    var hourlyRates: [String: Int] = [:]
    var transfers: [String: AcceptanceTransfer] = [:]
    var teacherProfiles: [String: TeacherRegistration] = [:]
    var parentRegistration: ParentRegistration?
    init(lessons: [Lesson] = []) { self.lessons = lessons }
    private enum CodingKeys: String, CodingKey { case lessons, favoriteTeacherIDs, hourlyRates, transfers, teacherProfiles, parentRegistration }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessons = try c.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        favoriteTeacherIDs = try c.decodeIfPresent(Set<String>.self, forKey: .favoriteTeacherIDs) ?? []
        hourlyRates = try c.decodeIfPresent([String: Int].self, forKey: .hourlyRates) ?? [:]
        teacherProfiles = try c.decodeIfPresent([String: TeacherRegistration].self, forKey: .teacherProfiles) ?? [:]
        parentRegistration = try c.decodeIfPresent(ParentRegistration.self, forKey: .parentRegistration)
        transfers = try c.decodeIfPresent([String: AcceptanceTransfer].self, forKey: .transfers) ?? [:]
    }
}

/// Supplied by the service owner; never invent a real payment destination.
struct PaymentConfiguration {
    let recipientName: String?
    let cliqAlias: String?
    static let unconfigured = PaymentConfiguration(recipientName: nil, cliqAlias: nil)
    var isConfigured: Bool { !(recipientName ?? "").isEmpty && !(cliqAlias ?? "").isEmpty }
}

protocol LessonRepository {
    func load() throws -> DemoSnapshot?
    func save(_ snapshot: DemoSnapshot) throws
}

/// Stable area IDs drive matching independently of the display language.
enum JordanArea: String, Codable, CaseIterable, Identifiable {
    case jubeiha, khalda, shmeisani, amman, irbid, zarqa, balqa, madaba, jerash, ajloun, mafraq, karak, tafilah, maan, aqaba
    var id: String { rawValue }
    var key: L10n { L10n(rawValue: "area_" + rawValue)! }
}
struct DeclarationRecord: Codable {
    let acceptedAt: Date
    let version: String
    let language: String
}
struct TeacherRegistration: Codable {
    let bio: String
    let areas: Set<JordanArea>
    let certificateFile: String
    let declaration: DeclarationRecord
}
struct ParentRegistration: Codable {
    let area: JordanArea
    let declaration: DeclarationRecord
}
