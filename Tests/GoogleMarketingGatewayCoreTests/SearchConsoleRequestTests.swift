import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func searchConsoleRequestsHaveIndependentFixedContracts() throws {
  let validProperty = try SearchConsoleProperty("https://example.com:8443/a%2Fb/?q=x")
  let domain = try SearchConsoleProperty("sc-domain:example.com")
  let feed = try SearchConsoleHTTPURL("https://example.com/sitemap.xml?x=1%2F2")
  let analytics = try SearchConsoleAnalyticsRequest(
    startDate: "2026-01-01", endDate: "2026-01-02", dimensions: [.query, .page],
    type: .web, aggregationType: .byProperty, rowLimit: 1, startRow: 0,
    dataState: .hourlyAll,
    dimensionFilterGroups: [
      try .init(
        groupType: "and",
        filters: [try .init(dimension: .query, expression: "widget", operator: .contains)]
      )
    ]
  )
  let cases: [(URLRequest, SearchConsoleRequestExpectation)] = [
    (try SearchConsoleRequests.sitesList(accessToken: "token"), .init(method: "GET", url: "https://www.googleapis.com/webmasters/v3/sites", contentType: nil)),
    (try SearchConsoleRequests.sitesGet(site: validProperty, accessToken: "token"), .init(method: "GET", url: "https://www.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com%3A8443%2Fa%252Fb%2F%3Fq%3Dx", contentType: nil)),
    (try SearchConsoleRequests.searchAnalytics(site: domain, request: analytics, accessToken: "token"), .init(method: "POST", url: "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/searchAnalytics/query", contentType: "application/json")),
    (try SearchConsoleRequests.sitemapsList(site: domain, sitemapIndex: feed, accessToken: "token"), .init(method: "GET", url: "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/sitemaps?sitemapIndex=https://example.com/sitemap.xml?x%3D1%252F2", contentType: nil)),
    (try SearchConsoleRequests.sitemapsGet(site: validProperty, feedpath: feed, accessToken: "token"), .init(method: "GET", url: "https://www.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com%3A8443%2Fa%252Fb%2F%3Fq%3Dx/sitemaps/https%3A%2F%2Fexample.com%2Fsitemap.xml%3Fx%3D1%252F2", contentType: nil)),
    (try SearchConsoleRequests.urlInspection(site: domain, inspectionURL: feed, languageCode: try .init("en-Latn-US"), accessToken: "token"), .init(method: "POST", url: "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect", contentType: "application/json"))
  ]
  for (request, expected) in cases {
    #expect(request.httpMethod == expected.method)
    #expect(request.url?.absoluteString == expected.url)
    #expect(request.url?.scheme == "https")
    #expect(request.url?.port == nil)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == expected.contentType)
    #expect((expected.method == "GET") == (request.httpBody == nil))
  }
  let reportBody = try #require(cases[2].0.httpBody)
  let report = try #require(JSONSerialization.jsonObject(with: reportBody) as? [String: Any])
  let expectedReport: [String: Any] = [
    "startDate": "2026-01-01",
    "endDate": "2026-01-02",
    "dimensions": ["query", "page"],
    "type": "web",
    "aggregationType": "byProperty",
    "rowLimit": 1,
    "startRow": 0,
    "dataState": "hourly_all",
    "dimensionFilterGroups": [[
      "groupType": "and",
      "filters": [["dimension": "query", "expression": "widget", "operator": "contains"]]
    ]]
  ]
  #expect(NSDictionary(dictionary: report).isEqual(to: expectedReport))
  let minimal = try SearchConsoleRequests.searchAnalytics(
    site: domain,
    request: try .init(startDate: "2026-01-01", endDate: "2026-01-02"),
    accessToken: "token"
  )
  let minimalBody = try #require(minimal.httpBody)
  let minimalJSON = try #require(JSONSerialization.jsonObject(with: minimalBody) as? [String: Any])
  #expect(
    NSDictionary(dictionary: minimalJSON).isEqual(
      to: ["startDate": "2026-01-01", "endDate": "2026-01-02"]
    )
  )
  let unfilteredSitemaps = try SearchConsoleRequests.sitemapsList(
    site: domain,
    sitemapIndex: nil,
    accessToken: "token"
  )
  #expect(unfilteredSitemaps.url?.absoluteString == "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/sitemaps")
  #expect(URLComponents(url: try #require(unfilteredSitemaps.url), resolvingAgainstBaseURL: false)?.queryItems == nil)
  let defaultOperator = try SearchConsoleRequests.searchAnalytics(
    site: domain,
    request: try .init(
      startDate: "2026-01-01", endDate: "2026-01-02",
      dimensionFilterGroups: [try .init(groupType: "and", filters: [try .init(dimension: .query, expression: "default")])]
    ),
    accessToken: "token"
  )
  let defaultOperatorBody = try #require(defaultOperator.httpBody)
  let defaultOperatorJSON = try #require(JSONSerialization.jsonObject(with: defaultOperatorBody) as? [String: Any])
  let defaultFilters = try #require((defaultOperatorJSON["dimensionFilterGroups"] as? [[String: Any]])?.first?["filters"] as? [[String: Any]])
  #expect(NSArray(array: defaultFilters).isEqual(to: [["dimension": "query", "expression": "default"]]))
  let inspectionBody = try #require(cases[5].0.httpBody)
  let inspection = try #require(JSONSerialization.jsonObject(with: inspectionBody) as? [String: String])
  #expect(inspection == ["inspectionUrl": feed.value, "siteUrl": domain.value, "languageCode": "en-Latn-US"])
  let noLanguage = try SearchConsoleRequests.urlInspection(site: domain, inspectionURL: feed, languageCode: nil, accessToken: "token")
  let noLanguageBody = try #require(noLanguage.httpBody)
  let noLanguageJSON = try #require(JSONSerialization.jsonObject(with: noLanguageBody) as? [String: String])
  #expect(noLanguageJSON["languageCode"] == nil)
}

