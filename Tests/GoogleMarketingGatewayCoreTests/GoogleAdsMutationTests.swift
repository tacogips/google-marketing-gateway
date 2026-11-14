import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

@Test func searchCampaignRequestIsTypedAtomicAndEnabled() throws {
  let request = try GoogleAdsRequests.createSearchCampaign(
    input: try mutationFixtureInput(), validateOnly: true,
    accessToken: "access", developerToken: "developer", loginCustomerId: "9998887776"
  )
  #expect(request.url?.absoluteString == "https://googleads.googleapis.com/v25/customers/1234567890/googleAds:mutate")
  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "login-customer-id") == "9998887776")
  let bodyData = try #require(request.httpBody)
  let body = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
  #expect(body["validateOnly"] as? Bool == true)
  #expect(body["partialFailure"] as? Bool == false)
  let operations = try #require(body["mutateOperations"] as? [[String: Any]])
  #expect(operations.count == 8)
  #expect(operations.contains { $0["campaignBudgetOperation"] != nil })
  #expect(operations.contains { $0["campaignOperation"] != nil })
  let campaignOperation = try #require(operations.first { $0["campaignOperation"] != nil })
  let campaignOperationBody = try #require(campaignOperation["campaignOperation"] as? [String: Any])
  let campaignCreate = try #require(campaignOperationBody["create"] as? [String: Any])
  #expect(campaignCreate["containsEuPoliticalAdvertising"] as? String == "DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING")
  #expect(operations.filter { $0["campaignCriterionOperation"] != nil }.count == 2)
  #expect(operations.filter { $0["adGroupCriterionOperation"] != nil }.count == 2)
  #expect(operations.contains { $0["adGroupAdOperation"] != nil })
  let bodyText = try #require(String(bytes: bodyData, encoding: .utf8))
  #expect(!bodyText.contains("remove"))
}

@Test func removalRequestContainsOnlyRemoveOperation() throws {
  let name = "customers/1234567890/campaigns/456"
  let request = try GoogleAdsRequests.removeResource(
    customerId: "1234567890", collection: "campaigns", resourceName: name,
    validateOnly: false, accessToken: "access", developerToken: "developer"
  )
  #expect(request.url?.absoluteString == "https://googleads.googleapis.com/v25/customers/1234567890/campaigns:mutate")
  let bodyData = try #require(request.httpBody)
  let body = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
  let operations = try #require(body["operations"] as? [[String: Any]])
  #expect(operations.count == 1)
  #expect(operations[0]["remove"] as? String == name)
  #expect(body["validateOnly"] as? Bool == false)
}

@Test func managerLinkRequestsUseAccountSpecificLoginHeaders() throws {
  let invitation = try GoogleAdsRequests.inviteManagerLink(
    managerCustomerId: "3827004490", clientCustomerId: "9708882574",
    validateOnly: true, accessToken: "access", developerToken: "developer"
  )
  #expect(invitation.url?.path == "/v25/customers/3827004490/customerClientLinks:mutate")
  #expect(invitation.value(forHTTPHeaderField: "login-customer-id") == "3827004490")
  let invitationBody = try #require(invitation.httpBody)
  let invitationJSON = try #require(try JSONSerialization.jsonObject(with: invitationBody) as? [String: Any])
  #expect(invitationJSON["validateOnly"] as? Bool == true)
  let operation = try #require(invitationJSON["operation"] as? [String: Any])
  let create = try #require(operation["create"] as? [String: Any])
  #expect(create["clientCustomer"] as? String == "customers/9708882574")
  #expect(create["status"] as? String == "PENDING")

  let acceptance = try GoogleAdsRequests.acceptManagerLink(
    clientCustomerId: "9708882574", managerCustomerId: "3827004490",
    managerLinkId: "123", validateOnly: false,
    accessToken: "access", developerToken: "developer"
  )
  #expect(acceptance.url?.path == "/v25/customers/9708882574/customerManagerLinks:mutate")
  #expect(acceptance.value(forHTTPHeaderField: "login-customer-id") == "9708882574")
  let acceptanceBody = try #require(acceptance.httpBody)
  let acceptanceJSON = try #require(try JSONSerialization.jsonObject(with: acceptanceBody) as? [String: Any])
  let operations = try #require(acceptanceJSON["operations"] as? [[String: Any]])
  let update = try #require(operations[0]["update"] as? [String: Any])
  #expect(update["resourceName"] as? String == "customers/9708882574/customerManagerLinks/3827004490~123")
  #expect(update["status"] as? String == "ACTIVE")
  #expect(operations[0]["updateMask"] as? String == "status")
}

