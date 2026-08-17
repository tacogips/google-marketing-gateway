import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

@Test func keywordIdeasRequestUsesTypedBoundedSeed() throws {
  let input = GoogleAdsKeywordIdeasInput(
    customerId: "9708882574",
    languageConstantId: "1005",
    geoTargetConstantIds: ["2392"],
    keywords: ["instant translation", "screen ocr"],
    url: "https://konjac-note.com/",
    pageSize: 100
  )
  let request = try GoogleAdsRequests.generateKeywordIdeas(
    input: input, accessToken: "access", developerToken: "developer",
    loginCustomerId: "9708882574"
  )
  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://googleads.googleapis.com/v25/customers/9708882574:generateKeywordIdeas")
  #expect(request.value(forHTTPHeaderField: "login-customer-id") == "9708882574")
  let body = try requestJSON(request)
  #expect(body["language"] as? String == "languageConstants/1005")
  #expect(body["geoTargetConstants"] as? [String] == ["geoTargetConstants/2392"])
  #expect(body["keywordPlanNetwork"] as? String == "GOOGLE_SEARCH")
  #expect(body["includeAdultKeywords"] as? Bool == false)
  #expect(body["pageSize"] as? Int == 100)
  let seed = try #require(body["keywordAndUrlSeed"] as? [String: Any])
  #expect(seed["keywords"] as? [String] == ["instant translation", "screen ocr"])
  #expect(seed["url"] as? String == "https://konjac-note.com/")
  #expect(body["keywordSeed"] == nil)
  #expect(body["urlSeed"] == nil)
}

@Test func customerAccountRequestUsesManagerHeaderAndNoMutationEnvelope() throws {
  let input = GoogleAdsCustomerAccountInput(
    managerCustomerId: "3827004490",
    descriptiveName: "Konjac Note Ads",
    currencyCode: "JPY",
    timeZone: "Asia/Tokyo"
  )
  let request = try GoogleAdsRequests.createCustomerClient(
    input: input, accessToken: "access", developerToken: "developer"
  )
  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://googleads.googleapis.com/v25/customers/3827004490:createCustomerClient")
  #expect(request.value(forHTTPHeaderField: "login-customer-id") == "3827004490")
  let body = try requestJSON(request)
  let customer = try #require(body["customerClient"] as? [String: Any])
  #expect(customer["descriptiveName"] as? String == "Konjac Note Ads")
  #expect(customer["currencyCode"] as? String == "JPY")
  #expect(customer["timeZone"] as? String == "Asia/Tokyo")
  #expect(body["operations"] == nil)
  #expect(body["validateOnly"] == nil)
}

@Test func planningInputsRejectUnsafeOrUnboundedValues() {
  #expect(throws: GatewayError.self) {
    try GoogleAdsKeywordIdeasInput(
      customerId: "9708882574", languageConstantId: "1005",
      geoTargetConstantIds: ["2392"], keywords: [],
      url: "http://konjac-note.com/", pageSize: 100
    ).validate()
  }
  #expect(throws: GatewayError.self) {
    try GoogleAdsCustomerAccountInput(
      managerCustomerId: "3827004490", descriptiveName: "Konjac Note Ads",
      currencyCode: "jpy", timeZone: "Asia/Tokyo"
    ).validate()
  }
}

@Test func accountCreationPlanIsLocalAndApplyRequiresConfirmation() async throws {
  let fixture = try planningFixture()
  defer { try? FileManager.default.removeItem(at: fixture.root) }
  let transport = PlanningCapturingTransport()
  let cli = GoogleMarketingGatewayCLI(mode: .admin, transport: transport)
  let environment = ["ADS_ACCESS": "access", "ADS_DEVELOPER": "developer", "ADS_LOGIN": "3827004490"]
  let base = [
    "google-ads", "client-accounts", "create", "plan",
    "--request-file", fixture.account.path, "--profile", "ads-admin", "--config", fixture.config.path
  ]
  let plan = await cli.run(arguments: base, environment: environment)
  #expect(plan.exitCode == 0, "\(plan.stderr)")
  #expect(plan.stdout.contains("\"requestSent\" : false"))
  #expect(await transport.requests().isEmpty)

  var apply = base
  apply[3] = "apply"
  let rejected = await cli.run(arguments: apply, environment: environment)
  #expect(rejected.exitCode == 2)
  #expect(await transport.requests().isEmpty)
}

private actor PlanningCapturingTransport: HTTPTransport {
  private var captured: [URLRequest] = []
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    captured.append(request)
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: nil, headerFields: nil
    ))
    return (Data("{}".utf8), response)
  }
  func requests() -> [URLRequest] { captured }
}

private struct PlanningFixture { let root: URL; let config: URL; let account: URL }

private func planningFixture() throws -> PlanningFixture {
  let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".build/google-ads-planning-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  let config = root.appendingPathComponent("profiles.json")
  let account = root.appendingPathComponent("account.json")
  try Data("""
  {"profiles":[{"id":"ads-admin","product":"google-ads","capability":"admin",
  "oauthScopes":["https://www.googleapis.com/auth/adwords"],
  "accessTokenEnvironmentVariable":"ADS_ACCESS","developerTokenEnvironmentVariable":"ADS_DEVELOPER",
  "loginCustomerIdEnvironmentVariable":"ADS_LOGIN"}]}
  """.utf8).write(to: config)
  try Data("""
  {"managerCustomerId":"3827004490","descriptiveName":"Konjac Note Ads",
  "currencyCode":"JPY","timeZone":"Asia/Tokyo"}
  """.utf8).write(to: account)
  return PlanningFixture(root: root, config: config, account: account)
}

private func requestJSON(_ request: URLRequest) throws -> [String: Any] {
  let data = try #require(request.httpBody)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
