import Foundation

public enum MarketingProduct: String, Codable, CaseIterable, Sendable {
  case googleAds = "google-ads"
  case displayVideo360 = "display-video-360"
  case bidManager = "bid-manager"
  case campaignManager360 = "campaign-manager-360"
  case searchAds360 = "search-ads-360"
  case adManager = "ad-manager"
  case merchantCenter = "merchant-center"
  case adsense
  case admob
  case searchConsole = "search-console"
  case analyticsData = "analytics-data"
  case analyticsAdmin = "analytics-admin"
  case youtubeAnalytics = "youtube-analytics"
  case youtubeData = "youtube-data"
  case tagManager = "tag-manager"
  case adsDataHub = "ads-data-hub"
  case authorizedBuyers = "authorized-buyers"
  case realtimeBidding = "realtime-bidding"
  case businessProfile = "business-profile"
  case localServicesAds = "local-services-ads"
  case trends
}

public struct OperationDescriptor: Codable, Equatable, Sendable {
  public let id: String
  public let product: MarketingProduct
  public let capability: GatewayMode
  public let oauthScopes: [String]
  public let availability: String
  public let apiFamily: String
  public let apiVersion: String
  public let stability: String
  public let origin: String
  public let providerMethod: String
  public let requestKind: String
  public let spendRisk: String
  public let requestBodyPolicy: String
  public let responsePolicy: String
  public let verification: String
  public let confirmationPolicy: String
  public let duplicateRiskHorizon: String
  public let reconciliationPolicy: String
  public let planPayloadPolicy: String

  public init(
    id: String,
    product: MarketingProduct,
    capability: GatewayMode,
    oauthScopes: [String],
    availability: String = "implemented",
    apiFamily: String? = nil,
    apiVersion: String? = nil,
    stability: String = "ga",
    origin: String? = nil,
    providerMethod: String? = nil,
    requestKind: String = "read",
    spendRisk: String = "none",
    requestBodyPolicy: String = "none",
    responsePolicy: String = "json",
    verification: String = "deterministic-tests",
    confirmationPolicy: String = "none",
    duplicateRiskHorizon: String = "none",
    reconciliationPolicy: String = "not-applicable",
    planPayloadPolicy: String = "none"
  ) {
    self.id = id
    self.product = product
    self.capability = capability
    self.oauthScopes = oauthScopes
    self.availability = availability
    self.apiFamily = apiFamily ?? product.defaultAPIFamily
    self.apiVersion = apiVersion ?? product.defaultAPIVersion
    self.stability = stability
    self.origin = origin ?? product.defaultOrigin
    self.providerMethod = providerMethod ?? id
    self.requestKind = requestKind
    self.spendRisk = spendRisk
    self.requestBodyPolicy = requestBodyPolicy
    self.responsePolicy = responsePolicy
    self.verification = verification
    self.confirmationPolicy = confirmationPolicy
    self.duplicateRiskHorizon = duplicateRiskHorizon
    self.reconciliationPolicy = reconciliationPolicy
    self.planPayloadPolicy = planPayloadPolicy
  }

  public var isImplemented: Bool { availability == "implemented" }

