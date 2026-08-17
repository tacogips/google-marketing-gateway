import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension GoogleAdsRequests {
  static func createCustomerClient(
    input: GoogleAdsCustomerAccountInput,
    accessToken: String,
    developerToken: String
  ) throws -> URLRequest {
    try input.validate()
    let body = try JSONEncoder().encode(CreateCustomerClientBody(customerClient: .init(
      descriptiveName: input.descriptiveName,
      currencyCode: input.currencyCode,
      timeZone: input.timeZone
    )))
    return try request(
      path: "/\(apiVersion)/customers/\(input.managerCustomerId):createCustomerClient",
      accessToken: accessToken, developerToken: developerToken,
      loginCustomerId: input.managerCustomerId, method: "POST", body: body
    )
  }

  static func generateKeywordIdeas(
    input: GoogleAdsKeywordIdeasInput,
    accessToken: String,
    developerToken: String,
    loginCustomerId: String? = nil
  ) throws -> URLRequest {
    try input.validate()
    let body = try JSONEncoder().encode(GenerateKeywordIdeasBody(input: input))
    return try request(
      path: "/\(apiVersion)/customers/\(input.customerId):generateKeywordIdeas",
      accessToken: accessToken, developerToken: developerToken,
      loginCustomerId: loginCustomerId, method: "POST", body: body
    )
  }

  static func inviteManagerLink(
    managerCustomerId: String,
    clientCustomerId: String,
    validateOnly: Bool,
    accessToken: String,
    developerToken: String
  ) throws -> URLRequest {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(managerCustomerId)
    _ = try GoogleAdsMutationSupport.validatedCustomerID(clientCustomerId)
    let body = try JSONEncoder().encode(CustomerClientLinkMutateBody(
      operation: .init(create: .init(
        clientCustomer: "customers/\(clientCustomerId)", status: "PENDING"
      )),
      validateOnly: validateOnly
    ))
    return try request(
      path: "/\(apiVersion)/customers/\(managerCustomerId)/customerClientLinks:mutate",
      accessToken: accessToken, developerToken: developerToken,
      loginCustomerId: managerCustomerId, method: "POST", body: body
    )
  }

  static func managerLinkID(
    managerCustomerId: String,
    resourceName: String,
    accessToken: String,
    developerToken: String
  ) throws -> URLRequest {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(managerCustomerId)
    guard resourceName.hasPrefix("customers/\(managerCustomerId)/customerClientLinks/"),
      !resourceName.contains("'") else {
      throw GatewayError("Google Ads customer client link resource is invalid", code: .invalidArgument, exitCode: 2)
    }
    return try search(
      customerId: managerCustomerId,
      query: "SELECT customer_client_link.manager_link_id FROM customer_client_link WHERE customer_client_link.resource_name = '\(resourceName)'",
      pageToken: nil, accessToken: accessToken, developerToken: developerToken,
      loginCustomerId: managerCustomerId
    )
  }

  static func acceptManagerLink(
    clientCustomerId: String,
    managerCustomerId: String,
    managerLinkId: String,
    validateOnly: Bool,
    accessToken: String,
    developerToken: String
  ) throws -> URLRequest {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(clientCustomerId)
    _ = try GoogleAdsMutationSupport.validatedCustomerID(managerCustomerId)
    _ = try GoogleAdsMutationSupport.validatedCustomerID(managerLinkId)
    let resourceName = "customers/\(clientCustomerId)/customerManagerLinks/\(managerCustomerId)~\(managerLinkId)"
    let body = try JSONEncoder().encode(CustomerManagerLinkMutateBody(
      operations: [.init(
        update: .init(resourceName: resourceName, status: "ACTIVE"),
        updateMask: "status"
      )],
      validateOnly: validateOnly
    ))
    return try request(
      path: "/\(apiVersion)/customers/\(clientCustomerId)/customerManagerLinks:mutate",
      accessToken: accessToken, developerToken: developerToken,
      loginCustomerId: clientCustomerId, method: "POST", body: body
    )
  }

  static func createSearchCampaign(
    input: GoogleAdsSearchCampaignInput,
    validateOnly: Bool,
    accessToken: String,
    developerToken: String,
    loginCustomerId: String? = nil
  ) throws -> URLRequest {
    try input.validate()
    let body = try JSONEncoder().encode(SearchCampaignMutateBody(input: input, validateOnly: validateOnly))
    return try request(
      path: "/\(apiVersion)/customers/\(input.customerId)/googleAds:mutate",
      accessToken: accessToken,
      developerToken: developerToken,
      loginCustomerId: loginCustomerId,
      method: "POST",
      body: body
    )
  }

  static func removeResource(
    customerId: String,
    collection: String,
    resourceName: String,
    validateOnly: Bool,
    accessToken: String,
    developerToken: String,
    loginCustomerId: String? = nil
  ) throws -> URLRequest {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(customerId)
    guard GoogleAdsRemovalResource.allowedCollections.contains(collection) else {
      throw GatewayError("Google Ads removal collection is invalid", code: .invalidArgument, exitCode: 2)
    }
    let body = try JSONEncoder().encode(RemoveMutateBody(
      operations: [RemoveOperation(remove: resourceName)],
      partialFailure: false,
      validateOnly: validateOnly,
      responseContentType: "RESOURCE_NAME_ONLY"
    ))
    return try request(
      path: "/\(apiVersion)/customers/\(customerId)/\(collection):mutate",
      accessToken: accessToken,
      developerToken: developerToken,
      loginCustomerId: loginCustomerId,
      method: "POST",
      body: body
    )
  }
}

