import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum SearchConsoleRequests {
  public static func sitesList(accessToken: String) throws -> URLRequest { try siteAPI(path: "/sites", accessToken: accessToken) }
  public static func sitesGet(site: SearchConsoleProperty, accessToken: String) throws -> URLRequest { try siteAPI(path: "/sites/\(encodeSegment(site.value))", accessToken: accessToken) }
  public static func searchAnalytics(site: SearchConsoleProperty, request: SearchConsoleAnalyticsRequest, accessToken: String) throws -> URLRequest { try siteAPI(path: "/sites/\(encodeSegment(site.value))/searchAnalytics/query", accessToken: accessToken, method: "POST", body: try JSONEncoder().encode(request)) }
  public static func sitemapsList(site: SearchConsoleProperty, sitemapIndex: SearchConsoleHTTPURL?, accessToken: String) throws -> URLRequest { try siteAPI(path: "/sites/\(encodeSegment(site.value))/sitemaps", accessToken: accessToken, query: sitemapIndex.map { [URLQueryItem(name: "sitemapIndex", value: $0.value)] }) }
  public static func sitemapsGet(site: SearchConsoleProperty, feedpath: SearchConsoleHTTPURL, accessToken: String) throws -> URLRequest { try siteAPI(path: "/sites/\(encodeSegment(site.value))/sitemaps/\(encodeSegment(feedpath.value))", accessToken: accessToken) }
  public static func urlInspection(site: SearchConsoleProperty, inspectionURL: SearchConsoleHTTPURL, languageCode: SearchConsoleLanguageCode?, accessToken: String) throws -> URLRequest {
    struct Body: Encodable { let inspectionUrl: String; let siteUrl: String; let languageCode: String? }
    return try inspection(path: "/urlInspection/index:inspect", accessToken: accessToken, body: try JSONEncoder().encode(Body(inspectionUrl: inspectionURL.value, siteUrl: site.value, languageCode: languageCode?.value)))
  }

  private static func siteAPI(path: String, accessToken: String, method: String = "GET", body: Data? = nil, query: [URLQueryItem]? = nil) throws -> URLRequest { try make(host: "www.googleapis.com", path: "/webmasters/v3\(path)", accessToken: accessToken, method: method, body: body, query: query) }
  private static func inspection(path: String, accessToken: String, body: Data) throws -> URLRequest { try make(host: "searchconsole.googleapis.com", path: "/v1\(path)", accessToken: accessToken, method: "POST", body: body) }
  private static func make(host: String, path: String, accessToken: String, method: String, body: Data?, query: [URLQueryItem]? = nil) throws -> URLRequest {
    guard HTTPHeaderValue.isCredential(accessToken) else { throw GatewayError("Search Console credential is missing", code: .missingCredential, exitCode: 2) }
    var components = URLComponents(); components.scheme = "https"; components.host = host; components.percentEncodedPath = path; components.queryItems = query
    guard let url = components.url else { throw GatewayError("Search Console request is invalid", code: .invalidArgument, exitCode: 2) }
    var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Accept"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization"); if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }; return request
  }
  private static func encodeSegment(_ value: String) -> String { value.utf8.map { byte in (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || [45, 46, 95, 126].contains(byte) ? String(UnicodeScalar(byte)) : String(format: "%%%02X", byte) }.joined() }
}
