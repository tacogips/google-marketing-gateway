import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func googleAdsV25RequestsUseFixedContracts() throws {
  let list = try GoogleAdsRequests.accessibleCustomers(accessToken: "token", developerToken: "developer", loginCustomerId: "123")
  let search = try GoogleAdsRequests.search(customerId: "456", query: "SELECT customer.id FROM customer", pageToken: nil, accessToken: "token", developerToken: "developer")
  #expect(list.httpMethod == "GET")
  #expect(list.url?.absoluteString == "https://googleads.googleapis.com/v25/customers:listAccessibleCustomers")
  #expect(list.value(forHTTPHeaderField: "login-customer-id") == "123")
  #expect(search.httpMethod == "POST")
  #expect(search.url?.absoluteString == "https://googleads.googleapis.com/v25/customers/456/googleAds:search")
  #expect(search.value(forHTTPHeaderField: "Authorization") == "Bearer token")
  #expect(search.value(forHTTPHeaderField: "developer-token") == "developer")
  #expect(search.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(search.value(forHTTPHeaderField: "Content-Type") == "application/json")
  #expect(search.value(forHTTPHeaderField: "login-customer-id") == nil)
  #expect(try jsonEquals(search, ["query": "SELECT customer.id FROM customer"]))

  let paged = try GoogleAdsRequests.search(
    customerId: "456",
    query: "SELECT customer.id FROM customer",
    pageToken: "next-token",
    accessToken: "token",
    developerToken: "developer",
    loginCustomerId: "789"
  )
  #expect(try jsonEquals(paged, ["query": "SELECT customer.id FROM customer", "pageToken": "next-token"]))
  #expect(paged.value(forHTTPHeaderField: "login-customer-id") == "789")
}

@Test func analyticsDataRequestsUseV1betaAndCamelCase() throws {
  let request = try AnalyticsDataRequests.runReport(
    property: "properties/123",
    request: try AnalyticsDataRequests.reportRequest(metrics: ["activeUsers"], dimensions: ["country"], startDate: "2026-08-01", endDate: "2026-08-02", offset: "0", limit: "10", currencyCode: "USD", keepEmptyRows: true, returnPropertyQuota: true),
    accessToken: "token"
  )
  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://analyticsdata.googleapis.com/v1beta/properties/123:runReport")
  let data = try #require(request.httpBody)
  let object = try JSONSerialization.jsonObject(with: data)
  let body = try #require(object as? [String: Any])
  #expect(body["keepEmptyRows"] as? Bool == true)
  #expect(body["returnPropertyQuota"] as? Bool == true)
  #expect(body["date_ranges"] == nil)
}

@Test func analyticsDataOperationsUseExactWireShapes() throws {
  let metadata = try AnalyticsDataRequests.metadata(property: "properties/123", accessToken: "token")
  #expect(metadata.url?.absoluteString == "https://analyticsdata.googleapis.com/v1beta/properties/123/metadata")
  #expect(metadata.httpMethod == "GET")
  #expect(metadata.httpBody == nil)
  #expect(metadata.value(forHTTPHeaderField: "Authorization") == "Bearer token")
  #expect(metadata.value(forHTTPHeaderField: "Content-Type") == nil)

  let minimal = try AnalyticsDataRequests.runReport(
    property: "properties/123",
    request: try AnalyticsDataRequests.reportRequest(
      metrics: ["activeUsers"], dimensions: [], startDate: "2026-08-01", endDate: "2026-08-02",
      offset: nil, limit: nil, currencyCode: nil, keepEmptyRows: false, returnPropertyQuota: false
    ),
    accessToken: "token"
  )
  let minimalBody = try jsonObject(minimal)
  #expect(minimalBody["dimensions"] == nil)
  #expect(minimalBody["offset"] == nil)
  #expect(minimalBody["limit"] == nil)
  #expect(minimalBody["keepEmptyRows"] as? Bool == false)
  #expect(minimalBody["returnPropertyQuota"] as? Bool == false)

  let compatibility = try AnalyticsDataRequests.compatibility(
    property: "properties/123", metrics: ["activeUsers"], dimensions: [], accessToken: "token"
  )
  #expect(compatibility.url?.absoluteString == "https://analyticsdata.googleapis.com/v1beta/properties/123:checkCompatibility")
  #expect(compatibility.httpMethod == "POST")
  #expect(try jsonObject(compatibility)["dimensions"] == nil)
}

@Test func newProfilesRequireExactScopeAndGoogleAdsDeveloperReference() throws {
  let data = Data("""
  {"profiles":[{"id":"ads","product":"google-ads","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"ACCESS_TOKEN","developerTokenEnvironmentVariable":"DEVELOPER_TOKEN"}]}
  """.utf8)
  #expect(try CredentialProfileConfiguration.decode(data).profiles.count == 1)
}

