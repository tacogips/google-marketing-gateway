import Foundation

public struct GoogleAdsWriterCommand: Sendable {
  private let client: GoogleRESTClient
  private let credentialResolver: any ReaderCredentialResolving

  public init(client: GoogleRESTClient, credentialResolver: any ReaderCredentialResolving) {
    self.client = client
    self.credentialResolver = credentialResolver
  }

  public func run(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    guard arguments.count >= 4,
      Array(arguments.prefix(3)) == ["google-ads", "search-campaigns", "create"] else {
      throw GatewayError("Unknown or unavailable writer operation", code: .invalidArgument, exitCode: 2)
    }
    let action = arguments[3]
    guard ["plan", "validate", "apply"].contains(action) else {
      throw GatewayError("Unknown or unavailable writer operation", code: .invalidArgument, exitCode: 2)
    }
    let flags = try GoogleAdsMutationSupport.parse(
      Array(arguments.dropFirst(4)),
      allowed: ["request-file", "profile", "config", "confirm-customer-id"]
    )
    let input = try GoogleAdsSearchCampaignInput.load(
      path: GoogleAdsMutationSupport.required(flags, "request-file")
    )
    let profile = try GoogleAdsMutationSupport.profile(
      capability: .writer, flags: flags, environment: environment
    )
    if action == "plan" {
      return GatewayCommandResult(exitCode: 0, stdout: try GoogleAdsMutationSupport.json(
        GoogleAdsSearchCampaignPlan(
          operation: "google-ads.search-campaigns.create", method: "POST",
          origin: "https://googleads.googleapis.com",
          path: "/\(GoogleAdsRequests.apiVersion)/customers/\(input.customerId)/googleAds:mutate",
          customerId: input.customerId, profileId: profile.id,
          validateOnly: false, requestSent: false, input: input
        )
      ))
    }
    if action == "apply" {
      let confirmation = try GoogleAdsMutationSupport.required(flags, "confirm-customer-id")
      guard confirmation == input.customerId else {
        throw GatewayError("--confirm-customer-id must exactly match the request customer", code: .invalidArgument, exitCode: 2)
      }
    } else if flags["confirm-customer-id"] != nil {
      throw GatewayError("Confirmation is accepted only for apply", code: .invalidArgument, exitCode: 2)
    }
    let credentials = try GoogleAdsMutationSupport.credentials(
      profile: profile, environment: environment, resolver: credentialResolver
    )
    let loginCustomerId = try GoogleAdsMutationSupport.loginCustomerId(
      profile: profile,
      environment: environment
    )
    let request = try GoogleAdsRequests.createSearchCampaign(
      input: input, validateOnly: action == "validate",
      accessToken: credentials.accessToken, developerToken: credentials.developerToken,
      loginCustomerId: loginCustomerId
    )
    let response = try await client.execute(request)
    guard let output = String(bytes: response, encoding: .utf8) else {
      throw GatewayError("Google Ads returned invalid UTF-8 JSON", code: .invalidResponse)
    }
    return GatewayCommandResult(exitCode: 0, stdout: output + "\n")
  }

  public static let usage = """
  google-ads search-campaigns create <plan|validate|apply> --request-file <path> --profile <id> --config <path> [--confirm-customer-id <digits>]

  plan sends no request. validate uses Google Ads validateOnly. apply creates an
  enabled budget, Search campaign, location/language criteria, ad group,
  keywords, and responsive Search ad atomically. apply requires exact customer
  confirmation. Daily budget and CPC bid are each capped at 500,000,000 micros.
  """
}
