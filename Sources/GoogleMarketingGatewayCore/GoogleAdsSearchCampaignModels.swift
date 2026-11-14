import Foundation

public enum GoogleAdsKeywordMatchType: String, Codable, Sendable {
  case exact = "EXACT"
  case phrase = "PHRASE"
  case broad = "BROAD"
}

public struct GoogleAdsSearchCampaignInput: Codable, Equatable, Sendable {
  private static let maximumDailyBudgetMicros: Int64 = 500_000_000
  private static let maximumCPCBidMicros: Int64 = 500_000_000

  public struct Keyword: Codable, Equatable, Sendable {
    public let text: String
    public let matchType: GoogleAdsKeywordMatchType
  }

  public let customerId: String
  public let campaignName: String
  public let dailyBudgetMicros: Int64
  public let adGroupName: String
  public let cpcBidMicros: Int64
  public let geoTargetConstantId: String
  public let languageConstantId: String
  public let keywords: [Keyword]
  public let headlines: [String]
  public let descriptions: [String]
  public let finalUrls: [String]

  public static func load(path: String) throws -> Self {
    guard CredentialProfileConfiguration.isSafePath(path) else { throw invalid() }
    let data = try SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1_048_576)
    do {
      let value = try JSONDecoder().decode(Self.self, from: data)
      try value.validate()
      return value
    } catch let error as GatewayError {
      throw error
    } catch {
      throw invalid()
    }
  }

  public func validate() throws {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(customerId)
    try Self.validateText(campaignName, maximumCharacters: 128)
    try Self.validateText(adGroupName, maximumCharacters: 255)
    guard (1...Self.maximumDailyBudgetMicros).contains(dailyBudgetMicros),
      (1...Self.maximumCPCBidMicros).contains(cpcBidMicros),
      CredentialProfileConfiguration.isDigits(geoTargetConstantId, maximum: 20),
      CredentialProfileConfiguration.isDigits(languageConstantId, maximum: 20),
      (1...20).contains(keywords.count), Set(keywords.map { "\($0.matchType.rawValue):\($0.text)" }).count == keywords.count,
      (3...15).contains(headlines.count), (2...4).contains(descriptions.count), (1...3).contains(finalUrls.count) else {
      throw Self.invalid()
    }
    for keyword in keywords { try Self.validateText(keyword.text, maximumCharacters: 80) }
    for headline in headlines { try Self.validateText(headline, maximumCharacters: 30) }
    for description in descriptions { try Self.validateText(description, maximumCharacters: 90) }
    for finalURL in finalUrls {
      guard let components = URLComponents(string: finalURL), components.scheme == "https",
        components.host != nil, components.user == nil, components.password == nil else { throw Self.invalid() }
    }
  }

  private static func validateText(_ value: String, maximumCharacters: Int) throws {
    guard (1...maximumCharacters).contains(value.count), value.utf8.count <= 1_024,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !value.unicodeScalars.contains(where: { $0.value <= 31 || (127...159).contains($0.value) }) else {
      throw invalid()
    }
  }

  private static func invalid() -> GatewayError {
    GatewayError("Google Ads Search campaign input is invalid", code: .invalidArgument, exitCode: 2)
  }
}

struct GoogleAdsSearchCampaignPlan: Encodable, Sendable {
  let operation: String
  let method: String
  let origin: String
  let path: String
  let customerId: String
  let profileId: String
  let validateOnly: Bool
  let requestSent: Bool
  let input: GoogleAdsSearchCampaignInput
}
