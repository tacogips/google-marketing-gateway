import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

@Test func canonicalMarketingAccessTokenWorksWithoutOAuthClient() throws {
  let profile = marketingTestProfile()
  let resolver = ReaderCredentialResolver()
  #expect(try resolver.accessToken(profile: profile, environment: [
    "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "external-token"
  ]) == "external-token")
  #expect(resolver.status(profile: profile, environment: [
    "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "external-token"
  ]).state == "ready")
  #expect(try resolver.accessToken(profile: profile, environment: ["LEGACY_TOKEN": "legacy-token"]) == "legacy-token")
}

@Test func marketingProfileOverrideAndConflictingAliases() throws {
  let profile = marketingTestProfile()
  let resolver = ReaderCredentialResolver()
  #expect(try resolver.accessToken(profile: profile, environment: [
    "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "global",
    "GOOGLE_MARKETING_GATEWAY_CREDENTIAL_ADS_ACCESS_TOKEN": "selected"
  ]) == "selected")
  do {
    _ = try resolver.accessToken(profile: profile, environment: [
      "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "canonical-secret", "LEGACY_TOKEN": "legacy-secret"
    ])
    Issue.record("Expected conflicting credential inputs to fail")
  } catch let error as GatewayError {
    #expect(error.code == .invalidConfiguration)
    #expect(!error.message.contains("canonical-secret"))
    #expect(!error.message.contains("legacy-secret"))
  }
  #expect(throws: GatewayError.self) {
    _ = try resolver.accessToken(profile: profile, environment: [
      "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "token",
      "GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_PATH": "/unused/token.json"
    ])
  }
}

@Test func marketingExternalTokenJSONRetainsProfileAndScopeChecks() throws {
  let profile = marketingTestProfile()
  let token = try OAuthToken(profile: profile, accessToken: "external-json-token", refreshToken: nil,
                             tokenType: "Bearer", expiry: Date().addingTimeInterval(3600), scopes: profile.oauthScopes)
  let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
  let json = try #require(String(data: encoder.encode(token), encoding: .utf8))
  let environment = ["GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_JSON": json]
  let resolver = ReaderCredentialResolver()
  #expect(try resolver.accessToken(profile: profile, environment: environment) == "external-json-token")
  #expect(resolver.status(profile: profile, environment: environment).tokenSource == "ENVIRONMENT_JSON")
  #expect(throws: GatewayError.self) {
    _ = try resolver.accessToken(profile: marketingTestProfile(id: "other"), environment: environment)
  }
}

@Test func marketingExternalTokenPathNeedsNoClientAndStatusUsesSelectedPath() throws {
  let root = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"))
    .appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  let path = root.appendingPathComponent("token.json").path
  let profile = marketingTestProfile()
  let token = try OAuthToken(profile: profile, accessToken: "path-token", refreshToken: nil,
                             tokenType: "Bearer", expiry: Date().addingTimeInterval(3600), scopes: profile.oauthScopes)
  try OAuthTokenStore().write(token, path: path, profile: profile)
  let env = ["GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_PATH": path]
  let resolver = ReaderCredentialResolver()
  #expect(try resolver.accessToken(profile: profile, environment: env) == "path-token")
  #expect(resolver.status(profile: profile, environment: env).tokenStorePath == path)
  #expect(resolver.status(profile: profile, environment: env).state == "ready")
}

@Test func allMarketingModesRouteLoginToMatchingProfile() async throws {
  let root = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"))
    .appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  for mode in [GatewayMode.reader, .writer, .admin, .deleter] {
    let configuration = try CredentialProfileConfiguration(profiles: [marketingTestProfile(capability: mode)])
    let path = root.appendingPathComponent("\(mode.rawValue).json")
    try JSONEncoder().encode(configuration).write(to: path)
    let auth = MarketingAuthCapture()
    let cli = GoogleMarketingGatewayCLI(mode: mode, authManager: auth)
    let result = await cli.run(arguments: ["auth", "login", "--config", path.path], environment: [:])
    #expect(result.exitCode == 0)
    #expect(auth.profile?.capability == mode)
    #expect(cli.usage.contains("auth login"))
    if mode != .reader {
      let wrong = await GoogleMarketingGatewayCLI(mode: .reader, authManager: auth).run(
        arguments: ["auth", "login", "--profile", "ads", "--config", path.path], environment: [:]
      )
      #expect(wrong.stderr.contains("FORBIDDEN_CAPABILITY"))
    }
  }
}

