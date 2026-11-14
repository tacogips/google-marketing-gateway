import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

@Test func adsenseAccountsRequestUsesFixedOriginAndBearerToken() throws {
  let request = try PublisherRequests.adsenseAccounts(
    accessToken: "test-token",
    pageSize: 25,
    pageToken: "next token"
  )
  #expect(request.httpMethod == "GET")
  #expect(request.url?.host == "adsense.googleapis.com")
  #expect(request.url?.path == "/v2/accounts")
  #expect(request.url?.query?.contains("pageSize=25") == true)
  #expect(request.url?.query?.contains("pageToken=next%20token") == true)
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
}

@Test func adsensePaymentsRejectsUnscopedResourceName() throws {
  #expect(throws: GatewayError.self) {
    _ = try PublisherRequests.adsensePayments(account: "publishers/123", accessToken: "token")
  }
}

@Test func adsenseInventoryRequestsUseOfficialPathsAndFixedOrigin() throws {
  let adClients = try PublisherRequests.adsenseAdClients(
    account: "accounts/pub-123",
    accessToken: "token"
  )
  let adUnits = try PublisherRequests.adsenseAdUnits(
    adClient: "accounts/pub-123/adclients/ca-456",
    accessToken: "token"
  )
  let sites = try PublisherRequests.adsenseSites(account: "accounts/pub-123", accessToken: "token")
  let issues = try PublisherRequests.adsensePolicyIssues(account: "accounts/pub-123", accessToken: "token")
  #expect(adClients.url?.absoluteString == "https://adsense.googleapis.com/v2/accounts/pub-123/adclients")
  #expect(adUnits.url?.absoluteString == "https://adsense.googleapis.com/v2/accounts/pub-123/adclients/ca-456/adunits")
  #expect(sites.url?.absoluteString == "https://adsense.googleapis.com/v2/accounts/pub-123/sites")
  #expect(issues.url?.absoluteString == "https://adsense.googleapis.com/v2/accounts/pub-123/policyIssues")
}

@Test func adsenseReportUsesOfficialGETQueryFieldNamesAndNoBody() throws {
  let request = try PublisherRequests.adsenseReport(
    account: "accounts/pub-123",
    parameters: try AdSenseReportParameters(
      dateRange: try reportDateRange(),
      dimensions: ["DATE"],
      metrics: ["CLICKS", "ESTIMATED_EARNINGS"],
      filters: ["COUNTRY_CODE==US"],
      orderBy: ["-CLICKS"],
      languageCode: "en-US",
      currencyCode: "USD",
      limit: 50,
      reportingTimeZone: "ACCOUNT_TIME_ZONE"
    ),
    accessToken: "token"
  )
  let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
  #expect(request.httpMethod == "GET")
  #expect(request.httpBody == nil)
  #expect(request.url?.host == "adsense.googleapis.com")
  #expect(items.contains(URLQueryItem(name: "dateRange", value: "CUSTOM")))
  #expect(items.contains(URLQueryItem(name: "startDate.year", value: "2026")))
  #expect(items.contains(URLQueryItem(name: "endDate.day", value: "31")))
  #expect(items.contains(URLQueryItem(name: "dimensions", value: "DATE")))
  #expect(items.contains(URLQueryItem(name: "metrics", value: "CLICKS")))
  #expect(items.contains(URLQueryItem(name: "reportingTimeZone", value: "ACCOUNT_TIME_ZONE")))
}

@Test func admobInventoryRequestsUseOfficialPathsAndPageLimit() throws {
  let apps = try PublisherRequests.admobApps(
    account: "accounts/pub-123",
    accessToken: "token",
    pageSize: 20_000
  )
  let adUnits = try PublisherRequests.admobAdUnits(account: "accounts/pub-123", accessToken: "token")
  #expect(apps.url?.host == "admob.googleapis.com")
  #expect(apps.url?.path == "/v1/accounts/pub-123/apps")
  #expect(apps.url?.query?.contains("pageSize=20000") == true)
  #expect(adUnits.url?.path == "/v1/accounts/pub-123/adUnits")
}

