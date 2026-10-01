import Foundation

@main
struct BookingChecks {
    @MainActor static func main() throws {
        let policy = AcceptancePolicy()
        let lesson = Lesson(id: UUID(), teacherID: "ahmad", student: "Student", grade: 6, date: Date().addingTimeInterval(86400), address: "Amman street 123", notes: "", price: 15)
        let first = try policy.accept(lesson, previousAcceptances: 0)
        precondition(first.acceptanceFee == 0 && first.status == .accepted)
        let second = try policy.accept(lesson, previousAcceptances: 1, paymentVerified: true)
        precondition(second.acceptanceFee == 1)
        let later = try policy.accept(lesson, previousAcceptances: 20, paymentVerified: true)
        precondition(later.acceptanceFee == 1)
        do { _ = try policy.accept(first, previousAcceptances: 1, paymentVerified: true); fatalError("Duplicate acceptance allowed") }
        catch LessonError.alreadyHandled { }
        var draft = BookingDraft()
        do { try draft.validate(); fatalError("Empty booking allowed") } catch LessonError.invalidBooking { }
        draft.student = "Test student"; draft.address = "Amman, test street 123"; draft.date = Date().addingTimeInterval(3600)
        try draft.validate()
        draft.date = Date().addingTimeInterval(-10)
        do { try draft.validate(); fatalError("Past booking allowed") } catch LessonError.invalidBooking { }
        let repository = MemoryRepository()
        let config = PaymentConfiguration(recipientName: "TestAccount", cliqAlias: "TestAccount")
        let app = AppModel(repository: repository, paymentConfiguration: config)
        precondition(!app.saveParentRegistration(area: .irbid, accepted: false))
        precondition(app.snapshot.parentRegistration == nil)
        precondition(app.saveParentRegistration(area: .jubeiha, accepted: true))
        precondition(app.nearbyTeachers.map(\.id) == ["ahmad"])
        precondition(app.matchesArea(.amman, teacherID: "sarah"))
        precondition(!app.matchesArea(.irbid, teacherID: "sarah"))
        precondition(!app.matchesArea(nil, teacherID: "sarah"))
        precondition(!app.saveTeacherRegistration(bio: "An experienced mathematics teacher", areas: [.amman], certificate: "", accepted: true))
        let legacy = try JSONDecoder().decode(DemoSnapshot.self, from: Data("{}".utf8))
        precondition(legacy.parentRegistration == nil && legacy.teacherProfiles.isEmpty)
        let encoded = try JSONEncoder().encode(app.snapshot)
        let decoded = try JSONDecoder().decode(DemoSnapshot.self, from: encoded)
        precondition(decoded.parentRegistration?.area == .jubeiha)
        precondition(decoded.parentRegistration?.declaration.version == "parent-v1")
        let requests = app.teacherLessons
        precondition(app.accept(requests[0].id))
        precondition(app.nextAcceptanceFee == 1)
        precondition(!app.accept(requests[0].id))
        precondition(!app.accept(requests[1].id))
        precondition(app.error == .paymentRequired)
        precondition(app.submitTransfer(for: requests[1].id, reference: "DEMO-TEST-001"))
        precondition(!app.accept(requests[1].id))
        app.reviewTransfer(for: requests[1].id, approved: false)
        precondition(app.transfer(for: requests[1].id)?.status == .rejected)
        precondition(app.submitTransfer(for: requests[1].id, reference: "DEMO-TEST-002"))
        app.reviewTransfer(for: requests[1].id, approved: true)
        precondition(app.transfer(for: requests[1].id)?.status == .verified)
        precondition(app.lesson(requests[1].id)?.status == .pending)
        precondition(app.accept(requests[1].id))
        precondition(app.saveHourlyRate("٢٥"))
        precondition(app.hourlyRate(app.teacher("ahmad")) == 25)
        precondition(!app.saveHourlyRate("0"))
        precondition(app.teacherLessons.compactMap(\.acceptanceFee).reduce(0,+) == 1)
        let reloaded = AppModel(repository: repository)
        precondition(reloaded.nextAcceptanceFee == 1)
        precondition(reloaded.hourlyRate(reloaded.teacher("ahmad")) == 25)
        repository.failSave = true
        let before = reloaded.snapshot.favoriteTeacherIDs
        reloaded.toggleFavorite("ahmad")
        precondition(reloaded.snapshot.favoriteTeacherIDs == before)
        precondition(reloaded.error == .storageError)
        print("PASS: first-free, paid acceptance gate, owner verification, rejection/resubmission, Arabic-digit rates, persistence, duplicate rejection, validation and rollback")
    }
}
final class MemoryRepository: LessonRepository {
    var snapshot: DemoSnapshot?
    var failSave = false
    func load() throws -> DemoSnapshot? { snapshot }
    func save(_ snapshot: DemoSnapshot) throws {
        if failSave { throw LessonError.storage }
        self.snapshot = snapshot
    }
}
