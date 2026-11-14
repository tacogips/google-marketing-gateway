import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PublisherRequests {
  public static func adsenseAccounts(
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/accounts",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken)
    )
  }

  public static func adsensePayments(
    account: String,
    accessToken: String
  ) throws -> URLRequest {
    try validateResource(account, prefix: "accounts/")
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(account)/payments",
      accessToken: accessToken,
      query: []
    )
  }

  public static func adsenseAdClients(
    account: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(account)/adclients",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 10_000)
    )
  }

  public static func adsenseAdUnits(
    adClient: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(adClient, pattern: ["accounts", nil, "adclients", nil])
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(adClient)/adunits",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 10_000)
    )
  }

  public static func adsenseSites(
    account: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(account)/sites",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 10_000)
    )
  }

  public static func adsensePolicyIssues(
    account: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(account)/policyIssues",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 10_000)
    )
  }

  public static func adsenseReport(
    account: String,
    parameters: AdSenseReportParameters,
    accessToken: String
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://adsense.googleapis.com",
      path: "/v2/\(account)/reports:generate",
      accessToken: accessToken,
      query: adsenseReportQuery(parameters)
    )
  }

  public static func admobAccounts(
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try request(
      origin: "https://admob.googleapis.com",
      path: "/v1/accounts",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken)
    )
  }

  public static func admobApps(
    account: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://admob.googleapis.com",
      path: "/v1/\(account)/apps",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 20_000)
    )
  }

  public static func admobAdUnits(
    account: String,
    accessToken: String,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    return try request(
      origin: "https://admob.googleapis.com",
      path: "/v1/\(account)/adUnits",
      accessToken: accessToken,
      query: pagination(pageSize: pageSize, pageToken: pageToken, maximumPageSize: 20_000)
    )
  }

  public static func admobNativeAdUnitCreate(
    input: AdMobNativeAdUnitInput,
    accessToken: String
  ) throws -> URLRequest {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let body: Data
    do {
      body = try encoder.encode(AdMobNativeAdUnitCreateBody(input: input))
    } catch {
      throw GatewayError("Unable to encode AdMob Native ad-unit request", code: .invalidArgument, exitCode: 2)
    }
    return try request(
      origin: "https://admob.googleapis.com",
      path: "/v1beta/\(input.account)/adUnits",
      accessToken: accessToken,
      query: [],
      method: "POST",
      body: body
    )
  }

  public static func admobNetworkReport(
    account: String,
    reportSpec: AdMobReportSpec,
    accessToken: String
  ) throws -> URLRequest {
    try admobReport(
      account: account,
      reportName: "networkReport",
      reportSpec: reportSpec,
      accessToken: accessToken
    )
  }

  public static func admobMediationReport(
    account: String,
    reportSpec: AdMobReportSpec,
    accessToken: String
  ) throws -> URLRequest {
    try admobReport(
      account: account,
      reportName: "mediationReport",
      reportSpec: reportSpec,
      accessToken: accessToken
    )
  }

  private static func pagination(
    pageSize: Int?,
    pageToken: String?,
    maximumPageSize: Int = 10_000
  ) throws -> [URLQueryItem] {
    if let pageSize, !(1...maximumPageSize).contains(pageSize) {
      throw GatewayError(
        "--page-size must be between 1 and \(maximumPageSize)",
        code: .invalidArgument,
        exitCode: 2
      )
    }
    var items: [URLQueryItem] = []
    if let pageSize { items.append(URLQueryItem(name: "pageSize", value: String(pageSize))) }
    if let pageToken, !pageToken.isEmpty { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
    return items
  }

  private static func request(
    origin: String,
    path: String,
    accessToken: String,
    query: [URLQueryItem],
    method: String = "GET",
    body: Data? = nil
  ) throws -> URLRequest {
    guard HTTPHeaderValue.isCredential(accessToken) else {
      throw GatewayError("Access token is empty", code: .missingCredential, exitCode: 2)
    }
    guard var components = URLComponents(string: origin) else {
      throw GatewayError("Invalid fixed Google API origin", code: .invalidArgument)
    }
    components.path = path
    components.queryItems = query.isEmpty ? nil : query
    guard let url = components.url else {
      throw GatewayError("Unable to construct Google API URL", code: .invalidArgument)
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    return request
  }

  private static func validateResource(_ value: String, prefix: String) throws {
    try validateResource(value, pattern: [String(prefix.dropLast()), nil])
  }

  private static func validateResource(_ value: String, pattern: [String?]) throws {
    let segments = value.split(separator: "/", omittingEmptySubsequences: false)
    guard segments.count == pattern.count else {
      throw GatewayError("Resource name has an invalid structure", code: .invalidArgument, exitCode: 2)
    }
    for (segment, expected) in zip(segments, pattern) {
      if let expected {
        guard segment == expected[...] else {
          throw GatewayError("Resource name has an invalid structure", code: .invalidArgument, exitCode: 2)
        }
      } else {
        guard !segment.isEmpty,
              segment.utf8.allSatisfy({ byte in
                (48...57).contains(byte) || (65...90).contains(byte) ||
                  (97...122).contains(byte) || byte == 45 || byte == 95
              }) else {
          throw GatewayError("Resource name contains an unsafe identifier", code: .invalidArgument, exitCode: 2)
        }
      }
    }
  }

  private static func admobReport(
    account: String,
    reportName: String,
    reportSpec: AdMobReportSpec,
    accessToken: String
  ) throws -> URLRequest {
    try validateResource(account, pattern: ["accounts", nil])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let body: Data
    do {
      body = try encoder.encode(AdMobGenerateReportRequest(reportSpec: reportSpec))
    } catch {
      throw GatewayError("Unable to encode AdMob report request", code: .invalidArgument, exitCode: 2)
    }
    return try request(
      origin: "https://admob.googleapis.com",
      path: "/v1/\(account)/\(reportName):generate",
      accessToken: accessToken,
      query: [],
      method: "POST",
      body: body
    )
  }

  private static func adsenseReportQuery(_ parameters: AdSenseReportParameters) -> [URLQueryItem] {
    var query = [URLQueryItem(name: "dateRange", value: "CUSTOM")]
    let start = parameters.dateRange.startDate
    let end = parameters.dateRange.endDate
    query += [
      URLQueryItem(name: "startDate.year", value: String(start.year)),
      URLQueryItem(name: "startDate.month", value: String(start.month)),
      URLQueryItem(name: "startDate.day", value: String(start.day)),
      URLQueryItem(name: "endDate.year", value: String(end.year)),
      URLQueryItem(name: "endDate.month", value: String(end.month)),
      URLQueryItem(name: "endDate.day", value: String(end.day))
    ]
    query += parameters.dimensions.map { URLQueryItem(name: "dimensions", value: $0) }
    query += parameters.metrics.map { URLQueryItem(name: "metrics", value: $0) }
    query += parameters.filters.map { URLQueryItem(name: "filters", value: $0) }
    query += parameters.orderBy.map { URLQueryItem(name: "orderBy", value: $0) }
    if let value = parameters.languageCode { query.append(URLQueryItem(name: "languageCode", value: value)) }
    if let value = parameters.currencyCode { query.append(URLQueryItem(name: "currencyCode", value: value)) }
    if let value = parameters.limit { query.append(URLQueryItem(name: "limit", value: String(value))) }
    if let value = parameters.reportingTimeZone {
      query.append(URLQueryItem(name: "reportingTimeZone", value: value))
    }
    return query
  }
}
