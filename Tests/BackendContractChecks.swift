import Foundation

final class MemorySessions: AuthSessionStorage {
  var session: AuthSession?
  func read() throws -> AuthSession? { session }
  func save(_ session: AuthSession) throws { self.session = session }
  func clear() throws { session = nil }
}
final class StubTransport: URLProtocol, @unchecked Sendable {
  static var handler: (URLRequest) throws -> (Int, String) = { _ in (500, "{}") }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let (code, body) = try Self.handler(request)
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: code, httpVersion: nil,
          headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(body.utf8))
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}
@main
struct BackendContractChecks {
  static func main() async throws {
    precondition(AuthenticationInput.name(" \u{202B}ahmed\u{202C} ") == "ahmed")
    precondition(AuthenticationInput.name("\u{200F}سرايرة\u{2069}") == "سرايرة")
    precondition(AuthenticationInput.name("O'Neil-Smith") == "O'Neil-Smith")
    precondition(AuthenticationInput.name("ahmed123") == "ahmed123") // Do not hide invalid visible input.
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubTransport.self]
    let storage = MemorySessions()
    let service = AuthenticationService(
      configuration: BackendConfiguration(url: URL(string: "http://localhost:8080")!),
      transport: URLSession(configuration: config), storage: storage)
    let user =
      #"{"id":"11111111-1111-1111-1111-111111111111","firstName":"Test","lastName":"Parent","email":"test@example.test","role":"USER","emailVerified":true}"#
    StubTransport.handler = { request in
      precondition(request.url!.path == "/api/v1/auth/login")
      precondition(request.httpMethod == "POST")
      return (
        200,
        "{\"success\":true,\"data\":{\"accessToken\":\"test-access\",\"refreshToken\":\"test-refresh\",\"expiresIn\":900,\"user\":\(user)}}"
      )
    }
    let account = try await service.login(email: "test@example.test", password: "TestPassword1!")
    precondition(account.role == "USER" && account.displayName == "Test Parent")
    precondition(storage.session?.accessToken == "test-access")
    StubTransport.handler = { request in
      precondition(request.url!.query == "area=amman")
      precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access")
      return (200, #"{"success":true,"data":[]}"#)
    }
    let teachers: [LiveProfile]? = try await service.api("tutoring/teachers?area=amman")
    precondition(teachers?.isEmpty == true)
    StubTransport.handler = { _ in
      (
        200,
        #"{"success":true,"data":[{"id":"11111111-1111-1111-1111-111111111111","teacherId":"11111111-1111-1111-1111-111111111111","startsAt":"2026-12-01T09:00:00.123456Z","endsAt":"2026-12-01T10:00:00Z"}]}"#
      )
    }
    let slots: [LiveSlot]? = try await service.api("tutoring/teachers/test/slots")
    precondition(slots?.count == 1 && slots![0].endsAt > slots![0].startsAt)
    StubTransport.handler = { _ in (422, #"{"success":false,"code":"PAYMENT_REQUIRED"}"#) }
    do {
      let _: LiveLesson? = try await service.api("tutoring/lessons/test/accept", method: "POST")
      preconditionFailure("Expected rejection")
    } catch AuthenticationError.server(let code) { precondition(code == "PAYMENT_REQUIRED") }
    StubTransport.handler = { _ in (200, #"{"success":true}"#) }
    try await service.logout()
    precondition(storage.session == nil)
    precondition(
      AuthenticationLink(url: URL(string: "daam://reset-password?token=test-token")!) != nil)
    precondition(
      AuthenticationLink(url: URL(string: "https://reset-password?token=test-token")!) == nil)
    precondition(
      AuthenticationLink(url: URL(string: "daam://reset-password?token=one&token=two")!) == nil)
    print(
      "PASS: login, session storage, authenticated query, timestamp decoding, error codes, logout, and deep links"
    )
  }
}
