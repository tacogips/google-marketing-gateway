import Darwin
import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func searchConsolePostRequestsRefuse307And308Redirects() async throws {
  let analytics = try SearchConsoleRequests.searchAnalytics(
    site: try SearchConsoleProperty("sc-domain:example.com"),
    request: try SearchConsoleAnalyticsRequest(startDate: "2026-01-01", endDate: "2026-01-02"),
    accessToken: "token"
  )
  let inspection = try SearchConsoleRequests.urlInspection(
    site: try SearchConsoleProperty("sc-domain:example.com"),
    inspectionURL: try SearchConsoleHTTPURL("https://example.com/page"),
    languageCode: nil,
    accessToken: "token"
  )
  for statusCode in [307, 308] {
    for request in [analytics, inspection] {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [SearchConsoleRedirectURLProtocol.self]
      SearchConsoleRedirectURLProtocol.reset(statusCode: statusCode)
      let (_, response) = try await URLSessionTransport(configuration: configuration).data(for: request)
      #expect(response.statusCode == statusCode)
      let received = SearchConsoleRedirectURLProtocol.requests
      #expect(received.count == 1)
      #expect(received.first?.url == request.url)
      #expect(received.allSatisfy { $0.url?.host != "redirect-capture.invalid" })
    }
  }
}

