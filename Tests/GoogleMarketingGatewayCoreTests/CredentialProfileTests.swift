import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func profileFixtureDefinesProductIsolatedReaders() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: profileFixturePath))
  let configuration = try CredentialProfileConfiguration.decode(data)
  #expect(configuration.profiles.count == 3)
  #expect(try configuration.profile(id: "adsense-reader").product == .adsense)
  #expect(try configuration.profile(id: "admob-reader").product == .admob)
  #expect(try configuration.profile(id: "admob-report-reader").oauthScopes == [admobReportScope])
}

@Test(arguments: [
  profileJSON(id: "duplicate", product: "adsense", capability: "reader", scopes: [adsenseScope], tokenEnvironment: "ADSENSE_TOKEN")
    + "," + profileJSON(id: "duplicate", product: "admob", capability: "reader", scopes: [admobScope], tokenEnvironment: "ADMOB_TOKEN"),
  profileJSON(id: "wrong-scope", product: "adsense", capability: "reader", scopes: [admobScope], tokenEnvironment: "ADSENSE_TOKEN"),
  profileJSON(id: "writer", product: "adsense", capability: "writer", scopes: [adsenseScope], tokenEnvironment: "ADSENSE_TOKEN"),
  profileJSON(id: "admin", product: "admob", capability: "admin", scopes: [admobScope], tokenEnvironment: "ADMOB_TOKEN"),
  profileJSON(id: "unsafe-env", product: "adsense", capability: "reader", scopes: [adsenseScope], tokenEnvironment: "TOKEN;PRINT_SECRET")
])
func profileValidationRejectsUnsafeConfigurations(_ profilesJSON: String) {
  let data = Data("{\"profiles\":[\(profilesJSON)]}".utf8)
  #expect(throws: GatewayError.self) {
    _ = try CredentialProfileConfiguration.decode(data)
  }
}

@Test func profileConfigurationRejectsUnknownRootFields() {
  let profile = profileJSON(id: "reader", product: "adsense", capability: "reader", scopes: [adsenseScope], tokenEnvironment: "ADSENSE_TOKEN")
  let data = Data("{\"profiles\":[\(profile)],\"unexpected\":true}".utf8)
  #expect(throws: GatewayError.self) {
    _ = try CredentialProfileConfiguration.decode(data)
  }
}

@Test func profileLoadResolvesOAuthPathsRelativeToConfigAndRejectsCollisions() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("profile-resolution-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  let profile = "{\"id\":\"reader\",\"product\":\"analytics-data\",\"capability\":\"reader\",\"oauthScopes\":[\"https://www.googleapis.com/auth/analytics.readonly\"],\"accessTokenEnvironmentVariable\":\"AN_TOKEN\",\"oauthClientJSONPath\":\"client.json\",\"tokenStorePath\":\"token.json\"}"
  try Data("{\"profiles\":[\(profile)]}".utf8).write(to: config)
  let loaded = try CredentialProfileConfiguration.load(path: config.path).profiles[0]
  #expect(loaded.oauthClientJSONPath == root.appendingPathComponent("client.json").path)
  #expect(loaded.tokenStorePath == root.appendingPathComponent("token.json").path)
  try Data("{\"profiles\":[\(profile.replacingOccurrences(of: "token.json", with: "client.json"))]}".utf8).write(to: config)
  #expect(throws: GatewayError.self) { _ = try CredentialProfileConfiguration.load(path: config.path) }
}

private func profileJSON(
  id: String,
  product: String,
  capability: String,
  scopes: [String],
  tokenEnvironment: String
) -> String {
  let scopesJSON = scopes.map { "\"\($0)\"" }.joined(separator: ",")
  return """
  {"id":"\(id)","product":"\(product)","capability":"\(capability)","oauthScopes":[\(scopesJSON)],"accessTokenEnvironmentVariable":"\(tokenEnvironment)"}
  """
}

private let adsenseScope = "https://www.googleapis.com/auth/adsense.readonly"
private let admobScope = "https://www.googleapis.com/auth/admob.readonly"
private let admobReportScope = "https://www.googleapis.com/auth/admob.report"
private let profileFixturePath = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .appendingPathComponent("Fixtures/reader-profiles.json")
  .path