  public func validateForCatalog() throws {
    guard !id.isEmpty, !apiFamily.isEmpty, !apiVersion.isEmpty, !providerMethod.isEmpty,
      !availability.isEmpty, !stability.isEmpty, !requestKind.isEmpty, !spendRisk.isEmpty,
      !requestBodyPolicy.isEmpty, !responsePolicy.isEmpty, !verification.isEmpty,
      !confirmationPolicy.isEmpty, !duplicateRiskHorizon.isEmpty,
      !reconciliationPolicy.isEmpty, !planPayloadPolicy.isEmpty else {
      throw GatewayError("Operation descriptor metadata is incomplete", code: .invalidConfiguration, exitCode: 2)
    }
    guard origin.hasPrefix("https://"), !origin.contains("*"),
      URL(string: origin)?.host != nil,
      URL(string: origin)?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty == true else {
      throw GatewayError("Operation descriptor origin must be a fixed official origin", code: .invalidConfiguration, exitCode: 2)
    }
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
      oauthScopes: ["https://www.googleapis.com/auth/adwords"],
      requestBodyPolicy: "local-gaql-file"
    ),
    OperationDescriptor(
      id: "google-ads.customer-client-links.list",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"],
      providerMethod: "GoogleAdsService.Search",
      requestBodyPolicy: "provider-generated-gaql"
    ),
    OperationDescriptor(
      id: "google-ads.customer-clients.list",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"],
      providerMethod: "GoogleAdsService.Search",
      requestBodyPolicy: "provider-generated-gaql"
    ),
    OperationDescriptor(
      id: "google-ads.customer-users.list",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"],
      providerMethod: "GoogleAdsService.Search",
      requestBodyPolicy: "provider-generated-gaql"
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
      id: "admob.accounts.adUnits.createNative",
      product: .admob,
      capability: .writer,
      oauthScopes: ["https://www.googleapis.com/auth/admob.monetization"],
      availability: "preview-only-durable-apply-pending",
      apiVersion: "v1beta",
      stability: "beta-limited-access",
      providerMethod: "accounts.adUnits.create",
      requestKind: "mutate",
      spendRisk: "indirect-serving",
      requestBodyPolicy: "typed-native-ad-unit-only",
      responsePolicy: "bounded-json",
      verification: "deterministic-no-live-mutation",
      confirmationPolicy: "apply-unavailable",
      duplicateRiskHorizon: "unbounded-after-ambiguous-transmission",
      reconciliationPolicy: "apply-unavailable-until-reviewed-durable-state",
      planPayloadPolicy: "not-persisted; zero-network-preview-only"
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
      availability: "official-alpha-allowlist-required",
      apiVersion: "alpha",
      stability: "allowlisted",
      origin: "https://trends.googleapis.com",
      verification: "catalog-only"
    )
  ] + plannedInventory

  public static var implementedOperations: [OperationDescriptor] {
    operations.filter(\.isImplemented)
  }

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
    guard let operation = operations.first(where: { $0.id == id && $0.isImplemented }) else {
      throw GatewayError("Operation is not implemented", code: .invalidArgument, exitCode: 2)
    }
    return operation
  }

  public static func validate() throws {
    try operations.forEach { try $0.validateForCatalog() }
  }

  private static let plannedInventory: [OperationDescriptor] = [
    inventory("google-ads.manager-links.mutate", .googleAds, .admin, "planned-reviewed-allowlist-required", requestKind: "admin-mutate", spendRisk: "serving-risk"),
    inventory("display-video-360.advertisers.list", .displayVideo360, .reader, "planned"),
    inventory("display-video-360.campaigns.create", .displayVideo360, .writer, "planned-reviewed-allowlist-required", requestKind: "mutate", spendRisk: "serving-risk"),
    inventory("bid-manager.queries.run", .bidManager, .reader, "planned"),
    inventory("campaign-manager-360.placements.list", .campaignManager360, .reader, "planned"),
    inventory("campaign-manager-360.offline-conversions.insert", .campaignManager360, .writer, "planned-reviewed-allowlist-required", requestKind: "upload", spendRisk: "attribution-risk"),
    inventory("search-ads-360.searchAds360.search", .searchAds360, .reader, "planned"),
    inventory("search-ads-360.reports.legacy", .searchAds360, .reader, "deprecated", stability: "deprecated"),
    inventory("search-ads-360.conversion.insert", .searchAds360, .writer, "planned-reviewed-allowlist-required", requestKind: "upload", spendRisk: "attribution-risk"),
    inventory("ad-manager.networks.list", .adManager, .reader, "beta-rest-planned", stability: "beta"),
    inventory("ad-manager.soap.orders.list", .adManager, .reader, "soap-planned"),
    inventory("merchant-center.accounts.list", .merchantCenter, .reader, "planned"),
    inventory("merchant-center.products.insert", .merchantCenter, .writer, "planned-reviewed-allowlist-required", requestKind: "mutate", spendRisk: "commerce-risk"),
    inventory("analytics-admin.account-summaries.list", .analyticsAdmin, .reader, "planned"),
    inventory("analytics-admin.access-bindings.list", .analyticsAdmin, .admin, "planned-sensitive-reader", requestKind: "admin-read"),
    inventory("tag-manager.containers.list", .tagManager, .reader, "planned"),
    inventory("tag-manager.versions.publish", .tagManager, .admin, "planned-reviewed-allowlist-required", requestKind: "publish", spendRisk: "serving-risk"),
    inventory("youtube-data.channels.list", .youtubeData, .reader, "planned"),
    inventory("youtube-analytics.reports.query", .youtubeAnalytics, .reader, "planned"),
    inventory("ads-data-hub.customers.list", .adsDataHub, .reader, "planned"),
    inventory("ads-data-hub.queries.start", .adsDataHub, .writer, "planned-reviewed-allowlist-required", requestKind: "query-execution", spendRisk: "none"),
    inventory("authorized-buyers.marketplace.clients.list", .authorizedBuyers, .reader, "restricted-entitlement-required", stability: "restricted"),
    inventory("realtime-bidding.bidders.list", .realtimeBidding, .reader, "restricted-entitlement-required", stability: "restricted"),
    inventory("business-profile.locations.list", .businessProfile, .reader, "planned"),
    inventory("business-profile.reviews.reply", .businessProfile, .writer, "planned-reviewed-allowlist-required", requestKind: "mutate", spendRisk: "reputation-risk"),
    inventory("local-services-ads.accounts.search", .localServicesAds, .reader, "planned"),
    inventory("trends.scraping", .trends, .reader, "excluded-unofficial", stability: "excluded", origin: "https://trends.googleapis.com", requestKind: "excluded", responsePolicy: "none")
  ]

  private static func inventory(
    _ id: String,
    _ product: MarketingProduct,
    _ capability: GatewayMode,
    _ availability: String,
    stability: String = "ga",
    origin: String? = nil,
    requestKind: String = "read",
    spendRisk: String = "none",
    responsePolicy: String = "json"
  ) -> OperationDescriptor {
    OperationDescriptor(
      id: id,
      product: product,
      capability: capability,
      oauthScopes: product.readerOAuthScopes,
      availability: availability,
      stability: stability,
      origin: origin,
      requestKind: requestKind,
      spendRisk: spendRisk,
      verification: "catalog-only",
    )
  }
}

