import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

private let inlineClientJSON = #"{"installed":{"client_id":"inline-client","client_secret":"private-app-value","auth_uri":"https://accounts.google.com/o/oauth2/v2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":[]}}"#

@Test func marketingInlineApplicationSelectionAndEncoding() throws {
  let profile = inlineClientProfile(path: "/private/tmp/unused-token.json")
  let selected = try marketingProfilePaths(profile, environment: ["GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_JSON": inlineClientJSON])
  #expect(selected.oauthClientJSON == inlineClientJSON)
  #expect(selected.oauthClientJSONPath == nil)
  #expect(try OAuthClient().loadClient(profile: selected).clientId == "inline-client")
  let encoded = try #require(String(data: JSONEncoder().encode(selected), encoding: .utf8))
  #expect(!encoded.contains("private-app-value"))
  #expect(!encoded.contains("inline-client"))
  #expect(throws: GatewayError.self) {
    _ = try marketingProfilePaths(profile, environment: [
      "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_JSON": inlineClientJSON,
      "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_PATH": "/unused/client.json"
    ])
  }
}

@Test func marketingInlineApplicationLoginAndRefreshUseNoClientFile() throws {
  let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("token.json").path
  let profile = try marketingProfilePaths(inlineClientProfile(path: path), environment: [
    "GOOGLE_MARKETING_GATEWAY_OAUTH_CLIENT_JSON": inlineClientJSON
  ])
  let client = OAuthClient(http: InlineClientHTTP())
  let auth = ReaderAuthService(oauth: client, openURL: { _ in true },
    makeReceiver: { _ in InlineClientReceiver() }, randomString: { String(repeating: "s", count: $0) })
  #expect(try auth.login(profile: profile, noBrowser: false, redirectURI: nil, timeoutSeconds: 1).state == "ready")
  #expect(try OAuthTokenStore().read(path: path, profile: profile).accessToken == "new-token")
  let expired = try OAuthToken(profile: profile, accessToken: "old-token", refreshToken: "old-refresh", tokenType: "Bearer",
    expiry: Date().addingTimeInterval(-1), scopes: profile.oauthScopes)
  try OAuthTokenStore().write(expired, path: path, profile: profile)
  #expect(try ReaderCredentialResolver(refresher: client).accessToken(profile: profile, environment: [:]) == "new-token")
  #expect(try OAuthTokenStore().read(path: path, profile: profile).accessToken == "new-token")
}

@Test func marketingInvalidInlineApplicationErrorDoesNotRevealJSON() throws {
  do {
    _ = try OAuthClient().loadClient(json: "private-invalid-json")
    Issue.record("Expected invalid client to fail")
  } catch let error as GatewayError {
    #expect(!error.message.contains("private-invalid-json"))
  }
}

private func inlineClientProfile(path: String) -> CredentialProfile {
  CredentialProfile(id: "inline", product: .analyticsData, capability: .reader,
    oauthScopes: ["scope-a"], accessTokenEnvironmentVariable: "INLINE_TOKEN",
    tokenStorePath: path)
}

private struct InlineClientReceiver: OAuthLoopbackReceiving {
  let redirectURI = "http://127.0.0.1:12345/oauth2callback"
  func waitForCode(expectedState: String, timeoutSeconds: Int32) throws -> String { "code" }
}

private struct InlineClientHTTP: OAuthHTTPHandling {
  func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    #expect(request.url?.absoluteString == OAuthDesktopClient.tokenEndpoint)
    #expect(String(data: request.httpBody ?? Data(), encoding: .utf8)?.removingPercentEncoding?.contains("client_id=inline-client") == true)
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    return (Data(#"{"access_token":"new-token","refresh_token":"new-refresh","token_type":"Bearer","expires_in":3600,"scope":"scope-a"}"#.utf8), response)
  }
}
