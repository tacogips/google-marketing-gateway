import Darwin
import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func desktopClientDecodesGoogleSnakeCaseAndBuildsPKCEURL() throws {
  let client = try JSONDecoder().decode(OAuthDesktopClient.self, from: Data("""
  {"installed":{"client_id":"desktop-client","client_secret":"not-output","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":["http://127.0.0.1"]}}
  """.utf8))
  let url = try OAuthPKCE.authorizationURL(client: client, scopes: ["scope-a"], redirectURI: "http://127.0.0.1:12345/oauth2callback", state: String(repeating: "s", count: 43), verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
  #expect(items.contains(URLQueryItem(name: "code_challenge_method", value: "S256")))
  #expect(items.contains(URLQueryItem(name: "redirect_uri", value: "http://127.0.0.1:12345/oauth2callback")))
  #expect(!url.absoluteString.contains("not-output"))
}

@Test func desktopClientAndTokenStoreRejectUnknownOrUnboundedSchema() throws {
  let unknownRoot = Data(#"{"installed":{"client_id":"id","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[]},"web":{}}"#.utf8)
  let unknownInstalled = Data(#"{"installed":{"client_id":"id","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[],"project_id":"unexpected"}}"#.utf8)
  let redirects = Array(repeating: "http://127.0.0.1", count: 33)
  let oversizedRedirects = try JSONSerialization.data(withJSONObject: [
    "installed": [
      "client_id": "id",
      "auth_uri": OAuthDesktopClient.authorizationEndpoint,
      "token_uri": OAuthDesktopClient.tokenEndpoint,
      "redirect_uris": redirects
    ]
  ])
  for data in [unknownRoot, unknownInstalled, oversizedRedirects] {
    #expect(throws: GatewayError.self) { _ = try JSONDecoder().decode(OAuthDesktopClient.self, from: data) }
  }

  let profile = tokenProfile(path: "/private/var/unused-token.json")
  let token = try OAuthToken(
    profile: profile, accessToken: "access", refreshToken: "refresh", tokenType: "Bearer",
    expiry: Date(timeIntervalSince1970: 2_000_000_000), updatedAt: Date(timeIntervalSince1970: 1_900_000_000), scopes: ["scope-a"]
  )
  var stored = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(token)) as? [String: Any])
  stored["unexpected"] = "field"
  #expect(throws: GatewayError.self) {
    _ = try JSONDecoder().decode(OAuthToken.self, from: JSONSerialization.data(withJSONObject: stored))
  }
}

