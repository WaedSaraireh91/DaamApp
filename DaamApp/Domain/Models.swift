import Foundation

enum LessonMode: String, CaseIterable, Identifiable, Sendable {
    case all, online, inPerson
    var id: String { rawValue }
}

struct Teacher: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let initial: String
    let subject: String
    let city: String
    let hourlyRate: Int
    let rating: String
    let modes: Set<LessonMode>
}

struct DashboardSummary: Equatable, Sendable {
    let newRequests: Int
    let upcomingLessons: Int
    let activeStudents: Int
    let monthlyEarnings: Int
}

protocol TutoringRepository: Sendable {
    func teachers() async throws -> [Teacher]
    func dashboard() async throws -> DashboardSummary
}

struct SearchTeachers: Sendable {
    let repository: any TutoringRepository
    func callAsFunction(mode: LessonMode) async throws -> [Teacher] {
        let teachers = try await repository.teachers()
        return teachers.filter { mode == .all || $0.modes.contains(mode) }
    }
}

struct LoadDashboard: Sendable {
    let repository: any TutoringRepository
    func callAsFunction() async throws -> DashboardSummary { try await repository.dashboard() }
}

enum CredentialsValidator {
    static func isValid(email: String, password: String) -> Bool {
        let parts = email.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !email.contains(" ") && password.count >= 6
    }
}