@Test func writerAndDeleterAreMutuallyIsolated() async throws {
  let fixture = try mutationFixtureFiles()
  defer { try? FileManager.default.removeItem(at: fixture.root) }
  let transport = MutationCapturingTransport()
  let writer = GoogleMarketingGatewayCLI(mode: .writer, transport: transport)
  let deleter = GoogleMarketingGatewayCLI(mode: .deleter, transport: transport)
  let environment = [
    "ADS_ACCESS": "access", "ADS_DEVELOPER": "developer", "ADS_LOGIN": "9998887776"
  ]

  let writerRemoval = await writer.run(arguments: ["google-ads", "campaigns", "remove", "plan"])
  #expect(writerRemoval.exitCode == 2)
  #expect(writerRemoval.stderr.contains("FORBIDDEN_CAPABILITY"))
  for mode in [GatewayMode.reader, .admin] {
    let result = await GoogleMarketingGatewayCLI(mode: mode, transport: transport).run(
      arguments: ["google-ads", "campaigns", "remove", "plan"]
    )
    #expect(result.exitCode == 2)
  }
  let deleterCreate = await deleter.run(arguments: ["google-ads", "search-campaigns", "create", "plan"])
  #expect(deleterCreate.exitCode == 2)

  let plan = await writer.run(arguments: [
    "google-ads", "search-campaigns", "create", "plan",
    "--request-file", fixture.input.path, "--profile", "ads-writer", "--config", fixture.config.path
  ], environment: environment)
  #expect(plan.exitCode == 0, "\(plan.stderr)")
  #expect(plan.stdout.contains("\"requestSent\" : false"))
  #expect(await transport.requests().isEmpty)

  let removalPlan = await deleter.run(arguments: [
    "google-ads", "campaigns", "remove", "plan", "--customer-id", "1234567890",
    "--resource-name", "customers/1234567890/campaigns/456",
    "--profile", "ads-deleter", "--config", fixture.config.path
  ], environment: environment)
  #expect(removalPlan.exitCode == 0)
  #expect(removalPlan.stdout.contains("status REMOVED"))
  #expect(await transport.requests().isEmpty)
}

@Test func validateUsesProviderValidateOnlyAndApplyRequiresExactConfirmation() async throws {
  let fixture = try mutationFixtureFiles()
  defer { try? FileManager.default.removeItem(at: fixture.root) }
  let transport = MutationCapturingTransport()
  let environment = [
    "ADS_ACCESS": "access", "ADS_DEVELOPER": "developer", "ADS_LOGIN": "9998887776"
  ]
  let cli = GoogleMarketingGatewayCLI(mode: .writer, transport: transport)
  let base = [
    "google-ads", "search-campaigns", "create", "validate",
    "--request-file", fixture.input.path, "--profile", "ads-writer", "--config", fixture.config.path
  ]
  let validation = await cli.run(arguments: base, environment: environment)
  #expect(validation.exitCode == 0, "\(validation.stderr)")
  let validationRequest = try #require(await transport.requests().last)
  let validationData = try #require(validationRequest.httpBody)
  let validationBody = try #require(try JSONSerialization.jsonObject(with: validationData) as? [String: Any])
  #expect(validationBody["validateOnly"] as? Bool == true)

  var apply = base
  apply[3] = "apply"
  let rejected = await cli.run(arguments: apply, environment: environment)
  #expect(rejected.exitCode == 2)
  #expect((await transport.requests()).count == 1)
}