@Test func privateTokenStoreRoundTripsAndLogoutIsScoped() throws {
  let root = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected-token.json").path
  let profile = tokenProfile(path: path)
  let token = try OAuthToken(profile: profile, accessToken: "access-value", refreshToken: "refresh-value", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"])
  let store = OAuthTokenStore()
  try store.write(token, path: path, profile: profile)
  #expect(try store.read(path: path, profile: profile).accessToken == "access-value")
  #expect(try store.delete(path: path, profile: profile))
  #expect(!FileManager.default.fileExists(atPath: path))
}

@Test func tokenStoreRefusesToDeleteAnEntryBoundToAnotherProfile() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected-token.json").path
  let selected = tokenProfile(path: path)
  let other = CredentialProfile(id: "other-profile", product: .analyticsData, capability: .reader, oauthScopes: ["scope-a"], accessTokenEnvironmentVariable: "OTHER_TOKEN", oauthClientJSONPath: selected.oauthClientJSONPath, tokenStorePath: path)
  let store = OAuthTokenStore()
  try store.write(try OAuthToken(profile: selected, accessToken: "access-value", refreshToken: "refresh-value", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"]), path: path, profile: selected)
  #expect(throws: GatewayError.self) { _ = try store.delete(path: path, profile: other) }
  #expect(try store.read(path: path, profile: selected).accessToken == "access-value")
}

@Test func privateTokenStoreSafelyReplacesItsSelectedPrivateEntry() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected-token.json").path
  let store = OAuthTokenStore()
  let profile = tokenProfile(path: path)
  try store.write(try OAuthToken(profile: profile, accessToken: "first", refreshToken: "refresh", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"]), path: path, profile: profile)
  try store.write(try OAuthToken(profile: profile, accessToken: "second", refreshToken: "refresh", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"]), path: path, profile: profile)
  #expect(try store.read(path: path, profile: profile).accessToken == "second")
}

@Test func tokenStoreRejectsSymlinkForReadAndDeletion() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let target = root.appendingPathComponent("target.json"); let link = root.appendingPathComponent("selected.json")
  try Data("{}".utf8).write(to: target)
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
  let store = OAuthTokenStore()
  let profile = tokenProfile(path: link.path)
  #expect(throws: GatewayError.self) { _ = try store.read(path: link.path, profile: profile) }
  #expect(throws: GatewayError.self) { _ = try store.delete(path: link.path, profile: profile) }
  #expect(FileManager.default.fileExists(atPath: target.path))
}

@Test func tokenStoreRejectsPermissiveParentDirectoryOnRead() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected.json").path
  let profile = tokenProfile(path: path)
  let store = OAuthTokenStore()
  try store.write(try OAuthToken(profile: profile, accessToken: "access-value", refreshToken: "refresh-value", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"]), path: path, profile: profile)
  #expect(chmod(root.path, 0o755) == 0)
  #expect(throws: GatewayError.self) { _ = try store.read(path: path, profile: profile) }
}

@Test func tokenStoreDoesNotOverwriteDestinationThatAppearsBeforePublish() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected.json").path
  try Data("existing".utf8).write(to: URL(fileURLWithPath: path))
  let profile = tokenProfile(path: path)
  let token = try OAuthToken(profile: profile, accessToken: "access-value", refreshToken: "refresh-value", tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: ["scope-a"])
  #expect(throws: GatewayError.self) { try OAuthTokenStore().write(token, path: path, profile: profile) }
  #expect(try String(contentsOfFile: path) == "existing")
}

@Test func callbackParserRejectsUnexpectedParametersAndAcceptsOnlyExactRequest() throws {
  let state = String(repeating: "s", count: 43)
  #expect(try OAuthLoopbackReceiver.callbackCode(request: "GET /oauth2callback?code=authorization-code&state=\(state) HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n", expectedState: state) == "authorization-code")
  #expect(throws: GatewayError.self) {
    _ = try OAuthLoopbackReceiver.callbackCode(request: "GET /oauth2callback?code=authorization-code&state=\(state)&unexpected=value HTTP/1.1\r\n\r\n", expectedState: state)
  }
  #expect(throws: GatewayError.self) {
    _ = try OAuthLoopbackReceiver.callbackCode(request: "POST /oauth2callback?code=authorization-code&state=\(state) HTTP/1.1\r\n\r\n", expectedState: state)
  }
  #expect(throws: GatewayError.self) {
    _ = try OAuthLoopbackReceiver.callbackCode(request: "GET /oauth2callback?error=access_denied&state=\(state) HTTP/1.1\r\n\r\n", expectedState: state)
  }
  let maximumCode = String(repeating: "a", count: 8_192)
  #expect(try OAuthLoopbackReceiver.callbackCode(request: "GET /oauth2callback?code=\(maximumCode)&state=\(state) HTTP/1.1\r\n\r\n", expectedState: state) == maximumCode)
  #expect(throws: GatewayError.self) {
    _ = try OAuthLoopbackReceiver.callbackCode(request: "GET /oauth2callback?code=\(maximumCode)a&state=\(state) HTTP/1.1\r\n\r\n", expectedState: state)
  }
}