@Test func marketingProfileNormalizationRejectsCollisions() throws {
  #expect(throws: GatewayError.self) {
    _ = try CredentialProfileConfiguration(profiles: [marketingTestProfile(id: "work-mail"), marketingTestProfile(id: "work_mail")])
  }
  _ = try CredentialProfileConfiguration(profiles: [CredentialProfile(
    id: "external", product: .googleAds, capability: .reader,
    oauthScopes: ["https://www.googleapis.com/auth/adwords"], accessTokenEnvironmentVariable: "TOKEN",
    tokenStorePath: "/unused/token.json", developerTokenEnvironmentVariable: "DEVELOPER"
  )])
}

private func marketingTestProfile(id: String = "ads", capability: GatewayMode = .reader) -> CredentialProfile {
  CredentialProfile(id: id, product: .googleAds, capability: capability,
                    oauthScopes: ["https://www.googleapis.com/auth/adwords"], accessTokenEnvironmentVariable: "LEGACY_TOKEN",
                    developerTokenEnvironmentVariable: "LEGACY_DEVELOPER")
}

private final class MarketingAuthCapture: ReaderAuthManaging, @unchecked Sendable {
  var profile: CredentialProfile?
  func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus {
    ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                     state: "missing", expiresAt: nil, hasRefreshToken: false)
  }
  func logout(profile: CredentialProfile) throws -> Bool { false }
  func login(profile: CredentialProfile, noBrowser: Bool, redirectURI: String?, timeoutSeconds: Int32) throws -> ReaderAuthLoginOutput {
    self.profile = profile
    return ReaderAuthLoginOutput(profileId: profile.id, state: "ready", authorizationURL: nil)
  }
}

@Test func marketingOrdinaryRequestUsesCanonicalCredentialsWithoutLogin() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("profiles.json")
  let configuration = try CredentialProfileConfiguration(profiles: [marketingTestProfile()])
  try JSONEncoder().encode(configuration).write(to: path)
  let auth = MarketingAuthCapture()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: MarketingExternalTokenTransport(), authManager: auth).run(
    arguments: ["google-ads", "accessible-customers", "list", "--profile", "ads", "--config", path.path],
    environment: ["GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "external-token",
                  "GOOGLE_MARKETING_GATEWAY_DEVELOPER_TOKEN": "external-developer"]
  )
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("customers/123"))
  #expect(auth.profile == nil)
  #expect(!result.stdout.contains("external-token"))
  #expect(!result.stderr.contains("external-token"))
}

private struct MarketingExternalTokenTransport: HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer external-token")
    #expect(request.value(forHTTPHeaderField: "developer-token") == "external-developer")
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    return (Data(#"{"resourceNames":["customers/123"]}"#.utf8), response)
  }
}

@Test func marketingProfileSourcesReplaceProductDefaultsAcrossInputTypes() throws {
  let profile = marketingTestProfile()
  let environment = [
    "GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_PATH": "/unused/default-token.json",
    "GOOGLE_MARKETING_GATEWAY_CREDENTIAL_ADS_ACCESS_TOKEN": "selected-token",
    "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_PATH": "/unused/default-client.json",
    "GOOGLE_MARKETING_GATEWAY_CREDENTIAL_ADS_OAUTH_CLIENT_JSON": "inline-application"
  ]
  let input = try MarketingCredentialInput(profile: profile, environment: environment)
  #expect(input.accessToken == "selected-token")
  #expect(input.tokenStorePath == nil)
  let selected = try marketingProfilePaths(profile, environment: environment)
  #expect(selected.oauthClientJSON == "inline-application")
  #expect(selected.oauthClientJSONPath == nil)
}
