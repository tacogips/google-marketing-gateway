import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

private final class NewRouteTransport: HTTPTransport, @unchecked Sendable {
  private let lock = NSLock()
  private(set) var requests: [URLRequest] = []

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard let url = request.url else { throw GatewayError("missing URL", code: .invalidResponse) }
    lock.withLock { requests.append(request) }
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (Data(#"{"ok":true}"#.utf8), response)
  }
}

@Test func invalidAnalyticsInputDoesNotResolveCredentials() async throws {
  let root = try cliTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"analytics","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"TOKEN"}]}"#.utf8).write(to: config)
  let spy = CredentialSpy()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, credentialResolver: spy).run(arguments: ["analytics-data", "metadata", "get", "--property", "bad", "--profile", "analytics", "--config", config.path])
  #expect(result.exitCode == 2)
  #expect(spy.calls == 0)
}

@Test func invalidGoogleAdsInputDoesNotResolveCredentials() async throws {
  let root = try cliTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"ads","product":"google-ads","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"TOKEN","developerTokenEnvironmentVariable":"DEV"}]}"#.utf8).write(to: config)
  let spy = CredentialSpy()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, credentialResolver: spy).run(arguments: ["google-ads", "search", "--customer-id", "bad-id", "--query-file", "missing", "--profile", "ads", "--config", config.path])
  #expect(result.exitCode == 2)
  #expect(spy.calls == 0)

  let agency = await GoogleMarketingGatewayCLI(mode: .reader, credentialResolver: spy).run(arguments: [
    "google-ads", "customer-users", "list", "--customer-id", "bad-id", "--profile", "ads", "--config", config.path
  ])
  #expect(agency.exitCode == 2)
  #expect(spy.calls == 0)
}

@Test func everyNewReaderRouteDispatches() async throws {
  let root = try cliTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let query = root.appendingPathComponent("query.sql"); try Data("SELECT customer.id FROM customer".utf8).write(to: query)
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"ads","product":"google-ads","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ADS_TOKEN","developerTokenEnvironmentVariable":"ADS_DEV"},{"id":"analytics","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"AN_TOKEN"}]}"#.utf8).write(to: config)
  let transport = NewRouteTransport()
  let cli = GoogleMarketingGatewayCLI(mode: .reader, transport: transport)
  let cases = [
    ["google-ads", "accessible-customers", "list", "--profile", "ads"],
    ["google-ads", "search", "--customer-id", "123", "--query-file", query.path, "--profile", "ads"],
    ["google-ads", "customer-client-links", "list", "--customer-id", "123", "--page-token", "next", "--profile", "ads"],
    ["google-ads", "customer-clients", "list", "--customer-id", "123", "--profile", "ads"],
    ["google-ads", "customer-users", "list", "--customer-id", "123", "--profile", "ads"],
    ["analytics-data", "metadata", "get", "--property", "properties/123", "--profile", "analytics"],
    ["analytics-data", "reports", "run", "--property", "properties/123", "--start-date", "2026-08-01", "--end-date", "2026-08-02", "--metrics", "activeUsers", "--profile", "analytics"],
    ["analytics-data", "compatibility", "check", "--property", "properties/123", "--metrics", "activeUsers", "--profile", "analytics"]
  ]
  for arguments in cases {
    let result = await cli.run(arguments: arguments + ["--config", config.path], environment: ["ADS_TOKEN": "token", "ADS_DEV": "developer", "AN_TOKEN": "token"])
    #expect(result.exitCode == 0)
  }
  #expect(transport.requests.map { $0.url?.absoluteString } == [
    "https://googleads.googleapis.com/v25/customers:listAccessibleCustomers",
    "https://googleads.googleapis.com/v25/customers/123/googleAds:search",
    "https://googleads.googleapis.com/v25/customers/123/googleAds:search",
    "https://googleads.googleapis.com/v25/customers/123/googleAds:search",
    "https://googleads.googleapis.com/v25/customers/123/googleAds:search",
    "https://analyticsdata.googleapis.com/v1beta/properties/123/metadata",
    "https://analyticsdata.googleapis.com/v1beta/properties/123:runReport",
    "https://analyticsdata.googleapis.com/v1beta/properties/123:checkCompatibility"
  ])
  #expect(transport.requests.map(\.httpMethod) == ["GET", "POST", "POST", "POST", "POST", "GET", "POST", "POST"])
  #expect(transport.requests[0].value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(transport.requests[1].value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(transport.requests[2].value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(transport.requests[3].value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(transport.requests[4].value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(transport.requests[5...].allSatisfy { $0.value(forHTTPHeaderField: "developer-token") == nil })
}