@Test func loopbackReceiverContinuesAfterInvalidCallback() async throws {
  let receiver = try OAuthLoopbackReceiver()
  let state = String(repeating: "s", count: 43)
  let waiting = Task { try receiver.waitForCode(expectedState: state, timeoutSeconds: 3) }
  let invalidURL = try #require(URL(string: "\(receiver.redirectURI)?code=wrong&state=not-the-state"))
  _ = try await URLSession.shared.data(for: URLRequest(url: invalidURL))
  let validURL = try #require(URL(string: "\(receiver.redirectURI)?code=authorization-code&state=\(state)"))
  _ = try await URLSession.shared.data(for: URLRequest(url: validURL))
  let received = try await waiting.value
  #expect(received == "authorization-code")
}

@Test func loopbackReceiverBoundsAStalledConnection() async throws {
  let receiver = try OAuthLoopbackReceiver()
  let waiting = Task { try receiver.waitForCode(expectedState: String(repeating: "s", count: 43), timeoutSeconds: 1) }
  let socket = try stalledLoopbackConnection(redirectURI: receiver.redirectURI)
  defer { close(socket) }
  do {
    _ = try await waiting.value
    Issue.record("A stalled OAuth callback must not complete login")
  } catch is GatewayError {
  }
}

@Test func OAuthClientRefreshUsesInjectedHTTPAndPreservesScope() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let clientPath = root.appendingPathComponent("client.json").path
  try Data(#"{"installed":{"client_id":"id","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[]}}"#.utf8).write(to: URL(fileURLWithPath: clientPath))
  let profile = tokenProfile(path: root.appendingPathComponent("token.json").path)
  let token = try OAuthToken(profile: profile, accessToken: "old", refreshToken: "refresh", tokenType: "Bearer", expiry: .distantPast, scopes: ["scope-a"])
  let refreshed = try OAuthClient(http: OAuthHTTPStub()).refresh(clientPath: clientPath, token: token, requiredScopes: ["scope-a"])
  #expect(refreshed.accessToken == "fresh")
  #expect(refreshed.refreshToken == "refresh")
}

@Test func OAuthHTTPRefuses307And308RedirectsWithoutReplayingCredentials() throws {
  for statusCode in [307, 308] {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OAuthRedirectURLProtocol.self]
    OAuthRedirectURLProtocol.reset(statusCode: statusCode)
    let http = URLSessionOAuthHTTP(configuration: configuration, timeoutSeconds: 2)
    var request = URLRequest(url: try #require(URL(string: OAuthDesktopClient.tokenEndpoint)))
    request.httpMethod = "POST"
    request.httpBody = Data("refresh_token=refresh-sentinel&client_secret=secret-sentinel".utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let (_, response) = try http.execute(request)

    #expect(response.statusCode == statusCode)
    let requests = OAuthRedirectURLProtocol.requests
    #expect(requests.count == 1)
    #expect(requests.first?.url == request.url)
    #expect(requests.allSatisfy { $0.url?.host != "redirect-capture.invalid" })
  }
}

@Test func resolverSerializesSameStoreRefreshes() async throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected-token.json").path
  let profile = CredentialProfile(
    id: "analytics-reader",
    product: .analyticsData,
    capability: .reader,
    oauthScopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    accessTokenEnvironmentVariable: "AN_TOKEN",
    oauthClientJSONPath: root.appendingPathComponent("client.json").path,
    tokenStorePath: path
  )
  let store = OAuthTokenStore()
  try store.write(try OAuthToken(profile: profile, accessToken: "expired", refreshToken: "refresh", tokenType: "Bearer", expiry: .distantPast, scopes: profile.oauthScopes), path: path, profile: profile)
  let refresher = RefreshSpy(profile: profile)
  let resolver = ReaderCredentialResolver(tokenStore: store, refresher: refresher)
  async let first = resolver.accessToken(profile: profile, environment: [:])
  async let second = resolver.accessToken(profile: profile, environment: [:])
  #expect(try await first == "fresh")
  #expect(try await second == "fresh")
  #expect(refresher.callCount == 1)
}

