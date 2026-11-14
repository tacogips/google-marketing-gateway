import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

@Test func marketingLoginSelectsDefaultRoleProfilesWithoutConfiguration() async throws {
  let root = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"))
    .appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  for mode in GatewayMode.allCases {
    let capture = DefaultAuthCapture()
    let result = await GoogleMarketingGatewayCLI(mode: mode, authManager: capture).run(arguments: ["auth", "login"], environment: ["XDG_STATE_HOME": root.path])
    #expect(result.exitCode == 0)
    let selected = try #require(capture.profile)
    #expect(selected.product == .googleAds)
    #expect(selected.capability == mode)
    #expect(selected.id == "google-ads-" + mode.rawValue)
    #expect(selected.oauthScopes == [GoogleAdsMutationSupport.scope])
    #expect(selected.tokenStorePath?.contains("/google-ads/" + mode.rawValue + "/") == true)
    #expect(!FileManager.default.fileExists(atPath: root.path))
    let ordinary = try MarketingDefaultCredentials.profile(product: .googleAds, capability: mode, flags: [:], environment: ["XDG_STATE_HOME": root.path])
    #expect(ordinary == selected)
  }
}

@Test func marketingDefaultProfilesSupportImplementedProductsAndRejectUnsupportedRoles() throws {
  for product in [MarketingProduct.googleAds, .admob, .adsense, .searchConsole, .analyticsData] {
    let profile = try MarketingDefaultCredentials.profile(product: product, capability: .reader, flags: [:], environment: [:])
    #expect(profile.oauthScopes == product.readerOAuthScopes)
  }
  #expect(try MarketingDefaultCredentials.profile(product: .admob, capability: .writer, flags: [:], environment: [:]).oauthScopes
          == ["https://www.googleapis.com/auth/admob.monetization"])
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .analyticsData, capability: .writer, flags: [:], environment: [:])
  }
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .youtubeData, capability: .reader, flags: [:], environment: [:])
  }
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .googleAds, capability: .reader, flags: ["profile": "../escape"], environment: [:])
  }
}

@Test func marketingDefaultReaderUsesExternalCredentialsWithoutConfigOrLogin() async {
  let auth = DefaultAuthCapture()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: DefaultCredentialTransport(), authManager: auth).run(
    arguments: ["google-ads", "accessible-customers", "list"],
    environment: ["GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN": "external-token", "GOOGLE_MARKETING_GATEWAY_DEVELOPER_TOKEN": "external-developer"]
  )
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("customers/123"))
  #expect(auth.profile == nil)
}

@Test func marketingExplicitConfigNeverFallsBackToDefaultCredentials() throws {
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .googleAds, capability: .reader,
                                                 flags: ["config": "/nonexistent/explicit-config.json"], environment: [:])
  }
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .googleAds, capability: .reader, flags: [:],
                                                 environment: ["XDG_STATE_HOME": "relative/path"])
  }
  #expect(throws: GatewayError.self) {
    _ = try MarketingDefaultCredentials.profile(product: .googleAds, capability: .reader, flags: [:], environment: [
      "GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_PATH": "/private/tmp/shared.json",
      "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_PATH": "/private/tmp/shared.json"
    ])
  }
}

private final class DefaultAuthCapture: ReaderAuthManaging, @unchecked Sendable {
  var profile: CredentialProfile?
  func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus {
    ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false, state: "missing", expiresAt: nil, hasRefreshToken: false)
  }
  func logout(profile: CredentialProfile) throws -> Bool { false }
  func login(profile: CredentialProfile, noBrowser: Bool, redirectURI: String?, timeoutSeconds: Int32) throws -> ReaderAuthLoginOutput {
    self.profile = profile
    return ReaderAuthLoginOutput(profileId: profile.id, state: "ready", authorizationURL: nil)
  }
}

private struct DefaultCredentialTransport: HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer external-token")
    #expect(request.value(forHTTPHeaderField: "developer-token") == "external-developer")
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    return (Data(#"{"resourceNames":["customers/123"]}"#.utf8), response)
  }
}

@Test func marketingDefaultBrowserLoginStoresCredentialUsedByOrdinaryRequest() async throws {
  let root = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"))
    .appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let application = #"{"installed":{"client_id":"marketing-default","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[]}}"#
  let environment = ["XDG_STATE_HOME": root.path, "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_JSON": application]
  let service = ReaderAuthService(oauth: OAuthClient(http: DefaultLoginHTTP()), openURL: { url in
    #expect(url.host == "accounts.google.com")
    return true
  }, makeReceiver: { _ in DefaultLoginReceiver() }, randomString: { String(repeating: "s", count: $0) })
  let login = await GoogleMarketingGatewayCLI(mode: .reader, authManager: service).run(arguments: ["auth", "login"], environment: environment)
  #expect(login.exitCode == 0)
  let profile = try MarketingDefaultCredentials.profile(product: .googleAds, capability: .reader, flags: [:], environment: environment)
  let path = try #require(profile.tokenStorePath)
  #expect(try OAuthTokenStore().read(path: path, profile: profile).accessToken == "external-token")
  var ordinaryEnvironment = ["XDG_STATE_HOME": root.path]
  ordinaryEnvironment["GOOGLE_MARKETING_GATEWAY_DEVELOPER_TOKEN"] = "external-developer"
  let ordinary = await GoogleMarketingGatewayCLI(mode: .reader, transport: DefaultCredentialTransport()).run(
    arguments: ["google-ads", "accessible-customers", "list"], environment: ordinaryEnvironment)
  #expect(ordinary.exitCode == 0)
  #expect(ordinary.stdout.contains("customers/123"))
  #expect(!ordinary.stdout.contains("external-token"))
}

private struct DefaultLoginReceiver: OAuthLoopbackReceiving {
  let redirectURI = "http://127.0.0.1:12345/oauth2callback"
  func waitForCode(expectedState: String, timeoutSeconds: Int32) throws -> String { "authorization-code" }
}

private struct DefaultLoginHTTP: OAuthHTTPHandling {
  func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    #expect(request.url?.absoluteString == OAuthDesktopClient.tokenEndpoint)
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    return (Data(#"{"access_token":"external-token","refresh_token":"refresh-token","token_type":"Bearer","expires_in":3600,"scope":"https://www.googleapis.com/auth/adwords"}"#.utf8), response)
  }
}

@Test func marketingConfiguredAuthRejectsTokenDestinationEqualToConfig() async throws {
  let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  defer { try? FileManager.default.removeItem(at: root) }
  let profile = CredentialProfile(id: "ads", product: .googleAds, capability: .reader, oauthScopes: [GoogleAdsMutationSupport.scope],
                                  accessTokenEnvironmentVariable: "LEGACY_TOKEN", developerTokenEnvironmentVariable: "LEGACY_DEVELOPER")
  let configPath = root.appendingPathComponent("profiles.json")
  try JSONEncoder().encode(CredentialProfileConfiguration(profiles: [profile])).write(to: configPath)
  let before = try Data(contentsOf: configPath)
  let capture = DefaultAuthCapture()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, authManager: capture).run(
    arguments: ["auth", "login", "--config", configPath.path],
    environment: ["GOOGLE_MARKETING_GATEWAY_TOKEN_STORE_PATH": configPath.path])
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("Token-store path must differ"))
  #expect(capture.profile == nil)
  #expect(try Data(contentsOf: configPath) == before)
}
