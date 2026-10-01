import Foundation

/// In-memory fixtures only. Replace at the composition root when the API contract is ready.
struct MockTutoringRepository: TutoringRepository {
    func teachers() async throws -> [Teacher] { Self.fixtures }
    static let fixtures: [Teacher] =
        [Teacher(id: "ahmad", name: "أ. أحمد العبدالله", initial: "أ", subject: "رياضيات", city: "عمّان", hourlyRate: 15, rating: "4.9", modes: [.online, .inPerson]),
         Teacher(id: "sarah", name: "أ. سارة القيسي", initial: "س", subject: "لغة إنجليزية", city: "عمّان", hourlyRate: 18, rating: "4.8", modes: [.online]),
         Teacher(id: "mohammad", name: "أ. محمد بني هاني", initial: "م", subject: "علوم", city: "عمّان", hourlyRate: 14, rating: "4.7", modes: [.inPerson])]
    func dashboard() async throws -> DashboardSummary {
        DashboardSummary(newRequests: 5, upcomingLessons: 8, activeStudents: 12, monthlyEarnings: 320)
    }
}