private struct SearchConsoleRequestExpectation {
  let method: String
  let url: String
  let contentType: String?
}

@Test func searchConsolePathParametersCannotControlRequests() throws {
  for value in ["https://user@example.com/", "https://example.com/#fragment", "https://example.com\\path/", "ftp://example.com/", "https://example.com/%ZZ", "https://example.com/no-trailing", "https://example.com/a b/", "https://example.com/a{b}/", "https://example.com/a|b/", "https://example.com/é/"] {
    #expect(throws: GatewayError.self) { _ = try SearchConsoleProperty(value) }
  }
  for value in ["sc-domain:bad_domain", "sc-domain:.example.com", "sc-domain:a..example.com", "sc-domain:-bad.example", "sc-domain:example.com.", "sc-domain:example.com/path"] {
    #expect(throws: GatewayError.self) { _ = try SearchConsoleProperty(value) }
  }
  for value in ["https://user:secret@example.com/a", "https://example.com/#x", "https://example.com/%ZZ", "relative/path", "javascript:alert(1)", "https://example.com/sitemap name.xml", "https://example.com/a{b}", "https://example.com/a|b", "https://example.com/é"] {
    #expect(throws: GatewayError.self) { _ = try SearchConsoleHTTPURL(value) }
  }
  let hostile = try SearchConsoleProperty("https://example.com/%2e%2e/%2F@/?x=%25")
  let request = try SearchConsoleRequests.sitesGet(site: hostile, accessToken: "token")
  #expect(request.url?.host == "www.googleapis.com")
  #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.percentEncodedPath == "/webmasters/v3/sites/https%3A%2F%2Fexample.com%2F%252e%252e%2F%252F%40%2F%3Fx%3D%2525")
}

