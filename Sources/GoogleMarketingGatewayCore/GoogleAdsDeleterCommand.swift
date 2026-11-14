import Foundation

enum GoogleAdsRemovalResource: String, CaseIterable, Sendable {
  case campaigns
  case campaignBudgets = "campaign-budgets"
  case campaignCriteria = "campaign-criteria"
  case adGroups = "ad-groups"
  case adGroupCriteria = "ad-group-criteria"
  case adGroupAds = "ad-group-ads"

  static let allowedCollections = Set(allCases.map(\.apiCollection))

  var apiCollection: String {
    switch self {
    case .campaigns: "campaigns"
    case .campaignBudgets: "campaignBudgets"
    case .campaignCriteria: "campaignCriteria"
    case .adGroups: "adGroups"
    case .adGroupCriteria: "adGroupCriteria"
    case .adGroupAds: "adGroupAds"
    }
  }

  var resourceSegment: String { apiCollection }

  func validate(resourceName: String, customerId: String) throws {
    let prefix = "customers/\(customerId)/\(resourceSegment)/"
    guard resourceName.hasPrefix(prefix) else { throw invalid() }
    let identifier = String(resourceName.dropFirst(prefix.count))
    let pieces = identifier.split(separator: "~", omittingEmptySubsequences: false)
    let expectedPieces = self == .adGroupAds || self == .adGroupCriteria || self == .campaignCriteria ? 2 : 1
    guard pieces.count == expectedPieces,
      pieces.allSatisfy({ CredentialProfileConfiguration.isDigits(String($0), maximum: 20) }) else {
      throw invalid()
    }
  }

  private func invalid() -> GatewayError {
    GatewayError("Google Ads resource name does not match the removal route", code: .invalidArgument, exitCode: 2)
  }
}

public struct GoogleAdsDeleterCommand: Sendable {
  private let client: GoogleRESTClient
  private let credentialResolver: any ReaderCredentialResolving

  public init(client: GoogleRESTClient, credentialResolver: any ReaderCredentialResolving) {
    self.client = client
    self.credentialResolver = credentialResolver
  }

  public func run(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    guard arguments.count >= 4, arguments[0] == "google-ads",
      let resource = GoogleAdsRemovalResource(rawValue: arguments[1]), arguments[2] == "remove",
      ["plan", "validate", "apply"].contains(arguments[3]) else {
      throw GatewayError("Unknown or unavailable deleter operation", code: .invalidArgument, exitCode: 2)
    }
    let action = arguments[3]
    let flags = try GoogleAdsMutationSupport.parse(
      Array(arguments.dropFirst(4)),
      allowed: ["customer-id", "resource-name", "profile", "config", "confirm-resource-name"]
    )
    let customerId = try GoogleAdsMutationSupport.validatedCustomerID(
      GoogleAdsMutationSupport.required(flags, "customer-id")
    )
    let resourceName = try GoogleAdsMutationSupport.required(flags, "resource-name")
    try resource.validate(resourceName: resourceName, customerId: customerId)
    let profile = try GoogleAdsMutationSupport.profile(
      capability: .deleter, flags: flags, environment: environment
    )
    if action == "plan" {
      let output = RemovalPlan(
        operation: "google-ads.\(resource.rawValue).remove", method: "POST",
        origin: "https://googleads.googleapis.com",
        path: "/\(GoogleAdsRequests.apiVersion)/customers/\(customerId)/\(resource.apiCollection):mutate",
        customerId: customerId, resourceName: resourceName, profileId: profile.id,
        providerEffect: "status REMOVED", validateOnly: false, requestSent: false
      )
      return GatewayCommandResult(exitCode: 0, stdout: try GoogleAdsMutationSupport.json(output))
    }
    if action == "apply" {
      let confirmation = try GoogleAdsMutationSupport.required(flags, "confirm-resource-name")
      guard confirmation == resourceName else {
        throw GatewayError("--confirm-resource-name must exactly match the target", code: .invalidArgument, exitCode: 2)
      }
    } else if flags["confirm-resource-name"] != nil {
      throw GatewayError("Confirmation is accepted only for apply", code: .invalidArgument, exitCode: 2)
    }
    let credentials = try GoogleAdsMutationSupport.credentials(
      profile: profile, environment: environment, resolver: credentialResolver
    )
    let loginCustomerId = try GoogleAdsMutationSupport.loginCustomerId(
      profile: profile,
      environment: environment
    )
    let request = try GoogleAdsRequests.removeResource(
      customerId: customerId, collection: resource.apiCollection, resourceName: resourceName,
      validateOnly: action == "validate", accessToken: credentials.accessToken,
      developerToken: credentials.developerToken, loginCustomerId: loginCustomerId
    )
    let response = try await client.execute(request)
    guard let output = String(bytes: response, encoding: .utf8) else {
      throw GatewayError("Google Ads returned invalid UTF-8 JSON", code: .invalidResponse)
    }
    return GatewayCommandResult(exitCode: 0, stdout: output + "\n")
  }

  public static let usage = """
  google-ads <campaigns|campaign-budgets|campaign-criteria|ad-groups|
    ad-group-criteria|ad-group-ads> remove <plan|validate|apply>
    --customer-id <digits> --resource-name <name> --profile <id>
    --config <path> [--confirm-resource-name <name>]

  plan sends no request. validate uses Google Ads validateOnly. apply requires
  the full resource name as confirmation and performs the provider remove
  operation, whose documented effect is status REMOVED.
  """
}

private struct RemovalPlan: Encodable {
  let operation: String; let method: String; let origin: String; let path: String
  let customerId: String; let resourceName: String; let profileId: String
  let providerEffect: String; let validateOnly: Bool; let requestSent: Bool
}