@Test func resolverReportsAllowlistedNearExpiryMetadataWithInjectedClock() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("selected-token.json").path
  let profile = tokenProfile(path: path)
  let current = Date(timeIntervalSince1970: 1_700_000_000)
  let store = OAuthTokenStore()
  try store.write(try OAuthToken(profile: profile, accessToken: "access-value", refreshToken: "refresh-value", tokenType: "Bearer", expiry: current.addingTimeInterval(60), updatedAt: current, scopes: ["scope-a"]), path: path, profile: profile)
  let status = ReaderCredentialResolver(tokenStore: store, now: { current }).status(profile: profile, environment: [:])
  #expect(status.profileId == profile.id)
  #expect(status.product == profile.product)
  #expect(status.oauthScopes == profile.oauthScopes)
  #expect(!status.environmentTokenAvailable)
  #expect(status.tokenStoreConfigured && status.tokenStoreExists)
  #expect(status.state == "near-expiry")
  #expect(status.expiresAt == current.addingTimeInterval(60))
  #expect(status.hasRefreshToken)
}

@Test func statusReportsInvalidStoreEvenWhenEnvironmentTokenIsAvailable() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let target = root.appendingPathComponent("target.json")
  let link = root.appendingPathComponent("selected.json")
  try Data("{}".utf8).write(to: target)
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
  let profile = tokenProfile(path: link.path)
  let status = ReaderCredentialResolver().status(profile: profile, environment: [profile.accessTokenEnvironmentVariable: "environment-token"])
  #expect(status.environmentTokenAvailable)
  #expect(status.tokenStoreExists)
  #expect(status.state == "ready")
  #expect(status.tokenSource == "ENVIRONMENT_TOKEN")
  #expect(ReaderCredentialResolver().status(profile: profile, environment: [:]).state == "invalid")
}

@Test func authLoginUsesInjectedTokenStoreAndSurfacesPersistenceFailure() throws {
  let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let clientPath = root.appendingPathComponent("client.json").path
  try Data(#"{"installed":{"client_id":"id","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[]}}"#.utf8).write(to: URL(fileURLWithPath: clientPath))
  let profile = CredentialProfile(id: "oauth-test", product: .analyticsData, capability: .reader, oauthScopes: ["scope-a"], accessTokenEnvironmentVariable: "OAUTH_TEST_TOKEN", oauthClientJSONPath: clientPath, tokenStorePath: root.appendingPathComponent("selected.json").path)
  let recorder = TokenStoreSpy()
  let opened = OpenURLSpy()
  let service = ReaderAuthService(
    oauth: OAuthClient(http: OAuthHTTPStub()),
    openURL: { url in opened.open(url) },
    makeReceiver: { _ in FixedReceiver(redirectURI: "http://127.0.0.1:12345/oauth2callback", code: "authorization-code") },
    randomString: { String(repeating: "s", count: $0) },
    tokenStore: recorder
  )
  let login = try service.login(profile: profile, noBrowser: false, redirectURI: nil, timeoutSeconds: 1)
  #expect(login.state == "ready")
  #expect(login.tokenSource == "FILE")
  #expect(login.tokenStorePath == profile.tokenStorePath)
  #expect(login.tokenSourceHint?.contains("Unset OAUTH_TEST_TOKEN") == true)
  #expect(opened.count == 1)
  #expect(recorder.writeCount == 1)
  let failing = TokenStoreSpy(writeError: GatewayError("persistence failed", code: .invalidConfiguration))
  let failingService = ReaderAuthService(
    oauth: OAuthClient(http: OAuthHTTPStub()),
    openURL: { _ in true },
    makeReceiver: { _ in FixedReceiver(redirectURI: "http://127.0.0.1:12345/oauth2callback", code: "authorization-code") },
    randomString: { String(repeating: "s", count: $0) },
    tokenStore: failing
  )
  #expect(throws: GatewayError.self) { _ = try failingService.login(profile: profile, noBrowser: false, redirectURI: nil, timeoutSeconds: 1) }
}

private struct OAuthHTTPStub: OAuthHTTPHandling {
  func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == OAuthDesktopClient.tokenEndpoint)
    guard let url = request.url else { throw GatewayError("missing URL", code: .invalidResponse) }
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (Data(#"{"access_token":"fresh","refresh_token":"refresh","token_type":"Bearer","expires_in":3600,"scope":"scope-a"}"#.utf8), response)
  }
}

private final class OAuthRedirectURLProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []
  nonisolated(unsafe) private static var configuredStatusCode = 307

  static var requests: [URLRequest] {
    lock.lock()
    defer { lock.unlock() }
    return recordedRequests
  }

  static func reset(statusCode: Int) {
    lock.lock()
    defer { lock.unlock() }
    recordedRequests = []
    configuredStatusCode = statusCode
  }

  // swiftlint:disable:next static_over_final_class
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host != "redirect-capture.invalid"
  }

  // swiftlint:disable:next static_over_final_class
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.lock.lock()
    Self.recordedRequests.append(request)
    let statusCode = Self.configuredStatusCode
    Self.lock.unlock()
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: ["Location": "https://redirect-capture.invalid/private-request"]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