@Test func searchConsolePropertyAndURLRespectExactByteBounds() throws {
  let propertyPrefix = "https://example.com/"
  let propertyAtLimit = propertyPrefix + String(repeating: "a", count: 4_096 - propertyPrefix.utf8.count - 1) + "/"
  #expect(propertyAtLimit.utf8.count == 4_096)
  _ = try SearchConsoleProperty(propertyAtLimit)
  #expect(throws: GatewayError.self) { _ = try SearchConsoleProperty(propertyAtLimit + "a") }

  let urlPrefix = "https://example.com/"
  let urlAtLimit = urlPrefix + String(repeating: "a", count: 8_192 - urlPrefix.utf8.count)
  #expect(urlAtLimit.utf8.count == 8_192)
  _ = try SearchConsoleHTTPURL(urlAtLimit)
  #expect(throws: GatewayError.self) { _ = try SearchConsoleHTTPURL(urlAtLimit + "a") }
}

@Test func searchConsoleAnalyticsAcceptsEveryOfficialClosedValue() throws {
  let dimensions = ["query", "page", "country", "device", "date", "hour", "searchAppearance"]
  let types = ["web", "image", "video", "news", "discover", "googleNews"]
  let aggregations = ["auto", "byPage", "byProperty", "byNewsShowcasePanel"]
  let states = ["all", "final", "hourly_all"]
  let filterDimensions = ["country", "device", "page", "query", "searchAppearance"]
  let filterOperators = ["equals", "notEquals", "contains", "notContains", "includingRegex", "excludingRegex"]
  #expect(Set(SearchConsoleDimension.allCases.map(\.rawValue)) == Set(dimensions))
  #expect(Set(SearchConsoleSearchType.allCases.map(\.rawValue)) == Set(types))
  #expect(Set(SearchConsoleAggregationType.allCases.map(\.rawValue)) == Set(aggregations))
  #expect(Set(SearchConsoleDataState.allCases.map(\.rawValue)) == Set(states))
  #expect(Set(SearchConsoleFilterDimension.allCases.map(\.rawValue)) == Set(filterDimensions))
  #expect(Set(SearchConsoleFilterOperator.allCases.map(\.rawValue)) == Set(filterOperators))
  for raw in dimensions {
    _ = try SearchConsoleAnalyticsRequest(
      startDate: "2026-01-01",
      endDate: "2026-01-02",
      dimensions: [try #require(SearchConsoleDimension(rawValue: raw))]
    )
  }
  for raw in types {
    #expect(SearchConsoleSearchType(rawValue: raw)?.rawValue == raw)
  }
  for raw in aggregations {
    #expect(SearchConsoleAggregationType(rawValue: raw)?.rawValue == raw)
  }
  for raw in states {
    #expect(SearchConsoleDataState(rawValue: raw)?.rawValue == raw)
  }
  for dimension in filterDimensions {
    for operation in filterOperators {
      _ = try SearchConsoleDimensionFilter(
        dimension: try #require(SearchConsoleFilterDimension(rawValue: dimension)),
        expression: "value",
        operator: SearchConsoleFilterOperator(rawValue: operation)
      )
    }
  }
}

@Test func searchConsoleAnalyticsSemanticValidationRejectsBoundaries() throws {
  let valid = { try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-01", rowLimit: 1, startRow: 0) }
  _ = try valid()
  let invalidRequests: [() throws -> Void] = [
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-02-30", endDate: "2026-03-01") },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-02", endDate: "2026-01-01") },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-1-01", endDate: "2026-01-02") },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02", dimensions: [.query, .query]) },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02", rowLimit: 0) },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02", rowLimit: 25_001) },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02", startRow: -1) },
    { _ = try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02", dimensionFilterGroups: []) },
    { _ = try SearchConsoleDimensionFilterGroup(groupType: "or", filters: [try .init(dimension: .query, expression: "value")]) },
    { _ = try SearchConsoleDimensionFilter(dimension: .query, expression: "\n") },
    { _ = try SearchConsoleDimensionFilter(dimension: .query, expression: String(repeating: "a", count: 4_097)) },
    { _ = try SearchConsoleDimensionFilter(dimension: .query, expression: "safe\u{0000}unsafe") }
  ]
  for invalid in invalidRequests { #expect(throws: GatewayError.self) { try invalid() } }
}

