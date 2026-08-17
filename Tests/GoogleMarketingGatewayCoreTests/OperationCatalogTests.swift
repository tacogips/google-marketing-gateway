import Testing
@testable import GoogleMarketingGatewayCore

@Test func catalogMetadataIsCompleteAndFixedOriginOnly() throws {
  try OperationCatalog.validate()
  #expect(OperationCatalog.operations.allSatisfy { !$0.origin.contains("*") })
  #expect(OperationCatalog.operations.allSatisfy { $0.origin.hasPrefix("https://") })
  #expect(OperationCatalog.operations.allSatisfy { !$0.apiFamily.isEmpty && !$0.apiVersion.isEmpty })
  #expect(OperationCatalog.operations.contains { $0.id == "display-video-360.advertisers.list" && $0.availability == "planned" })
  #expect(OperationCatalog.operations.contains { $0.id == "ad-manager.networks.list" && $0.availability == "beta-rest-planned" })
  #expect(OperationCatalog.operations.contains { $0.id == "authorized-buyers.marketplace.clients.list" && $0.availability == "restricted-entitlement-required" })
  #expect(OperationCatalog.operations.contains { $0.id == "search-ads-360.reports.legacy" && $0.availability == "deprecated" })
  #expect(OperationCatalog.operations.contains { $0.id == "trends.api" && $0.availability == "official-alpha-allowlist-required" })
  #expect(OperationCatalog.operations.contains { $0.id == "trends.scraping" && $0.availability == "excluded-unofficial" })
}

@Test func operationLookupReturnsOnlyImplementedDispatchableRows() throws {
  #expect(try OperationCatalog.operation(id: "google-ads.customer-client-links.list").isImplemented)
  #expect(try OperationCatalog.operation(id: "google-ads.customer-clients.list").isImplemented)
  #expect(try OperationCatalog.operation(id: "google-ads.customer-users.list").isImplemented)
  #expect(try OperationCatalog.operation(id: "google-ads.manager-links.link").isImplemented)
  #expect(try OperationCatalog.operation(id: "google-ads.client-accounts.create").isImplemented)
  #expect(try OperationCatalog.operation(id: "google-ads.keyword-ideas.generate").isImplemented)
  #expect(throws: GatewayError.self) {
    _ = try OperationCatalog.operation(id: "display-video-360.advertisers.list")
  }
}

@Test func googleAdsAgencyDescriptorsExposeExactReaderMetadata() throws {
  let ids = [
    "google-ads.customer-client-links.list",
    "google-ads.customer-clients.list",
    "google-ads.customer-users.list"
  ]
  for id in ids {
    let descriptor = try OperationCatalog.operation(id: id)
    #expect(descriptor.product == .googleAds)
    #expect(descriptor.capability == .reader)
    #expect(descriptor.oauthScopes == ["https://www.googleapis.com/auth/adwords"])
    #expect(descriptor.apiVersion == "v25")
    #expect(descriptor.origin == "https://googleads.googleapis.com")
    #expect(descriptor.providerMethod == "GoogleAdsService.Search")
    #expect(descriptor.requestKind == "read")
    #expect(descriptor.spendRisk == "none")
    #expect(descriptor.requestBodyPolicy == "provider-generated-gaql")
  }
}

@Test func googleAdsMutationsHaveSeparatedWriterAndDeleterMetadata() throws {
  let create = try OperationCatalog.operation(id: "google-ads.search-campaigns.create")
  #expect(create.capability == .writer)
  #expect(create.requestKind == "mutate")
  #expect(create.spendRisk == "ad-spend")
  let removals = OperationCatalog.implementedOperations.filter {
    $0.product == .googleAds && $0.requestKind == "delete"
  }
  #expect(removals.count == 6)
  #expect(removals.allSatisfy { $0.capability == .deleter })
  #expect(removals.allSatisfy { $0.confirmationPolicy == "exact-resource-name-on-apply" })
  #expect(OperationCatalog.implementedOperations
    .filter { $0.capability == .writer }
    .allSatisfy { $0.requestKind != "delete" })
}

@Test func invalidDescriptorFixturesFailDeterministically() {
  let invalidOrigins = ["", "http://googleads.googleapis.com", "https://*.googleapis.com", "https://googleads.googleapis.com/v25"]
  for origin in invalidOrigins {
    let descriptor = OperationDescriptor(
      id: "fixture.invalid",
      product: .googleAds,
      capability: .reader,
      oauthScopes: ["https://www.googleapis.com/auth/adwords"],
      origin: origin
    )
    #expect(throws: GatewayError.self) {
      try descriptor.validateForCatalog()
    }
  }
}
