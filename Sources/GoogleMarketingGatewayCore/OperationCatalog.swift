import Foundation

public enum MarketingProduct: String, Codable, CaseIterable, Sendable {
  case googleAds = "google-ads"
  case adsense
  case admob
  case searchConsole = "search-console"
  case analyticsData = "analytics-data"
  case analyticsAdmin = "analytics-admin"
  case merchant
  case youtubeAnalytics = "youtube-analytics"
  case youtubeData = "youtube-data"
  case tagManager = "tag-manager"
  case trends
}

public struct OperationDescriptor: Codable, Equatable, Sendable {
  public let id: String
  public let product: MarketingProduct
  public let capability: GatewayMode
  public let oauthScopes: [String]
  public let availability: String

  public init(
    id: String,
    product: MarketingProduct,
    capability: GatewayMode,
    oauthScopes: [String],
    availability: String = "implemented"
  ) {
    self.id = id
    self.product = product
    self.capability = capability
    self.oauthScopes = oauthScopes
    self.availability = availability
  }
}

public enum OperationCatalog {
  public static let operations: [OperationDescriptor] = [
    OperationDescriptor(
      id: "google-ads.accessible-customers.list",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"]
    ),
    OperationDescriptor(
      id: "google-ads.search",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"]
    ),
    OperationDescriptor(
      id: "analytics-data.metadata.get",
      product: .analyticsData,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/analytics.readonly"]
    ),
    OperationDescriptor(
      id: "analytics-data.reports.run",
      product: .analyticsData,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/analytics.readonly"]
    ),
    OperationDescriptor(
      id: "analytics-data.compatibility.check",
      product: .analyticsData,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/analytics.readonly"]
    ),
    OperationDescriptor(id: "search-console.sites.list", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(id: "search-console.sites.get", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(id: "search-console.search-analytics.query", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(id: "search-console.sitemaps.list", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(id: "search-console.sitemaps.get", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(id: "search-console.url-inspection.inspect", product: .searchConsole, capability: .reader, oauthScopes: ["https://www.googleapis.com/auth/webmasters.readonly"]),
    OperationDescriptor(
      id: "adsense.accounts.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.payments.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.accounts.adclients.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.accounts.adclients.adunits.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.accounts.sites.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.accounts.policyIssues.list",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "adsense.accounts.reports.generate",
      product: .adsense,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adsense.readonly"]
    ),
    OperationDescriptor(
      id: "admob.accounts.list",
      product: .admob,
      capability: .reader,
      oauthScopes: [
        "https://www.googleapis.com/auth/admob.readonly",
        "https://www.googleapis.com/auth/admob.report"
      ]
    ),
    OperationDescriptor(
      id: "admob.accounts.apps.list",
      product: .admob,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/admob.readonly"]
    ),
    OperationDescriptor(
      id: "admob.accounts.adUnits.list",
      product: .admob,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/admob.readonly"]
    ),
    OperationDescriptor(
      id: "admob.accounts.networkReport.generate",
      product: .admob,
      capability: .reader,
      oauthScopes: [
        "https://www.googleapis.com/auth/admob.readonly",
        "https://www.googleapis.com/auth/admob.report"
      ]
    ),
    OperationDescriptor(
      id: "admob.accounts.mediationReport.generate",
      product: .admob,
      capability: .reader,
      oauthScopes: [
        "https://www.googleapis.com/auth/admob.readonly",
        "https://www.googleapis.com/auth/admob.report"
      ]
    ),
    OperationDescriptor(
      id: "trends.api",
      product: .trends,
      capability: .reader,
      oauthScopes: [],
      availability: "official-alpha-allowlist-required"
    )
  ]

  public static func encoded(pretty: Bool = true) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    let data = try encoder.encode(operations)
    guard let output = String(bytes: data, encoding: .utf8) else {
      throw GatewayError("Unable to encode the operation catalog", code: .invalidResponse)
    }
    return output + "\n"
  }

  public static func operation(id: String) throws -> OperationDescriptor {
    guard let operation = operations.first(where: { $0.id == id && $0.availability == "implemented" }) else {
      throw GatewayError("Operation is not implemented", code: .invalidArgument, exitCode: 2)
    }
    return operation
  }
}
