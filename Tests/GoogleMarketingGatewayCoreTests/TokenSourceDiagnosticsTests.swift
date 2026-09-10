import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func statusAndRequestsUseEnvironmentBeforeMissingTokenFile() throws {
  let profile = CredentialProfile(
    id: "reader", product: .analyticsData, capability: .reader, oauthScopes: ["scope-a"],
    accessTokenEnvironmentVariable: "SELECTED_MARKETING_TOKEN", tokenStorePath: "/missing/marketing-token.json"
  )
  let resolver = ReaderCredentialResolver()
  let environment = ["SELECTED_MARKETING_TOKEN": "local-test-token"]
  let status = resolver.status(profile: profile, environment: environment)
  #expect(status.state == "ready")
  #expect(status.tokenSource == "ENVIRONMENT_TOKEN")
  #expect(status.tokenEnvironmentVariable == "SELECTED_MARKETING_TOKEN")
  #expect(try resolver.accessToken(profile: profile, environment: environment) == "local-test-token")
  do {
    _ = try resolver.accessToken(profile: profile, environment: [:])
    Issue.record("Expected missing token file")
  } catch let error as GatewayError {
    #expect(error.message.contains("tokenSource=FILE"))
    #expect(error.message.contains("/missing/marketing-token.json"))
    #expect(error.message.contains("SELECTED_MARKETING_TOKEN"))
    #expect(!error.message.contains("local-test-token"))
  }
}