private struct FixedReceiver: OAuthLoopbackReceiving {
  let redirectURI: String
  let code: String
  func waitForCode(expectedState: String, timeoutSeconds: Int32) throws -> String {
    #expect(expectedState.count == 43)
    #expect(timeoutSeconds == 1)
    return code
  }
}

private final class TokenStoreSpy: OAuthTokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private let writeError: Error?
  private var writes = 0
  init(writeError: Error? = nil) { self.writeError = writeError }
  var writeCount: Int { lock.lock(); defer { lock.unlock() }; return writes }
  func read(path: String, profile: CredentialProfile) throws -> OAuthToken { throw GatewayError("unused", code: .invalidConfiguration) }
  func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws {
    lock.lock(); writes += 1; lock.unlock()
    if let writeError { throw writeError }
  }
  func delete(path: String, profile: CredentialProfile) throws -> Bool { false }
}

private final class OpenURLSpy: @unchecked Sendable {
  private let lock = NSLock()
  private var opens = 0
  var count: Int { lock.lock(); defer { lock.unlock() }; return opens }
  func open(_ url: URL) -> Bool { lock.lock(); opens += 1; lock.unlock(); return true }
}

private final class RefreshSpy: OAuthTokenRefreshing, @unchecked Sendable {
  private let lock = NSLock()
  private let profile: CredentialProfile
  private var calls = 0
  init(profile: CredentialProfile) { self.profile = profile }
  var callCount: Int { lock.lock(); defer { lock.unlock() }; return calls }
  func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    lock.lock(); calls += 1; lock.unlock()
    Thread.sleep(forTimeInterval: 0.05)
    return try OAuthToken(profile: profile, accessToken: "fresh", refreshToken: token.refreshToken, tokenType: "Bearer", expiry: Date().addingTimeInterval(3_600), scopes: requiredScopes)
  }
}

private func temporaryDirectory() throws -> URL {
  let base = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"), isDirectory: true)
  let url = base.appendingPathComponent("gateway-oauth-test-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
  return url
}

private func tokenProfile(path: String) -> CredentialProfile {
  CredentialProfile(
    id: "oauth-test",
    product: .analyticsData,
    capability: .reader,
    oauthScopes: ["scope-a"],
    accessTokenEnvironmentVariable: "OAUTH_TEST_TOKEN",
    oauthClientJSONPath: "/private/var/empty-client.json",
    tokenStorePath: path
  )
}

private func stalledLoopbackConnection(redirectURI: String) throws -> Int32 {
  let components = try #require(URLComponents(string: redirectURI))
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  guard fd >= 0 else { throw GatewayError("test socket failed", code: .transportFailure) }
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = UInt16(try #require(components.port)).bigEndian
  address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
  let result = withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard result == 0 else { close(fd); throw GatewayError("test socket connect failed", code: .transportFailure) }
  return fd
}