@Test func profileMismatchAndUnsafeGAQLDoNotTouchCredentialsOrTransport() async throws {
  let root = try cliTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"analytics","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"TOKEN"}]}"#.utf8).write(to: config)
  let spy = CredentialSpy()
  let transport = NewRouteTransport()
  let cli = GoogleMarketingGatewayCLI(mode: .reader, transport: transport, credentialResolver: spy)
  let mismatch = await cli.run(arguments: [
    "google-ads", "accessible-customers", "list", "--profile", "analytics", "--config", config.path
  ])
  #expect(mismatch.exitCode == 2)
  #expect(spy.calls == 0)
  #expect(transport.requests.isEmpty)

  let oversized = root.appendingPathComponent("oversized.sql")
  try Data(repeating: 65, count: 1_048_577).write(to: oversized)
  let invalidFile = await cli.run(arguments: [
    "google-ads", "search", "--customer-id", "123", "--query-file", oversized.path,
    "--profile", "analytics", "--config", config.path
  ])
  #expect(invalidFile.exitCode == 2)
  #expect(spy.calls == 0)
  #expect(transport.requests.isEmpty)
}

@Test func authLoginForwardsBoundedLoopbackOptionsWithoutCredentialResolution() async throws {
  let root = try cliTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  let configuration = """
  {"profiles":[
    {"id":"analytics","product":"analytics-data","capability":"reader",
     "oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],
     "accessTokenEnvironmentVariable":"TOKEN","oauthClientJSONPath":"client.json","tokenStorePath":"token.json"}
  ]}
  """
  try Data(configuration.utf8).write(to: config)
  let auth = AuthManagerSpy()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, authManager: auth).run(
    arguments: ["auth", "login", "--profile", "analytics", "--config", config.path, "--no-browser", "--redirect-uri", "http://127.0.0.1:12345/test", "--timeout-seconds", "12"]
  )
  #expect(result.exitCode == 0)
  #expect(auth.noBrowser)
  #expect(auth.redirectURI == "http://127.0.0.1:12345/test")
  #expect(auth.timeoutSeconds == 12)
}

private final class CredentialSpy: ReaderCredentialResolving, @unchecked Sendable {
  var calls = 0
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String { calls += 1; return "unused" }
}

private final class AuthManagerSpy: ReaderAuthManaging, @unchecked Sendable {
  var noBrowser = false
  var redirectURI: String?
  var timeoutSeconds: Int32?

  func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus {
    ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false, state: "missing", expiresAt: nil, hasRefreshToken: false)
  }

  func logout(profile: CredentialProfile) throws -> Bool { false }

  func login(profile: CredentialProfile, noBrowser: Bool, redirectURI: String?, timeoutSeconds: Int32) throws -> ReaderAuthLoginOutput {
    self.noBrowser = noBrowser
    self.redirectURI = redirectURI
    self.timeoutSeconds = timeoutSeconds
    return ReaderAuthLoginOutput(profileId: profile.id, state: "ready", authorizationURL: nil)
  }
}

private func cliTemporaryDirectory() throws -> URL {
  let base = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"), isDirectory: true)
  let url = base.appendingPathComponent("gateway-cli-test-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
  return url
}
