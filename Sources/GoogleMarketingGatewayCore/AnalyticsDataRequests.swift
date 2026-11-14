import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnalyticsDataReportRequest: Codable, Equatable, Sendable {
  public struct NamedValue: Codable, Equatable, Sendable { public let name: String }
  public let metrics: [NamedValue]
  public let dimensions: [NamedValue]?
  public let dateRanges: [DateRange]
  public let offset: String?
  public let limit: String?
  public let currencyCode: String?
  public let keepEmptyRows: Bool?
  public let returnPropertyQuota: Bool?
  public struct DateRange: Codable, Equatable, Sendable { public let startDate: String; public let endDate: String }
}

public enum AnalyticsDataRequests {
  public static let apiVersion = "v1beta"
  public static func metadata(property: String, accessToken: String) throws -> URLRequest {
    try make(path: "/v1beta/\(try validatedProperty(property))/metadata", accessToken: accessToken)
  }
  public static func runReport(property: String, request: AnalyticsDataReportRequest, accessToken: String) throws -> URLRequest {
    guard !request.metrics.isEmpty else { throw GatewayError("At least one metric is required", code: .invalidArgument, exitCode: 2) }
    return try make(path: "/v1beta/\(try validatedProperty(property)):runReport", accessToken: accessToken, method: "POST", body: try JSONEncoder().encode(request))
  }
  public static func compatibility(property: String, metrics: [String], dimensions: [String], accessToken: String) throws -> URLRequest {
    guard !metrics.isEmpty else { throw GatewayError("At least one metric is required", code: .invalidArgument, exitCode: 2) }
    struct Body: Codable { let metrics: [AnalyticsDataReportRequest.NamedValue]; let dimensions: [AnalyticsDataReportRequest.NamedValue]? }
    return try make(path: "/v1beta/\(try validatedProperty(property)):checkCompatibility", accessToken: accessToken, method: "POST", body: try JSONEncoder().encode(Body(metrics: try names(metrics, maximum: 10), dimensions: dimensions.isEmpty ? nil : try names(dimensions, maximum: 9))))
  }
  public static func reportRequest(metrics: [String], dimensions: [String], startDate: String, endDate: String, offset: String?, limit: String?, currencyCode: String?, keepEmptyRows: Bool?, returnPropertyQuota: Bool?) throws -> AnalyticsDataReportRequest {
    guard isDate(startDate), isDate(endDate), startDate <= endDate else { throw GatewayError("Analytics dates are invalid", code: .invalidArgument, exitCode: 2) }
    if let offset { _ = try boundedInteger(offset, name: "offset", maximum: Int64.max) }
    if let limit {
      let parsed = try boundedInteger(limit, name: "limit", maximum: 250_000)
      guard parsed > 0 else { throw GatewayError("Analytics limit is invalid", code: .invalidArgument, exitCode: 2) }
    }
    if let currencyCode, currencyCode.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) == nil { throw GatewayError("Currency code is invalid", code: .invalidArgument, exitCode: 2) }
    return AnalyticsDataReportRequest(metrics: try names(metrics, maximum: 10), dimensions: dimensions.isEmpty ? nil : try names(dimensions, maximum: 9), dateRanges: [.init(startDate: startDate, endDate: endDate)], offset: offset, limit: limit, currencyCode: currencyCode, keepEmptyRows: keepEmptyRows, returnPropertyQuota: returnPropertyQuota)
  }
  private static func names(_ input: [String], maximum: Int) throws -> [AnalyticsDataReportRequest.NamedValue] {
    guard !input.isEmpty, input.count <= maximum, Set(input).count == input.count else { throw GatewayError("Analytics names are invalid", code: .invalidArgument, exitCode: 2) }
    return try input.map { value in
      guard value.range(of: #"^[A-Za-z][A-Za-z0-9_]*(:[A-Za-z0-9_]+)?$"#, options: .regularExpression) != nil, value.utf8.count <= 256 else { throw GatewayError("Analytics name is invalid", code: .invalidArgument, exitCode: 2) }
      return .init(name: value)
    }
  }
  private static func validatedProperty(_ value: String) throws -> String {
    guard value.range(of: #"^properties/[0-9]{1,20}$"#, options: .regularExpression) != nil else { throw GatewayError("Analytics property is invalid", code: .invalidArgument, exitCode: 2) }
    return value
  }
  private static func isDate(_ value: String) -> Bool {
    guard value.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return false }
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
    return formatter.date(from: value).map { formatter.string(from: $0) == value } ?? false
  }
  private static func boundedInteger(_ value: String, name: String, maximum: Int64) throws -> Int64 {
    guard let result = Int64(value), result >= 0, result <= maximum else { throw GatewayError("Analytics \(name) is invalid", code: .invalidArgument, exitCode: 2) }
    return result
  }
  private static func make(path: String, accessToken: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
    guard HTTPHeaderValue.isCredential(accessToken), let url = URL(string: "https://analyticsdata.googleapis.com\(path)") else { throw GatewayError("Analytics credential or URL is invalid", code: .missingCredential, exitCode: 2) }
    var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    return request
  }
}