@Test func searchConsoleAnalyticsRejectsGroupFilterAndExpressionResourceBounds() throws {
  let filter = try SearchConsoleDimensionFilter(dimension: .query, expression: "value")
  let group = try SearchConsoleDimensionFilterGroup(groupType: "and", filters: [filter])
  #expect(throws: GatewayError.self) {
    _ = try SearchConsoleAnalyticsRequest(
      startDate: "2026-01-01", endDate: "2026-01-02",
      dimensionFilterGroups: Array(repeating: group, count: 101)
    )
  }
  #expect(throws: GatewayError.self) {
    _ = try SearchConsoleAnalyticsRequest(
      startDate: "2026-01-01", endDate: "2026-01-02",
      dimensionFilterGroups: [try .init(groupType: "and", filters: Array(repeating: filter, count: 101))]
    )
  }
  let maxBytes = String(repeating: "👩‍👩‍👧‍👧", count: 1_000)
  #expect(maxBytes.count < 4_096)
  #expect(maxBytes.utf8.count > 16_384)
  #expect(throws: GatewayError.self) {
    _ = try SearchConsoleDimensionFilter(dimension: .query, expression: maxBytes)
  }
}

@Test func searchConsoleAnalyticsAcceptsExactResourceBoundaries() throws {
  let filter = try SearchConsoleDimensionFilter(dimension: .query, expression: "value")
  let groups = Array(
    repeating: try SearchConsoleDimensionFilterGroup(groupType: "and", filters: [filter]),
    count: 100
  )
  _ = try SearchConsoleAnalyticsRequest(
    startDate: "2026-01-01",
    endDate: "2026-01-02",
    rowLimit: 25_000,
    startRow: 0,
    dimensionFilterGroups: groups
  )
  let maximumExpression = String(repeating: "😀", count: 4_096)
  #expect(maximumExpression.count == 4_096)
  #expect(maximumExpression.utf8.count == 16_384)
  _ = try SearchConsoleDimensionFilter(dimension: .query, expression: maximumExpression)
}

@Test func searchConsoleLanguageValidationCoversBoundaries() throws {
  let valid = ["en", "en-US", "en-1abc", "zh-Hant-TW-u-ca-gregory-x-private", "x-private", "zh-cmn-Hans-CN", "i-klingon"]
  for value in valid { #expect(try SearchConsoleLanguageCode(value).value == value) }
  let invalid = ["en--US", "en-u", "en-1!!!", "en-1901-1901", "sl-rozaj-ROZAJ", "zh-Hans-cmn-CN", "en-x", String(repeating: "a", count: 256)]
  for value in invalid { #expect(throws: GatewayError.self) { _ = try SearchConsoleLanguageCode(value) } }
}

@Test func searchConsoleProfilesAreExactAndFixturesRemainIsolated() throws {
  let exact = #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#
  #expect(try CredentialProfileConfiguration.decode(Data(exact.utf8)).profiles.count == 1)
  let installed = exact.replacingOccurrences(of: "\"SC_TOKEN\"", with: "\"SC_TOKEN\",\"oauthClientJSONPath\":\"client.json\",\"tokenStorePath\":\"token.json\"")
  #expect(try CredentialProfileConfiguration.decode(Data(installed.utf8)).profiles.first?.tokenStorePath == "token.json")
  let invalid = [
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":[],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly","https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly","https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"writer","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN","developerTokenEnvironmentVariable":"ADS_DEV"}]}"#,
    #"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN","loginCustomerIdEnvironmentVariable":"ADS_LOGIN"}]}"#
  ]
  for json in invalid { #expect(throws: GatewayError.self) { _ = try CredentialProfileConfiguration.decode(Data(json.utf8)) } }
  let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/search-console-reader-profiles.json")
  #expect(try CredentialProfileConfiguration.decode(Data(contentsOf: fixture)).profiles.map(\.id) == ["search-console-environment", "search-console-installed"])
  let existing = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/reader-profiles.json")
  #expect(try CredentialProfileConfiguration.decode(Data(contentsOf: existing)).profiles.count == 3)
}
