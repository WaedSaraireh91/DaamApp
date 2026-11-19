import Foundation
import Security

/// Removes presentation-only direction controls; preserves the visible spelling.
enum AuthenticationInput {
  static func name(_ value: String) -> String {
    let controls = CharacterSet(charactersIn: "\u{061C}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")
    return String(String.UnicodeScalarView(value.unicodeScalars.filter { !controls.contains($0) }))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct BackendConfiguration {
  let url: URL
  static var configured: BackendConfiguration? {
    guard let file = Bundle.main.url(forResource: "BackendConfig", withExtension: "plist"),
      let data = try? Data(contentsOf: file),
      let values = try? PropertyListDecoder().decode([String: String].self, from: data),
      let raw = values["BaseURL"], let url = URL(string: raw), url.host != nil
    else { return nil }
    if url.scheme == "https" { return Self(url: url) }
    #if DEBUG && targetEnvironment(simulator)
      if url.scheme == "http" && url.host == "localhost" { return Self(url: url) }
    #endif
    return nil
  }
}
struct AuthSession: Codable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
  let sessionExpiresAt: Date

  private enum CodingKeys: String, CodingKey {
    case accessToken, refreshToken, expiresAt, sessionExpiresAt
  }

  init(accessToken: String, refreshToken: String, expiresAt: Date, sessionExpiresAt: Date) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.sessionExpiresAt = sessionExpiresAt
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    accessToken = try values.decode(String.self, forKey: .accessToken)
    refreshToken = try values.decode(String.self, forKey: .refreshToken)
    expiresAt = try values.decode(Date.self, forKey: .expiresAt)
    // Older keychain sessions lack an absolute expiry. Expire them at the stored
    // access-token boundary so they sign in again instead of receiving a new day.
    sessionExpiresAt = try values.decodeIfPresent(Date.self, forKey: .sessionExpiresAt) ?? expiresAt
  }

  func preservingSessionExpiry(_ expiry: Date) -> AuthSession {
    AuthSession(
      accessToken: accessToken, refreshToken: refreshToken,
      expiresAt: expiresAt, sessionExpiresAt: expiry)
  }
}
struct AppUpdatePolicy: Decodable {
  let forceUpdate: Bool
  let storeUrl: String?
}
struct AccountProfile: Decodable {
  let id: UUID
  let firstName: String
  let lastName: String
  let email: String?
  let role: String
  let emailVerified: Bool
  let phoneNumber: String?
  var displayName: String { firstName + " " + lastName }
}
enum AuthenticationError: Error {
  case rejected, throttled, unavailable, storage, sessionExpired
  case server(String)
}
struct APIEnvelope<Value: Decodable>: Decodable {
  let success: Bool
  let code: String?
  let data: Value?
  let errors: [ValidationField]?
}
struct ValidationField: Decodable { let field: String; let message: String? }
struct EmptyResponse: Decodable {}

/// Device-only session storage. Passwords are never persisted.
protocol AuthSessionStorage {
  func read() throws -> AuthSession?
  func save(_ session: AuthSession) throws
  func clear() throws
}
struct SessionKeychain: AuthSessionStorage {
  let account: String
  private var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "DaamApp.backend.authentication",
      kSecAttrAccount as String: account,
    ]
  }
  func read() throws -> AuthSession? {
    var request = query
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw AuthenticationError.storage
    }
    return try JSONDecoder().decode(AuthSession.self, from: data)
  }
  func save(_ session: AuthSession) throws {
    let data = try JSONEncoder().encode(session)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      guard
        SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
          == errSecSuccess
      else { throw AuthenticationError.storage }
    } else if status != errSecSuccess {
      throw AuthenticationError.storage
    }
  }
  func clear() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AuthenticationError.storage
    }
  }
}

