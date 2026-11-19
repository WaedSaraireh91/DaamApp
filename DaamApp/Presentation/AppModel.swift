import Foundation
import Combine

enum AppTab: Hashable { case home, bookings, favorites, account, requests, schedule }

@MainActor
final class AppModel: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "daam.language") }
    }
    @Published var role: AccountRole?
    @Published var parentTab: AppTab = .home
    @Published var teacherTab: AppTab = .home
    @Published var selectedTeacherID = "ahmad"
    @Published private(set) var snapshot = DemoSnapshot()
    @Published var error: L10n?
    let teachers: [Teacher] = MockTutoringRepository.fixtures
    private let repository: any LessonRepository
    private let defaults: UserDefaults
    private let policy = AcceptancePolicy()
    let paymentConfiguration: PaymentConfiguration

    init(repository: any LessonRepository, defaults: UserDefaults = .standard, paymentConfiguration: PaymentConfiguration = .unconfigured) {
        self.paymentConfiguration = paymentConfiguration
        self.repository = repository
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "daam.language") ?? "ar") ?? .arabic
        do {
            if let saved = try repository.load() { snapshot = saved }
            else {
                snapshot = DemoSnapshot(lessons: Self.sampleRequests())
                try repository.save(snapshot)
            }
        } catch { self.error = .storageError }
    }
    func text(_ key: L10n) -> String { key.text(language) }
    func money(_ value: Int) -> String { L10n.money.format(language, value) }
    func teacher(_ id: String) -> Teacher { teachers.first { $0.id == id } ?? teachers[0] }
    func teacherName(_ teacher: Teacher) -> String {
        switch teacher.id { case "sarah": return text(.teacherNameSarah)
        case "mohammad": return text(.teacherNameMohammad)
        default: return text(.teacherNameAhmad) }
    }
    func subject(_ teacher: Teacher) -> String {
        text(teacher.id == "sarah" ? .english : teacher.id == "mohammad" ? .science : .math)
    }
    func teacherLocation(_ teacher: Teacher) -> String {
        if let profile = snapshot.teacherProfiles[teacher.id] { return profile.areas.sorted { $0.rawValue < $1.rawValue }.map { text($0.key) }.joined(separator: language == .arabic ? "، " : ", ") }
        let area: L10n = teacher.id == "sarah" ? .khalda : teacher.id == "mohammad" ? .shmeisani : .jubeiha
        return text(.amman) + "، " + text(area)
    }
    func status(_ status: LessonStatus) -> String {
        text(status == .pending ? .pending : status == .accepted ? .accepted : .declined)
    }
    func lesson(_ id: UUID) -> Lesson? { snapshot.lessons.first { $0.id == id } }
    var teacherLessons: [Lesson] { snapshot.lessons.filter { $0.teacherID == selectedTeacherID } }
    var nextAcceptanceFee: Int { policy.fee(previousAcceptances: teacherLessons.filter { $0.status == .accepted }.count) }
    func toggleFavorite(_ id: String) {
        var changed = snapshot
        if changed.favoriteTeacherIDs.contains(id) { changed.favoriteTeacherIDs.remove(id) }
        else { changed.favoriteTeacherIDs.insert(id) }
        commit(changed)
    }
    @discardableResult
    private func commit(_ changed: DemoSnapshot) -> Bool {
        do { try repository.save(changed); snapshot = changed; return true }
        catch { self.error = .storageError; return false }
    }
    func book(_ draft: BookingDraft, teacher: Teacher) -> UUID? {
        guard snapshot.parentRegistration != nil else { error = .registrationRequired; return nil }
        do {
            try draft.validate()
            guard !snapshot.lessons.contains(where: {
                $0.teacherID == teacher.id && $0.status != .declined && abs($0.date.timeIntervalSince(draft.date)) < 3600
            }) else { throw LessonError.timeUnavailable }
            let lesson = Lesson(id: UUID(), teacherID: teacher.id, student: draft.student.trimmingCharacters(in: .whitespacesAndNewlines), grade: draft.grade, date: draft.date, address: draft.address, notes: draft.notes, price: hourlyRate(teacher), area: snapshot.parentRegistration?.area)
            var changed = snapshot; changed.lessons.append(lesson)
            return commit(changed) ? lesson.id : nil
        } catch { self.error = (error as? LessonError) == .timeUnavailable ? .timeUnavailable : .invalidBooking; return nil }
    }
    func accept(_ id: UUID) -> Bool {
        guard let index = snapshot.lessons.firstIndex(where: { $0.id == id }) else { return false }
        var changed = snapshot
        do {
            let lesson = changed.lessons[index]
            let count = changed.lessons.filter { $0.teacherID == lesson.teacherID && $0.status == .accepted }.count
            changed.lessons[index] = try policy.accept(lesson, previousAcceptances: count, paymentVerified: changed.transfers[id.uuidString]?.status == .verified)
            return commit(changed)
        } catch { self.error = (error as? LessonError) == .paymentRequired ? .paymentRequired : .alreadyHandled; return false }
    }
    func decline(_ id: UUID) {
        guard let index = snapshot.lessons.firstIndex(where: { $0.id == id }), snapshot.lessons[index].status == .pending else { error = .alreadyHandled; return }
        var changed = snapshot; changed.lessons[index].status = .declined; commit(changed)
    }
    func hourlyRate(_ teacher: Teacher) -> Int { snapshot.hourlyRates[teacher.id] ?? teacher.hourlyRate }
    @discardableResult
    func saveHourlyRate(_ raw: String) -> Bool {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).map { $0.wholeNumberValue.map(String.init) ?? String($0) }.joined()
        guard let value = Int(normalized), (1...500).contains(value) else { error = .invalidRate; return false }
        var changed = snapshot
        changed.hourlyRates[selectedTeacherID] = value
        return commit(changed)
    }
    func transfer(for id: UUID) -> AcceptanceTransfer? { snapshot.transfers[id.uuidString] }
    func submitTransfer(for id: UUID, reference: String) -> Bool {
        guard paymentConfiguration.isConfigured,
              let alias = paymentConfiguration.cliqAlias,
              let lesson = lesson(id), lesson.status == .pending,
              transfer(for: id) == nil || transfer(for: id)?.status == .rejected,
              !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let normalizedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snapshot.transfers.contains(where: { $0.key != id.uuidString && $0.value.reference.caseInsensitiveCompare(normalizedReference) == .orderedSame && $0.value.status != .rejected }) else { error = .duplicateReference; return false }
        var changed = snapshot
        changed.transfers[id.uuidString] = AcceptanceTransfer(reference: reference.trimmingCharacters(in: .whitespacesAndNewlines), recipientAlias: alias, amount: 1)
        return commit(changed)
    }
    /// Demo owner action. Production authorization and receipt verification belong on the server.
    func reviewTransfer(for id: UUID, approved: Bool) {
        guard var transfer = snapshot.transfers[id.uuidString], transfer.status == .submitted,
              lesson(id)?.status == .pending else { return }
        transfer.status = approved ? .verified : .rejected
        var changed = snapshot
        changed.transfers[id.uuidString] = transfer
        commit(changed)
    }
    func teachingAreas(_ teacherID: String) -> Set<JordanArea> {
        snapshot.teacherProfiles[teacherID]?.areas ?? [teacherID == "sarah" ? .khalda : teacherID == "mohammad" ? .shmeisani : .jubeiha]
    }
    func matchesArea(_ area: JordanArea?, teacherID: String) -> Bool {
        guard let area else { return false }
        let areas = teachingAreas(teacherID)
        let ammanAreas: Set<JordanArea> = [.amman, .jubeiha, .khalda, .shmeisani]
        return areas.contains(area) || (area == .amman && !areas.isDisjoint(with: ammanAreas)) || (areas.contains(.amman) && ammanAreas.contains(area))
    }
    var nearbyTeachers: [Teacher] { teachers.filter { matchesArea(snapshot.parentRegistration?.area, teacherID: $0.id) } }
    func saveParentRegistration(area: JordanArea, accepted: Bool) -> Bool {
        guard accepted else { error = .registrationRequired; return false }
        var changed = snapshot
        changed.parentRegistration = ParentRegistration(area: area, declaration: DeclarationRecord(acceptedAt: Date(), version: "parent-v1", language: language.rawValue))
        return commit(changed)
    }
    func saveTeacherRegistration(bio: String, areas: Set<JordanArea>, certificate: String?, accepted: Bool) -> Bool {
        let cleanBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard accepted, (20...1000).contains(cleanBio.count), !areas.isEmpty, FileManager.default.fileExists(atPath: Self.certificateDirectory.appendingPathComponent(certificate ?? "").path) else { error = .registrationRequired; return false }
        var changed = snapshot
        changed.teacherProfiles[selectedTeacherID] = TeacherRegistration(bio: cleanBio, areas: areas, certificateFile: certificate ?? "", declaration: DeclarationRecord(acceptedAt: Date(), version: "teacher-v1", language: language.rawValue))
        return commit(changed)
    }
    static var certificateDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PrivateCertificates", isDirectory: true)
    }
    private static func sampleRequests() -> [Lesson] {
        [Lesson(id: UUID(), teacherID: "ahmad", student: "عمر خالد", grade: 8, date: Date().addingTimeInterval(86400 * 2), address: "عمّان، الجبيهة، شارع الجامعة، مبنى 12", notes: "", price: 15, area: .jubeiha),
         Lesson(id: UUID(), teacherID: "ahmad", student: "جود سامر", grade: 6, date: Date().addingTimeInterval(86400 * 3), address: "عمّان، خلدا، شارع وصفي التل، مبنى 8", notes: "", price: 15, area: .khalda)]
    }
}