@Test func nativeAdUnitCreateUsesFixedV1betaPOSTAndExactBody() throws {
  let input = try AdMobNativeAdUnitInput(
    account: "accounts/pub-9876543210987654",
    appID: "ca-app-pub-9876543210987654~0123456789",
    displayName: "Example Native",
    adTypes: [.video, .richMedia]
  )
  let request = try PublisherRequests.admobNativeAdUnitCreate(input: input, accessToken: "token")
  let body = try #require(request.httpBody)
  let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://admob.googleapis.com/v1beta/accounts/pub-9876543210987654/adUnits")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
  #expect(Set(object.keys) == ["appId", "displayName", "adFormat", "adTypes"])
  #expect(object["adFormat"] as? String == "NATIVE")
  #expect(object["adTypes"] as? [String] == ["RICH_MEDIA", "VIDEO"])
}

@Test func nativeAdUnitCreateRejectsCrossAccountAndDuplicateTypes() {
  #expect(throws: GatewayError.self) {
    _ = try AdMobNativeAdUnitInput(
      account: "accounts/pub-1", appID: "ca-app-pub-2~3", displayName: "Native", adTypes: [.richMedia]
    )
  }
  #expect(throws: GatewayError.self) {
    _ = try AdMobNativeAdUnitInput(
      account: "accounts/pub-1", appID: "ca-app-pub-1~3", displayName: "Native", adTypes: [.richMedia, .richMedia]
    )
  }
}

@Test func admobReportPOSTBodiesUseOfficialCamelCaseFields() throws {
  let spec = try AdMobReportSpec(
    dateRange: try reportDateRange(),
    dimensions: ["DATE", "APP"],
    metrics: ["CLICKS"],
    localizationSettings: try AdMobLocalizationSettings(currencyCode: "USD", languageCode: "en-US"),
    maxReportRows: 100,
    timeZone: "America/Los_Angeles"
  )
  let requests = try [
    PublisherRequests.admobNetworkReport(account: "accounts/pub-123", reportSpec: spec, accessToken: "token"),
    PublisherRequests.admobMediationReport(account: "accounts/pub-123", reportSpec: spec, accessToken: "token")
  ]
  for request in requests {
    let body = try #require(request.httpBody)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let reportSpec = try #require(object["reportSpec"] as? [String: Any])
    let dateRange = try #require(reportSpec["dateRange"] as? [String: Any])
    let startDate = try #require(dateRange["startDate"] as? [String: Any])
    let localization = try #require(reportSpec["localizationSettings"] as? [String: Any])
    #expect(request.httpMethod == "POST")
    #expect(request.url?.host == "admob.googleapis.com")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(startDate["year"] as? Int == 2026)
    #expect(reportSpec["metrics"] as? [String] == ["CLICKS"])
    #expect(reportSpec["maxReportRows"] as? Int == 100)
    #expect(localization["currencyCode"] as? String == "USD")
    #expect(object["report_spec"] == nil)
  }
  #expect(requests[0].url?.path == "/v1/accounts/pub-123/networkReport:generate")
  #expect(requests[1].url?.path == "/v1/accounts/pub-123/mediationReport:generate")
}

@Test func nestedAndAccountResourcesRejectTraversalOrExtraSegments() throws {
  #expect(throws: GatewayError.self) {
    _ = try PublisherRequests.adsenseAdUnits(
      adClient: "accounts/pub-123/adclients/../../token",
      accessToken: "token"
    )
  }
  #expect(throws: GatewayError.self) {
    _ = try PublisherRequests.admobApps(account: "accounts/pub-123/apps/extra", accessToken: "token")
  }
}

@Test func writerHasNoEnabledMutations() async {
  let result = await GoogleMarketingGatewayCLI(mode: .writer).run(arguments: ["anything"])
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("FORBIDDEN_CAPABILITY"))
}

@Test func catalogDocumentsTrendsAlphaAvailability() throws {
  let output = try OperationCatalog.encoded()
  #expect(output.contains("official-alpha-allowlist-required"))
  #expect(output.contains("adsense.readonly"))
  #expect(output.contains("adsense.accounts.reports.generate"))
  #expect(output.contains("admob.accounts.networkReport.generate"))
  #expect(output.contains("admob.report"))
}

private func reportDateRange() throws -> MarketingDateRange {
  try MarketingDateRange(
    startDate: MarketingDate(year: 2026, month: 8, day: 1),
    endDate: MarketingDate(year: 2026, month: 8, day: 31)
  )
}