@Test func googleAdsRejectsBoundariesWithoutCredentialEcho() throws {
  #expect(throws: GatewayError.self) {
    _ = try GoogleAdsRequests.search(customerId: "1-2", query: "SELECT 1", pageToken: nil, accessToken: "token", developerToken: "developer")
  }
  #expect(throws: GatewayError.self) {
    _ = try GoogleAdsRequests.search(customerId: "12", query: "SELECT 1", pageToken: String(repeating: "x", count: 16_385), accessToken: "token", developerToken: "developer")
  }
  for token in ["", "with space", "line\nfeed", String(repeating: "x", count: 8_193), "nonascii-\u{00E9}"] {
    #expect(throws: GatewayError.self) {
      _ = try GoogleAdsRequests.accessibleCustomers(accessToken: token, developerToken: "developer")
    }
  }
  for token in ["", "with space", "line\nfeed", String(repeating: "x", count: 4_097)] {
    #expect(throws: GatewayError.self) {
      _ = try GoogleAdsRequests.accessibleCustomers(accessToken: "token", developerToken: token)
    }
  }
  #expect(throws: GatewayError.self) {
    _ = try GoogleAdsRequests.search(customerId: String(repeating: "1", count: 21), query: "SELECT 1", pageToken: nil, accessToken: "token", developerToken: "developer")
  }
  #expect(throws: GatewayError.self) {
    _ = try GoogleAdsRequests.search(customerId: "12", query: " \n ", pageToken: nil, accessToken: "token", developerToken: "developer")
  }
  #expect(throws: GatewayError.self) {
    _ = try GoogleAdsRequests.accessibleCustomers(accessToken: "token", developerToken: "developer", loginCustomerId: "1-2")
  }
}

@Test func analyticsRejectsGregorianDuplicateAndLimitBoundaries() {
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(metrics: ["activeUsers"], dimensions: [], startDate: "2026-02-30", endDate: "2026-03-01", offset: nil, limit: "1", currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil)
  }
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(metrics: ["activeUsers", "activeUsers"], dimensions: [], startDate: "2026-02-01", endDate: "2026-02-02", offset: nil, limit: "1", currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil)
  }
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(metrics: ["activeUsers"], dimensions: [], startDate: "2026-02-01", endDate: "2026-02-02", offset: nil, limit: "0", currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil)
  }
  let maxOffset = try? AnalyticsDataRequests.reportRequest(metrics: ["activeUsers"], dimensions: [], startDate: "2026-02-01", endDate: "2026-02-02", offset: "9223372036854775807", limit: "1", currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil)
  #expect(maxOffset?.offset == "9223372036854775807")
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(metrics: ["activeUsers"], dimensions: [], startDate: "2026-02-01", endDate: "2026-02-02", offset: "9223372036854775808", limit: "1", currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil)
  }
}

@Test func analyticsRejectsAdversarialNamesPropertiesAndCredentials() {
  let invalidProperties = ["", "properties/", "properties/-1", "properties/1/metadata", "properties/123?x=1", "properties/123%2Fmetadata", "properties/123\n"]
  for property in invalidProperties {
    #expect(throws: GatewayError.self) {
      _ = try AnalyticsDataRequests.metadata(property: property, accessToken: "token")
    }
  }
  let invalidNames = ["", "1metric", "metric-name", "metric/name", "metric\nname", String(repeating: "m", count: 257)]
  for name in invalidNames {
    #expect(throws: GatewayError.self) {
      _ = try AnalyticsDataRequests.reportRequest(
        metrics: [name], dimensions: [], startDate: "2026-08-01", endDate: "2026-08-02",
        offset: nil, limit: nil, currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil
      )
    }
  }
  for token in ["", "with space", "line\nfeed", String(repeating: "x", count: 8_193), "nonascii-\u{00E9}"] {
    #expect(throws: GatewayError.self) {
      _ = try AnalyticsDataRequests.metadata(property: "properties/123", accessToken: token)
    }
  }
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(
      metrics: Array(repeating: "metric", count: 11), dimensions: [], startDate: "2026-08-01", endDate: "2026-08-02",
      offset: nil, limit: nil, currencyCode: nil, keepEmptyRows: nil, returnPropertyQuota: nil
    )
  }
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsDataRequests.reportRequest(
      metrics: ["activeUsers"], dimensions: [], startDate: "2026-08-01", endDate: "2026-08-02",
      offset: "-1", limit: "250001", currencyCode: "usd", keepEmptyRows: nil, returnPropertyQuota: nil
    )
  }
}

@Test func newProfilesRejectCrossProductFieldsAndScopeBundles() {
  let invalid = [
    #"{"profiles":[{"id":"ads","product":"google-ads","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"TOKEN"}]}"#,
    #"{"profiles":[{"id":"ads","product":"google-ads","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords","https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"TOKEN","developerTokenEnvironmentVariable":"DEV"}]}"#,
    #"{"profiles":[{"id":"analytics","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"TOKEN","developerTokenEnvironmentVariable":"DEV"}]}"#,
    #"{"profiles":[{"id":"analytics","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adwords"],"accessTokenEnvironmentVariable":"TOKEN"}]}"#
  ]
  for value in invalid {
    #expect(throws: GatewayError.self) { _ = try CredentialProfileConfiguration.decode(Data(value.utf8)) }
  }
}

private func jsonObject(_ request: URLRequest) throws -> [String: Any] {
  let data = try #require(request.httpBody)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func jsonEquals(_ request: URLRequest, _ expected: [String: Any]) throws -> Bool {
  NSDictionary(dictionary: try jsonObject(request)).isEqual(to: expected)
}
