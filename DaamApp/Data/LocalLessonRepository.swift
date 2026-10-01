import Foundation

/// Local demo persistence. A production repository must enforce fees server-side.
struct LocalLessonRepository: LessonRepository {
    private let defaults: UserDefaults
    private let key = "daam.demo.snapshot.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> DemoSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(DemoSnapshot.self, from: data)
    }
    func save(_ snapshot: DemoSnapshot) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
    }
}