@Test func googleAdsProfilesSupportWriterAndDeleterWithoutCrossCapabilityUse() throws {
  let data = Data("""
  {"profiles":[
    {"id":"writer","product":"google-ads","capability":"writer","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ACCESS","developerTokenEnvironmentVariable":"DEVELOPER"},
    {"id":"deleter","product":"google-ads","capability":"deleter","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ACCESS","developerTokenEnvironmentVariable":"DEVELOPER"}
  ]}
  """.utf8)
  let config = try CredentialProfileConfiguration.decode(data)
  #expect(try config.profile(id: "writer").capability == .writer)
  #expect(try config.profile(id: "deleter").capability == .deleter)
}

@Test func searchCampaignAcceptsRealisticJPYBudgetWithinSafetyCap() throws {
  let input = try JSONDecoder().decode(GoogleAdsSearchCampaignInput.self, from: Data("""
  {
    "customerId":"1234567890",
    "campaignName":"JPY budget verification",
    "dailyBudgetMicros":269000000,
    "adGroupName":"JPY budget verification",
    "cpcBidMicros":100000000,
    "geoTargetConstantId":"2392",
    "languageConstantId":"1005",
    "keywords":[{"text":"swift developer","matchType":"EXACT"}],
    "headlines":["Swift Development Help","Freelance Swift Developer","Build Reliable Swift Apps"],
    "descriptions":["Get practical Swift development support for your product and team.","From planning through delivery, get focused engineering assistance."],
    "finalUrls":["https://example.com/swift-development"]
  }
  """.utf8))

  try input.validate()
}

private actor MutationCapturingTransport: HTTPTransport {
  private var captured: [URLRequest] = []
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    captured.append(request)
    guard let url = request.url,
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
      throw GatewayError("Invalid test request", code: .invalidResponse)
    }
    return (Data("{\"results\":[]}".utf8), response)
  }
  func requests() -> [URLRequest] { captured }
}

private func mutationFixtureInput() throws -> GoogleAdsSearchCampaignInput {
  try JSONDecoder().decode(GoogleAdsSearchCampaignInput.self, from: Data("""
  {
    "customerId":"1234567890",
    "campaignName":"Gateway verification",
    "dailyBudgetMicros":1000000,
    "adGroupName":"Gateway verification",
    "cpcBidMicros":250000,
    "geoTargetConstantId":"2392",
    "languageConstantId":"1005",
    "keywords":[
      {"text":"swift api gateway","matchType":"EXACT"},
      {"text":"marketing gateway","matchType":"PHRASE"}
    ],
    "headlines":["Swift Marketing Gateway","Typed Google Ads Control","Safe Campaign Operations"],
    "descriptions":[
      "Manage Google marketing operations with a typed Swift command line tool.",
      "Separate reading, writing, and removal with explicit capabilities."
    ],
    "finalUrls":["https://example.com/google-marketing-gateway"]
  }
  """.utf8))
}

private struct MutationFixtureFiles {
  let root: URL
  let config: URL
  let input: URL
}

private func mutationFixtureFiles() throws -> MutationFixtureFiles {
  let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".build/google-ads-mutation-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  let config = root.appendingPathComponent("profiles.json")
  let input = root.appendingPathComponent("campaign.json")
  try Data("""
  {"profiles":[
    {"id":"ads-writer","product":"google-ads","capability":"writer",
     "oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ADS_ACCESS",
     "developerTokenEnvironmentVariable":"ADS_DEVELOPER","loginCustomerIdEnvironmentVariable":"ADS_LOGIN"},
    {"id":"ads-deleter","product":"google-ads","capability":"deleter",
     "oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ADS_ACCESS",
     "developerTokenEnvironmentVariable":"ADS_DEVELOPER","loginCustomerIdEnvironmentVariable":"ADS_LOGIN"}
  ]}
  """.utf8).write(to: config)
  let encoded = try JSONEncoder().encode(mutationFixtureInput())
  try encoded.write(to: input)
  return MutationFixtureFiles(root: root, config: config, input: input)
}
