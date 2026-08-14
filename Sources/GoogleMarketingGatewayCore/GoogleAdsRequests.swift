import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum GoogleAdsRequests {
  public static let apiVersion = "v25"
  public static func accessibleCustomers(accessToken: String, developerToken: String, loginCustomerId: String? = nil) throws -> URLRequest {
    try request(path: "/v25/customers:listAccessibleCustomers", accessToken: accessToken, developerToken: developerToken, loginCustomerId: loginCustomerId)
  }
  public static func search(customerId: String, query: String, pageToken: String?, accessToken: String, developerToken: String, loginCustomerId: String? = nil) throws -> URLRequest {
    guard CredentialProfileConfiguration.isDigits(customerId, maximum: 20), !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, query.utf8.count <= 1_048_576 else {
      throw GatewayError("Google Ads search input is invalid", code: .invalidArgument, exitCode: 2)
    }
    if let pageToken, pageToken.isEmpty || pageToken.utf8.count > 16_384 || pageToken.utf8.contains(where: { $0 < 33 || $0 == 127 }) {
      throw GatewayError("Google Ads page token is invalid", code: .invalidArgument, exitCode: 2)
    }
    struct Body: Encodable { let query: String; let pageToken: String? }
    let body = try JSONEncoder().encode(Body(query: query, pageToken: pageToken))
    return try request(path: "/v25/customers/\(customerId)/googleAds:search", accessToken: accessToken, developerToken: developerToken, loginCustomerId: loginCustomerId, method: "POST", body: body)
  }
  private static func request(path: String, accessToken: String, developerToken: String, loginCustomerId: String?, method: String = "GET", body: Data? = nil) throws -> URLRequest {
    guard HTTPHeaderValue.isCredential(accessToken), HTTPHeaderValue.isCredential(developerToken, maximumBytes: 4_096) else {
      throw GatewayError("Google Ads credential is invalid", code: .missingCredential, exitCode: 2)
    }
    if let loginCustomerId, !CredentialProfileConfiguration.isDigits(loginCustomerId, maximum: 20) { throw GatewayError("Google Ads login customer id is invalid", code: .invalidArgument, exitCode: 2) }
    guard let url = URL(string: "https://googleads.googleapis.com\(path)") else { throw GatewayError("Unable to construct Google Ads URL", code: .invalidArgument, exitCode: 2) }
    var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(developerToken, forHTTPHeaderField: "developer-token")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let loginCustomerId { request.setValue(loginCustomerId, forHTTPHeaderField: "login-customer-id") }
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    return request
  }
}