private extension MarketingProduct {
  var defaultAPIFamily: String { rawValue }

  var defaultAPIVersion: String {
    switch self {
    case .googleAds: "v25"
    case .analyticsData: "v1beta"
    case .searchConsole: "v1"
    case .adsense: "v2"
    case .admob: "v1"
    case .displayVideo360: "v4"
    case .bidManager: "v2"
    case .campaignManager360: "v5"
    case .searchAds360: "v0"
    case .adManager: "v1beta"
    case .merchantCenter: "merchantapi"
    case .analyticsAdmin: "v1beta"
    case .tagManager: "v2"
    case .youtubeData: "v3"
    case .youtubeAnalytics: "v2"
    case .adsDataHub: "v1"
    case .authorizedBuyers: "v1"
    case .realtimeBidding: "v1"
    case .businessProfile: "v1"
    case .localServicesAds: "v1"
    case .trends: "alpha"
    }
  }

  var defaultOrigin: String {
    switch self {
    case .googleAds: "https://googleads.googleapis.com"
    case .analyticsData: "https://analyticsdata.googleapis.com"
    case .searchConsole: "https://searchconsole.googleapis.com"
    case .adsense: "https://adsense.googleapis.com"
    case .admob: "https://admob.googleapis.com"
    case .displayVideo360: "https://displayvideo.googleapis.com"
    case .bidManager: "https://doubleclickbidmanager.googleapis.com"
    case .campaignManager360: "https://dfareporting.googleapis.com"
    case .searchAds360: "https://searchads360.googleapis.com"
    case .adManager: "https://admanager.googleapis.com"
    case .merchantCenter: "https://merchantapi.googleapis.com"
    case .analyticsAdmin: "https://analyticsadmin.googleapis.com"
    case .tagManager: "https://tagmanager.googleapis.com"
    case .youtubeData: "https://youtube.googleapis.com"
    case .youtubeAnalytics: "https://youtubeanalytics.googleapis.com"
    case .adsDataHub: "https://adsdatahub.googleapis.com"
    case .authorizedBuyers: "https://authorizedbuyersmarketplace.googleapis.com"
    case .realtimeBidding: "https://realtimebidding.googleapis.com"
    case .businessProfile: "https://businessprofile.googleapis.com"
    case .localServicesAds: "https://localservices.googleapis.com"
    case .trends: "https://trends.googleapis.com"
    }
  }
}