private struct SearchCampaignMutateBody: Encodable {
  let mutateOperations: [SearchCampaignMutateOperation]
  let partialFailure = false
  let validateOnly: Bool
  let responseContentType = "RESOURCE_NAME_ONLY"

  init(input: GoogleAdsSearchCampaignInput, validateOnly: Bool) {
    let customer = "customers/\(input.customerId)"
    let budget = "\(customer)/campaignBudgets/-1"
    let campaign = "\(customer)/campaigns/-2"
    let adGroup = "\(customer)/adGroups/-3"
    var operations: [SearchCampaignMutateOperation] = [
      .campaignBudget(CampaignBudgetOperation(create: .init(
        resourceName: budget, name: "\(input.campaignName) budget",
        amountMicros: input.dailyBudgetMicros, deliveryMethod: "STANDARD", explicitlyShared: false
      ))),
      .campaign(CampaignOperation(create: .init(
        resourceName: campaign, name: input.campaignName, status: "ENABLED",
        advertisingChannelType: "SEARCH", campaignBudget: budget, manualCpc: EmptyObject(),
        containsEuPoliticalAdvertising: "DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING",
        networkSettings: .init(
          targetGoogleSearch: true, targetSearchNetwork: false,
          targetContentNetwork: false, targetPartnerSearchNetwork: false
        )
      ))),
      .campaignCriterion(CampaignCriterionOperation(create: .init(
        campaign: campaign,
        location: .init(geoTargetConstant: "geoTargetConstants/\(input.geoTargetConstantId)"),
        language: nil
      ))),
      .campaignCriterion(CampaignCriterionOperation(create: .init(
        campaign: campaign, location: nil,
        language: .init(languageConstant: "languageConstants/\(input.languageConstantId)")
      ))),
      .adGroup(AdGroupOperation(create: .init(
        resourceName: adGroup, name: input.adGroupName, status: "ENABLED",
        campaign: campaign, type: "SEARCH_STANDARD", cpcBidMicros: input.cpcBidMicros
      )))
    ]
    operations += input.keywords.map {
      .adGroupCriterion(AdGroupCriterionOperation(create: .init(
        adGroup: adGroup, status: "ENABLED", keyword: .init(text: $0.text, matchType: $0.matchType.rawValue)
      )))
    }
    operations.append(.adGroupAd(AdGroupAdOperation(create: .init(
      adGroup: adGroup, status: "ENABLED",
      ad: .init(
        finalUrls: input.finalUrls,
        responsiveSearchAd: .init(
          headlines: input.headlines.map(AdTextAsset.init(text:)),
          descriptions: input.descriptions.map(AdTextAsset.init(text:))
        )
      )
    ))))
    mutateOperations = operations
    self.validateOnly = validateOnly
  }
}

private enum SearchCampaignMutateOperation: Encodable {
  case campaignBudget(CampaignBudgetOperation)
  case campaign(CampaignOperation)
  case campaignCriterion(CampaignCriterionOperation)
  case adGroup(AdGroupOperation)
  case adGroupCriterion(AdGroupCriterionOperation)
  case adGroupAd(AdGroupAdOperation)

  private enum CodingKeys: String, CodingKey {
    case campaignBudgetOperation, campaignOperation, campaignCriterionOperation
    case adGroupOperation, adGroupCriterionOperation, adGroupAdOperation
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .campaignBudget(let value): try container.encode(value, forKey: .campaignBudgetOperation)
    case .campaign(let value): try container.encode(value, forKey: .campaignOperation)
    case .campaignCriterion(let value): try container.encode(value, forKey: .campaignCriterionOperation)
    case .adGroup(let value): try container.encode(value, forKey: .adGroupOperation)
    case .adGroupCriterion(let value): try container.encode(value, forKey: .adGroupCriterionOperation)
    case .adGroupAd(let value): try container.encode(value, forKey: .adGroupAdOperation)
    }
  }
}

