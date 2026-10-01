import Foundation

@main
struct DomainChecks {
    static func main() async throws {
        let repository = MockTutoringRepository()
        let search = SearchTeachers(repository: repository)
        let all = try await search(mode: .all)
        let online = try await search(mode: .online)
        let inPerson = try await search(mode: .inPerson)
        precondition(all.count == 3)
        precondition(online.map(\.id) == ["ahmad", "sarah"])
        precondition(inPerson.map(\.id) == ["ahmad", "mohammad"])
        precondition(CredentialsValidator.isValid(email: "demo@example.com", password: "demo1234"))
        precondition(!CredentialsValidator.isValid(email: "invalid", password: "demo1234"))
        precondition(!CredentialsValidator.isValid(email: "demo@example.com", password: "short"))
        let dashboard = try await LoadDashboard(repository: repository)()
        precondition(dashboard.newRequests == 5 && dashboard.monthlyEarnings == 320)
        print("Passed: teacher filtering, credential validation, dashboard fixtures")
    }
}