@Test func everySearchConsoleReaderRouteDispatchesExactRecordedRequest() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = try searchConsoleConfig(in: root)
  let query = root.appendingPathComponent("request.json")
  try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensions":["query","page"],"type":"web","aggregationType":"byProperty","rowLimit":1,"startRow":0,"dataState":"hourly_all","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"widget","operator":"contains"},{"dimension":"page","expression":"https://example.com/"}]}]}"#.utf8).write(to: query)
  let common = ["--profile", "search", "--config", config.path]
  let routes: [[String]] = [
    ["search-console", "sites", "list"],
    ["search-console", "sites", "get", "--site", "sc-domain:example.com"],
    ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", query.path],
    ["search-console", "sitemaps", "list", "--site", "sc-domain:example.com", "--sitemap-index", "https://example.com/sitemap.xml?x=1"],
    ["search-console", "sitemaps", "get", "--site", "sc-domain:example.com", "--feedpath", "https://example.com/sitemap.xml?x=1"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/page", "--language-code", "en-US"]
  ]
  let transport = SearchConsoleRecordingTransport()
  let reader = GoogleMarketingGatewayCLI(mode: .reader, transport: transport)
  for route in routes { #expect((await reader.run(arguments: route + common, environment: ["SC_TOKEN": "token"])).exitCode == 0) }
  let requests = transport.requests
  #expect(requests.count == 6)
  let getHeaders = ["accept": "application/json", "authorization": "Bearer token"]
  let postHeaders = getHeaders.merging(["content-type": "application/json"]) { _, replacement in replacement }
  let expectations: [(String, String, [String: String])] = [
    ("GET", "https://www.googleapis.com/webmasters/v3/sites", getHeaders),
    ("GET", "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com", getHeaders),
    ("POST", "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/searchAnalytics/query", postHeaders),
    ("GET", "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/sitemaps?sitemapIndex=https://example.com/sitemap.xml?x%3D1", getHeaders),
    ("GET", "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Aexample.com/sitemaps/https%3A%2F%2Fexample.com%2Fsitemap.xml%3Fx%3D1", getHeaders),
    ("POST", "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect", postHeaders)
  ]
  for (request, expected) in zip(requests, expectations) {
    #expect(request.httpMethod == expected.0)
    #expect(request.url?.absoluteString == expected.1)
    #expect(request.url?.port == nil)
    #expect(searchConsoleHeaders(request) == expected.2)
  }
  let analytics = try #require(requests[2].httpBody)
  let analyticsJSON = try #require(JSONSerialization.jsonObject(with: analytics) as? [String: Any])
  let expectedAnalytics: [String: Any] = [
    "startDate": "2026-01-01", "endDate": "2026-01-02", "dimensions": ["query", "page"],
    "type": "web", "aggregationType": "byProperty", "rowLimit": 1, "startRow": 0,
    "dataState": "hourly_all", "dimensionFilterGroups": [[
      "groupType": "and", "filters": [
        ["dimension": "query", "expression": "widget", "operator": "contains"],
        ["dimension": "page", "expression": "https://example.com/"]
      ]
    ]]
  ]
  #expect(NSDictionary(dictionary: analyticsJSON).isEqual(to: expectedAnalytics))
  let inspection = try #require(requests[5].httpBody)
  let inspectionJSON = try #require(JSONSerialization.jsonObject(with: inspection) as? [String: String])
  #expect(inspectionJSON == ["inspectionUrl": "https://example.com/page", "siteUrl": "sc-domain:example.com", "languageCode": "en-US"])
}

@Test func everySearchConsoleRouteIsRejectedByWriterAndAdmin() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = try searchConsoleConfig(in: root)
  let query = root.appendingPathComponent("request.json"); try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8).write(to: query)
  let common = ["--profile", "search", "--config", config.path]
  let routes = [
    ["search-console", "sites", "list"],
    ["search-console", "sites", "get", "--site", "sc-domain:example.com"],
    ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", query.path],
    ["search-console", "sitemaps", "list", "--site", "sc-domain:example.com"],
    ["search-console", "sitemaps", "get", "--site", "sc-domain:example.com", "--feedpath", "https://example.com/sitemap.xml"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/page"]
  ]
  for mode in [GatewayMode.writer, .admin] {
    let resolver = SearchConsoleCredentialSpy(); let transport = SearchConsoleRecordingTransport()
    let cli = GoogleMarketingGatewayCLI(mode: mode, transport: transport, credentialResolver: resolver)
    for route in routes { #expect((await cli.run(arguments: route + common, environment: ["SC_TOKEN": "token"])).exitCode == 2) }
    #expect(resolver.calls == 0)
    #expect(transport.requests.isEmpty)
    #expect(cli.usage.contains("No mutations enabled"))
  }
}

@Test func searchConsoleCatalogAndReaderHelpExposeOnlyAcceptedOperations() throws {
  let operations = OperationCatalog.operations.filter { $0.product == .searchConsole }.sorted { $0.id < $1.id }
  #expect(operations.map(\.id) == ["search-console.search-analytics.query", "search-console.sitemaps.get", "search-console.sitemaps.list", "search-console.sites.get", "search-console.sites.list", "search-console.url-inspection.inspect"])
  for operation in operations {
    #expect(operation.capability == .reader)
    #expect(operation.oauthScopes == ["https://www.googleapis.com/auth/webmasters.readonly"])
    #expect(operation.availability == "implemented")
  }
  #expect(OperationCatalog.operations.filter { $0.capability != .reader }.isEmpty)
  let usage = GoogleMarketingGatewayCLI(mode: .reader).usage
  for command in [
    "search-console sites list",
    "search-console sites get --site <property>",
    "search-console search-analytics query --site <property> --request-file <path>",
    "search-console sitemaps list --site <property> [--sitemap-index <url>]",
    "search-console sitemaps get --site <property> --feedpath <url>",
    "search-console url-inspection inspect --site <property> --inspection-url <url> [--language-code <BCP47>]"
  ] { #expect(usage.contains(command)) }
  for mutation in ["submit", "delete", " add "] { #expect(!usage.lowercased().contains(mutation)) }
}

@Test func malformedSearchConsoleInputsDoNotResolveCredentialsOrTransport() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = try searchConsoleConfig(in: root)
  let malformed = root.appendingPathComponent("bad.json"); try Data(#"{"startDate":"bad","endDate":"2026-01-01"}"#.utf8).write(to: malformed)
  let deeplyNested = root.appendingPathComponent("deep.json")
  let nesting = 64
  let deepJSON = #"{"unexpected":"# + String(repeating: "[", count: nesting) + "null" + String(repeating: "]", count: nesting) + "}"
  try Data(deepJSON.utf8).write(to: deeplyNested)
  let strictFailures: [(String, Data)] = [
    ("empty", Data()),
    ("unknown-root", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","extra":true}"#.utf8)),
    ("unknown-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x"}],"extra":true}]}"#.utf8)),
    ("unknown-filter", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x","extra":true}]}]}"#.utf8)),
    ("duplicate-key", Data(#"{"startDate":"2026-01-01","st\u0061rtDate":"2026-01-02","endDate":"2026-01-03"}"#.utf8)),
    ("duplicate-nested-key", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x","expression":"y"}]}]}"#.utf8)),
    ("search-type", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","searchType":"web"}"#.utf8)),
    ("duplicate-dimension", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensions":["query","query"]}"#.utf8)),
    ("unsupported-enum", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","type":"maps"}"#.utf8)),
    ("numeric-string", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":"1"}"#.utf8)),
    ("fraction", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":1.0}"#.utf8)),
    ("exponent", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":1e3}"#.utf8)),
    ("boolean", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":true}"#.utf8)),
    ("overflow", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":999999999999999999999999999999999999}"#.utf8)),
    ("zero-row-limit", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":0}"#.utf8)),
    ("numeric-boundary", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":25001}"#.utf8)),
    ("negative-start-row", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":-1}"#.utf8)),
    ("empty-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[]}]}"#.utf8)),
    ("or-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"or","filters":[{"dimension":"query","expression":"x"}]}]}"#.utf8)),
    ("unsafe-expression", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"\n"}]}]}"#.utf8)),
    ("invalid-json", Data(#"{"startDate":"2026-01-01"#.utf8)),
    ("invalid-utf8", Data([0xFF]))
  ]
  var strictPaths: [String] = []
  for (name, data) in strictFailures {
    let file = root.appendingPathComponent("\(name).json")
    try data.write(to: file)
    strictPaths.append(file.path)
  }
  let oversized = root.appendingPathComponent("oversized.json")
  try Data(repeating: 32, count: 1_048_577).write(to: oversized)
  strictPaths.append(oversized.path)
  let valid = root.appendingPathComponent("valid.json")
  try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8).write(to: valid)
  let link = root.appendingPathComponent("linked.json")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: valid)
  strictPaths.append(link.path)
  let directory = root.appendingPathComponent("directory.json", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  strictPaths.append(directory.path)
  let fifo = root.appendingPathComponent("request.fifo")
  guard mkfifo(fifo.path, mode_t(S_IRUSR | S_IWUSR)) == 0 else {
    throw GatewayError("Unable to create request-file test FIFO", code: .invalidResponse)
  }
  strictPaths.append(fifo.path)
  let cases = [
    ["search-console", "sites", "get", "--site", "https://user@example.com/"],
    ["search-console", "sites", "get", "--site", "https://example.com/a b/"],
    ["search-console", "sitemaps", "list", "--site", "sc-domain:example.com", "--sitemap-index", "https://user:secret@example.com/x"],
    ["search-console", "sitemaps", "get", "--site", "sc-domain:example.com", "--feedpath", "https://example.com/sitemap name.xml"],
    ["search-console", "sitemaps", "get", "--site", "sc-domain:example.com", "--feedpath", "relative"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/x", "--language-code", "en--US"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/x", "--language-code", "en-1!!!"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/x", "--language-code", "en-1901-1901"],
    ["search-console", "url-inspection", "inspect", "--site", "sc-domain:example.com", "--inspection-url", "https://example.com/x", "--language-code", "sl-rozaj-ROZAJ"],
    ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", malformed.path],
    ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", deeplyNested.path],
    ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", root.appendingPathComponent("missing.json").path],
    ["search-console", "sites", "list", "--unexpected", "value"],
    ["search-console", "sites", "get", "--site", "sc-domain:example.com", "--site", "sc-domain:other.example"],
    ["search-console", "sites", "get"],
    ["search-console", "sites", "list", "--site", "sc-domain:example.com"]
  ] + strictPaths.map { ["search-console", "search-analytics", "query", "--site", "sc-domain:example.com", "--request-file", $0] }
  for input in cases {
    let resolver = SearchConsoleCredentialSpy(); let transport = SearchConsoleRecordingTransport()
    let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: transport, credentialResolver: resolver).run(arguments: input + ["--profile", "search", "--config", config.path], environment: ["SC_TOKEN": "token"])
    #expect(result.exitCode == 2)
    #expect(resolver.calls == 0)
    #expect(transport.requests.isEmpty)
  }
}

private func searchConsoleHeaders(_ request: URLRequest) -> [String: String] {
  Dictionary(uniqueKeysWithValues: (request.allHTTPHeaderFields ?? [:]).map { ($0.key.lowercased(), $0.value) })
}

@Test func installedOAuthSearchConsoleProfileDispatchesThroughInjectedResolver() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"installed","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN","oauthClientJSONPath":"client.json","tokenStorePath":"token.json"}]}"#.utf8).write(to: config)
  let resolver = SearchConsoleCredentialSpy(); let transport = SearchConsoleRecordingTransport()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: transport, credentialResolver: resolver).run(
    arguments: ["search-console", "sites", "list", "--profile", "installed", "--config", config.path],
    environment: [:]
  )
  #expect(result.exitCode == 0)
  #expect(resolver.calls == 1)
  #expect(transport.requests.count == 1)
}

@Test func searchConsoleRejectsDifferentProductProfileBeforeCredentialsOrTransport() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"adsense","product":"adsense","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/adsense.readonly"],"accessTokenEnvironmentVariable":"ADSENSE_TOKEN"}]}"#.utf8).write(to: config)
  let resolver = SearchConsoleCredentialSpy(); let transport = SearchConsoleRecordingTransport()
  let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: transport, credentialResolver: resolver).run(
    arguments: ["search-console", "sites", "list", "--profile", "adsense", "--config", config.path],
    environment: ["ADSENSE_TOKEN": "token"]
  )
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("INVALID_PROFILE"))
  #expect(resolver.calls == 0)
  #expect(transport.requests.isEmpty)
}

@Test func searchConsoleProviderAndTransportFailuresAreRedacted() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = try searchConsoleConfig(in: root)
  for transport in [SearchConsoleFailureTransport.provider, .transport] {
    let result = await GoogleMarketingGatewayCLI(mode: .reader, transport: transport).run(arguments: ["search-console", "sites", "list", "--profile", "search", "--config", config.path], environment: ["SC_TOKEN": "token-sentinel"])
    #expect(result.exitCode == 1)
    for secret in ["token-sentinel", "user:secret@example.com", "query-expression", "request-file-content"] { #expect(!result.stderr.contains(secret)); #expect(!result.stdout.contains(secret)) }
  }
}

@Test func searchConsoleCredentialResolverFailuresAreRedacted() async throws {
  let root = try searchConsoleCLITemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
  let config = try searchConsoleConfig(in: root)
  let transport = SearchConsoleRecordingTransport()
  let result = await GoogleMarketingGatewayCLI(
    mode: .reader,
    transport: transport,
    credentialResolver: SearchConsoleFailingCredentialResolver()
  ).run(
    arguments: ["search-console", "sites", "list", "--profile", "search", "--config", config.path],
    environment: ["SC_TOKEN": "token-sentinel"]
  )
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("Credential resolution failed"))
  #expect(transport.requests.isEmpty)
  for secret in ["token-sentinel", "user:secret@example.com", "query-expression", "request-file-content"] {
    #expect(!result.stderr.contains(secret))
    #expect(!result.stdout.contains(secret))
  }
}

private final class SearchConsoleRecordingTransport: HTTPTransport, @unchecked Sendable {
  var requests: [URLRequest] = []
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (Data(#"{"ok":true}"#.utf8), response)
  }
}

private final class SearchConsoleCredentialSpy: ReaderCredentialResolving, @unchecked Sendable {
  var calls = 0
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String { calls += 1; return "token" }
}

private struct SearchConsoleFailingCredentialResolver: ReaderCredentialResolving {
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String {
    throw GatewayError(
      "Bearer token-sentinel https://user:secret@example.com query-expression request-file-content",
      code: .missingCredential,
      exitCode: 2
    )
  }
}

private enum SearchConsoleFailureTransport: HTTPTransport, Sendable {
  case provider, transport
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    switch self {
    case .provider:
      let response = HTTPURLResponse(url: try #require(request.url), statusCode: 403, httpVersion: nil, headerFields: nil)!
      return (Data(#"{"error":{"status":"PERMISSION_DENIED","message":"Bearer token-sentinel https://user:secret@example.com query-expression request-file-content"}}"#.utf8), response)
    case .transport:
      throw GatewayError("Bearer token-sentinel https://user:secret@example.com query-expression request-file-content", code: .transportFailure)
    }
  }
}

private final class SearchConsoleRedirectURLProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []
  nonisolated(unsafe) private static var configuredStatusCode = 307

  static var requests: [URLRequest] {
    lock.lock()
    defer { lock.unlock() }
    return recordedRequests
  }

  static func reset(statusCode: Int) {
    lock.lock()
    defer { lock.unlock() }
    recordedRequests = []
    configuredStatusCode = statusCode
  }

  // swiftlint:disable:next static_over_final_class
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host != "redirect-capture.invalid"
  }

  // swiftlint:disable:next static_over_final_class
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.lock.lock()
    Self.recordedRequests.append(request)
    let statusCode = Self.configuredStatusCode
    Self.lock.unlock()
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: ["Location": "https://redirect-capture.invalid/private-request"]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

private func searchConsoleConfig(in root: URL) throws -> URL {
  let config = root.appendingPathComponent("profiles.json")
  try Data(#"{"profiles":[{"id":"search","product":"search-console","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/webmasters.readonly"],"accessTokenEnvironmentVariable":"SC_TOKEN"}]}"#.utf8).write(to: config)
  return config
}

private func searchConsoleCLITemporaryDirectory() throws -> URL {
  let base = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"), isDirectory: true)
  let directory = base.appendingPathComponent("search-console-cli-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  return directory
}