private struct CampaignBudgetOperation: Encodable { let create: CampaignBudgetCreate }
private struct CampaignBudgetCreate: Encodable {
  let resourceName: String; let name: String; let amountMicros: Int64
  let deliveryMethod: String; let explicitlyShared: Bool
}
private struct CampaignOperation: Encodable { let create: CampaignCreate }
private struct CampaignCreate: Encodable {
  let resourceName: String; let name: String; let status: String; let advertisingChannelType: String
  let campaignBudget: String; let manualCpc: EmptyObject
  let containsEuPoliticalAdvertising: String; let networkSettings: NetworkSettings
}
private struct EmptyObject: Encodable {}
private struct NetworkSettings: Encodable {
  let targetGoogleSearch: Bool; let targetSearchNetwork: Bool
  let targetContentNetwork: Bool; let targetPartnerSearchNetwork: Bool
}
private struct CampaignCriterionOperation: Encodable { let create: CampaignCriterionCreate }
private struct CampaignCriterionCreate: Encodable {
  let campaign: String; let location: LocationInfo?; let language: LanguageInfo?
}
private struct LocationInfo: Encodable { let geoTargetConstant: String }
private struct LanguageInfo: Encodable { let languageConstant: String }
private struct AdGroupOperation: Encodable { let create: AdGroupCreate }
private struct AdGroupCreate: Encodable {
  let resourceName: String; let name: String; let status: String
  let campaign: String; let type: String; let cpcBidMicros: Int64
}
private struct AdGroupCriterionOperation: Encodable { let create: AdGroupCriterionCreate }
private struct AdGroupCriterionCreate: Encodable {
  let adGroup: String; let status: String; let keyword: KeywordInfo
}
private struct KeywordInfo: Encodable { let text: String; let matchType: String }
private struct AdGroupAdOperation: Encodable { let create: AdGroupAdCreate }
private struct AdGroupAdCreate: Encodable { let adGroup: String; let status: String; let ad: ResponsiveAd }
private struct ResponsiveAd: Encodable { let finalUrls: [String]; let responsiveSearchAd: ResponsiveSearchAd }
private struct ResponsiveSearchAd: Encodable { let headlines: [AdTextAsset]; let descriptions: [AdTextAsset] }
private struct AdTextAsset: Encodable { let text: String }
private struct RemoveMutateBody: Encodable {
  let operations: [RemoveOperation]; let partialFailure: Bool; let validateOnly: Bool; let responseContentType: String
}
private struct RemoveOperation: Encodable { let remove: String }
private struct CustomerClientLinkMutateBody: Encodable {
  let operation: CustomerClientLinkOperation
  let validateOnly: Bool
}
private struct CustomerClientLinkOperation: Encodable { let create: CustomerClientLinkCreate }
private struct CustomerClientLinkCreate: Encodable { let clientCustomer: String; let status: String }
private struct CustomerManagerLinkMutateBody: Encodable {
  let operations: [CustomerManagerLinkOperation]
  let validateOnly: Bool
}
private struct CustomerManagerLinkOperation: Encodable {
  let update: CustomerManagerLinkUpdate
  let updateMask: String
}
private struct CustomerManagerLinkUpdate: Encodable { let resourceName: String; let status: String }
private struct CreateCustomerClientBody: Encodable { let customerClient: CustomerClientCreate }
private struct CustomerClientCreate: Encodable {
  let descriptiveName: String
  let currencyCode: String
  let timeZone: String
}
private struct GenerateKeywordIdeasBody: Encodable {
  let language: String
  let geoTargetConstants: [String]
  let includeAdultKeywords = false
  let keywordPlanNetwork = "GOOGLE_SEARCH"
  let pageSize: Int?
  let keywordSeed: KeywordSeed?
  let urlSeed: URLSeed?
  let keywordAndUrlSeed: KeywordAndURLSeed?

  init(input: GoogleAdsKeywordIdeasInput) {
    language = "languageConstants/\(input.languageConstantId)"
    geoTargetConstants = input.geoTargetConstantIds.map { "geoTargetConstants/\($0)" }
    pageSize = input.pageSize
    if let url = input.url, !input.keywords.isEmpty {
      keywordAndUrlSeed = KeywordAndURLSeed(keywords: input.keywords, url: url)
      keywordSeed = nil
      urlSeed = nil
    } else if let url = input.url {
      keywordAndUrlSeed = nil
      keywordSeed = nil
      urlSeed = URLSeed(url: url)
    } else {
      keywordAndUrlSeed = nil
      keywordSeed = KeywordSeed(keywords: input.keywords)
      urlSeed = nil
    }
  }
}
private struct KeywordSeed: Encodable { let keywords: [String] }
private struct URLSeed: Encodable { let url: String }
private struct KeywordAndURLSeed: Encodable { let keywords: [String]; let url: String }