/// Matches the Spring Boot /api/v1 contract. Tokens never appear in logs or URLs.
actor AuthenticationService {
  private let configuration: BackendConfiguration
  private let transport: URLSession
  private let keychain: any AuthSessionStorage
  private var session: AuthSession?
  private let deviceID: String
  private var refreshing: Task<AuthSession, Error>?
  init(
    configuration: BackendConfiguration,
    transport: URLSession = URLSession(configuration: .ephemeral),
    storage: (any AuthSessionStorage)? = nil
  ) {
    let defaults = UserDefaults.standard
    let identifier = defaults.string(forKey: "backendDeviceID") ?? UUID().uuidString
    defaults.set(identifier, forKey: "backendDeviceID")
    self.deviceID = identifier
    self.configuration = configuration
    self.transport = transport
    keychain = storage ?? SessionKeychain(account: configuration.url.absoluteString)
  }
  private struct Tokens: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: AccountProfile
    var session: AuthSession {
      let now = Date()
      return AuthSession(
        accessToken: accessToken, refreshToken: refreshToken,
        expiresAt: now.addingTimeInterval(expiresIn),
        sessionExpiresAt: now.addingTimeInterval(24 * 60 * 60))
    }
  }
  private func request<T: Decodable>(
    _ path: String, method: String = "POST", body: [String: String] = [:], token: String? = nil
  ) async throws -> APIEnvelope<T> {
    let url = configuration.url.appendingPathComponent("api/v1/" + path)
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    if method != "GET" { request.httpBody = try JSONEncoder().encode(body) }
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw AuthenticationError.unavailable }
    if http.statusCode == 429 { throw AuthenticationError.throttled }
    guard (200...299).contains(http.statusCode) else {
      let error = try? JSONDecoder().decode(APIEnvelope<EmptyResponse>.self, from: data)
      if error?.code == "VALIDATION_FAILED", let fields = error?.errors {
        if fields.contains(where: { $0.field == "code" }) { throw AuthenticationError.server("INVALID_PHONE_CODE") }
        if fields.contains(where: { ["firstName", "lastName"].contains($0.field) }) { throw AuthenticationError.server("INVALID_PERSON_NAME") }
      }
      if let code = error?.code { throw AuthenticationError.server(code) }
      throw http.statusCode >= 500 ? AuthenticationError.unavailable : AuthenticationError.rejected
    }
    let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
    guard envelope.success else { throw AuthenticationError.server(envelope.code ?? "UNKNOWN") }
    return envelope
  }
  private func save(_ value: AuthSession) throws {
    try keychain.save(value)
    session = value
  }
  func api<T: Decodable>(
    _ path: String, method: String = "GET", body: Data? = nil,
    contentType: String = "application/json", authenticated: Bool = true,
    timeoutInterval: TimeInterval = 30
  ) async throws -> T? {
    guard
      let endpoint = URL(
        string: "api/v1/" + path, relativeTo: configuration.url.appendingPathComponent("/"))?
        .absoluteURL
    else { throw AuthenticationError.unavailable }
    var request = URLRequest(url: endpoint)
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = timeoutInterval
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    if authenticated {
      request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw AuthenticationError.unavailable }
    guard (200...299).contains(http.statusCode) else {
      let envelope = try? JSONDecoder().decode(APIEnvelope<EmptyResponse>.self, from: data)
      throw AuthenticationError.server(envelope?.code ?? "UNKNOWN")
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = formatter.date(from: value) { return date }
      formatter.formatOptions = [.withInternetDateTime]
      if let date = formatter.date(from: value) { return date }
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid timestamp"))
    }
    let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
    guard envelope.success else { throw AuthenticationError.server(envelope.code ?? "UNKNOWN") }
    return envelope.data
  }
  func certificate(teacherID: UUID) async throws -> URL {
    var request = URLRequest(
      url: configuration.url.appendingPathComponent(
        "api/v1/admin/tutoring/teachers/\(teacherID)/certificate"))
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw AuthenticationError.rejected
    }
    let ext: String
    switch http.mimeType {
    case "application/pdf": ext = "pdf"
    case "image/png": ext = "png"
    case "image/jpeg": ext = "jpg"
    default: throw AuthenticationError.rejected
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(ext)
    try data.write(to: url, options: [.atomic, .completeFileProtection])
    return url
  }
  struct PhoneChallenge: Decodable {
    let challengeId: UUID
    let localTestCode: String
    let expiresIn: Int
    let retryAfter: Int
  }
  func sendPhoneCode(_ phone: String, signup: Bool) async throws -> PhoneChallenge {
    let response: APIEnvelope<PhoneChallenge> = try await request(
      "auth/phone/code", body: ["phoneNumber": phone, "purpose": signup ? "SIGNUP" : "LOGIN"])
    guard let challenge = response.data else { throw AuthenticationError.unavailable }
    return challenge
  }
  func verifyPhone(_ challenge: UUID, code: String, firstName: String?, lastName: String?)
    async throws -> AccountProfile
  {
    var body = ["challengeId": challenge.uuidString, "code": code.trimmingCharacters(in: .whitespacesAndNewlines), "deviceId": deviceID]
    if let firstName, let lastName {
      body["firstName"] = AuthenticationInput.name(firstName)
      body["lastName"] = AuthenticationInput.name(lastName)
    }
    let response: APIEnvelope<Tokens> = try await request("auth/phone/verify", body: body)
    guard let tokens = response.data else { throw AuthenticationError.unavailable }
    try save(tokens.session)
    return tokens.user
  }
  func signup(email: String, password: String, firstName: String, lastName: String) async throws {
    let _: APIEnvelope<AccountProfile> = try await request(
      "auth/register",
      body: ["email": email, "password": password, "firstName": AuthenticationInput.name(firstName), "lastName": AuthenticationInput.name(lastName)])
  }
  func login(email: String, password: String) async throws -> AccountProfile {
    let response: APIEnvelope<Tokens> = try await request(
      "auth/login",
      body: ["email": email, "password": password, "deviceName": "Daam iOS", "deviceId": deviceID])
    guard let tokens = response.data else { throw AuthenticationError.unavailable }
    try save(tokens.session)
    return tokens.user
  }
  func accessToken() async throws -> String {
    guard let current = session else { throw AuthenticationError.rejected }
    guard current.sessionExpiresAt > Date() else {
      try? keychain.clear()
      session = nil
      throw AuthenticationError.sessionExpired
    }
    if current.expiresAt.timeIntervalSinceNow > 60 { return current.accessToken }
    if let refreshing { return try await refreshing.value.accessToken }
    let task = Task<AuthSession, Error> {
      let response: APIEnvelope<Tokens> = try await self.request(
        "auth/refresh", body: ["refreshToken": current.refreshToken])
      guard let tokens = response.data else { throw AuthenticationError.unavailable }
      let renewed = tokens.session.preservingSessionExpiry(current.sessionExpiresAt)
      try self.save(renewed)
      return renewed
    }
    refreshing = task
    defer { refreshing = nil }
    return try await task.value.accessToken
  }
  func restore() async throws -> AccountProfile? {
    session = try keychain.read()
    guard let current = session else { return nil }
    guard current.sessionExpiresAt > Date() else {
      try keychain.clear()
      session = nil
      return nil
    }
    do {
      let response: APIEnvelope<AccountProfile> = try await request(
        "users/me", method: "GET", token: accessToken())
      guard let user = response.data else { throw AuthenticationError.unavailable }
      return user
    } catch AuthenticationError.server(let code)
      where ["INVALID_TOKEN", "TOKEN_EXPIRED", "UNAUTHORIZED", "ACCOUNT_DISABLED"].contains(code)
    {
      try keychain.clear()
      session = nil
      return nil
    }
  }
  func logout() async throws {
    if session != nil {
      do {
        let _: APIEnvelope<EmptyResponse> = try await request("auth/logout", token: accessToken())
      } catch {}
    }
    try keychain.clear()
    session = nil
  }
  func sessionExpiration() -> Date? { session?.sessionExpiresAt }

  func expireSession() {
    try? keychain.clear()
    session = nil
  }

  func checkUpdatePolicy() async -> AppUpdatePolicy? {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    do {
      return try await api(
        "public/app-config?platform=ios&version=\(version)",
        authenticated: false,
        timeoutInterval: 5)
    } catch {
      return nil
    }
  }
  func resend(email: String) async throws {
    let _: APIEnvelope<EmptyResponse> = try await request(
      "auth/resend-verification", body: ["email": email])
  }
  func verify(token: String) async throws {
    let _: APIEnvelope<EmptyResponse> = try await request(
      "auth/verify-email", body: ["token": token])
  }
  func forgotPassword(email: String) async throws {
    let _: APIEnvelope<EmptyResponse> = try await request(
      "auth/forgot-password", body: ["email": email])
  }
  func resetPassword(token: String, password: String) async throws {
    let _: APIEnvelope<EmptyResponse> = try await request(
      "auth/reset-password", body: ["token": token, "newPassword": password])
    try keychain.clear()
    session = nil
  }
}

struct AuthenticationLink {
  enum Action { case verify, reset }
  let action: Action
  let token: String
  init?(url: URL) {
    guard url.scheme == "daam", url.path.isEmpty || url.path == "/",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let items = components.queryItems?.filter({ $0.name == "token" }), items.count == 1,
      let token = items.first?.value, !token.isEmpty, token.count <= 256
    else { return nil }
    switch url.host {
    case "verify-email": action = .verify
    case "reset-password": action = .reset
    default: return nil
    }
    self.token = token
  }
}
