import Foundation

public struct GoogleAdsAdminCommand: Sendable {
  private let client: GoogleRESTClient
  private let credentialResolver: any ReaderCredentialResolving

  public init(client: GoogleRESTClient, credentialResolver: any ReaderCredentialResolving) {
    self.client = client
    self.credentialResolver = credentialResolver
  }

  public func run(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    if Array(arguments.prefix(3)) == ["google-ads", "client-accounts", "create"] {
      return try await runAccountCreate(arguments: arguments, environment: environment)
    }
    return try await runManagerLink(arguments: arguments, environment: environment)
  }

  private func runManagerLink(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    guard arguments.count >= 4,
      Array(arguments.prefix(3)) == ["google-ads", "manager-links", "link"],
      ["plan", "validate", "apply"].contains(arguments[3]) else {
      throw GatewayError("Unknown or unavailable admin operation", code: .invalidArgument, exitCode: 2)
    }
    let action = arguments[3]
    let flags = try GoogleAdsMutationSupport.parse(
      Array(arguments.dropFirst(4)),
      allowed: [
        "manager-customer-id", "client-customer-id", "profile", "config",
        "confirm-manager-customer-id", "confirm-client-customer-id"
      ]
    )
    let manager = try GoogleAdsMutationSupport.validatedCustomerID(
      GoogleAdsMutationSupport.required(flags, "manager-customer-id")
    )
    let clientCustomer = try GoogleAdsMutationSupport.validatedCustomerID(
      GoogleAdsMutationSupport.required(flags, "client-customer-id")
    )
    guard manager != clientCustomer else {
      throw GatewayError("Manager and client customer ids must differ", code: .invalidArgument, exitCode: 2)
    }
    let profile = try GoogleAdsMutationSupport.profile(
      capability: .admin, flags: flags, environment: environment
    )
    let loginCustomerId = try GoogleAdsMutationSupport.loginCustomerId(
      profile: profile,
      environment: environment
    )
    guard loginCustomerId == manager else {
      throw GatewayError("Admin profile login customer id must match the manager", code: .invalidProfile, exitCode: 2)
    }
    if action == "plan" {
      return GatewayCommandResult(exitCode: 0, stdout: try GoogleAdsMutationSupport.json(
        GoogleAdsManagerLinkPlan(
          operation: "google-ads.manager-links.link", managerCustomerId: manager,
          clientCustomerId: clientCustomer, profileId: profile.id,
          validateOnly: false, requestSent: false
        )
      ))
    }
    if action == "apply" {
      guard flags["confirm-manager-customer-id"] == manager,
        flags["confirm-client-customer-id"] == clientCustomer else {
        throw GatewayError("Apply requires exact manager and client confirmations", code: .invalidArgument, exitCode: 2)
      }
    } else if flags["confirm-manager-customer-id"] != nil || flags["confirm-client-customer-id"] != nil {
      throw GatewayError("Confirmation is accepted only for apply", code: .invalidArgument, exitCode: 2)
    }
    let credentials = try GoogleAdsMutationSupport.credentials(
      profile: profile, environment: environment, resolver: credentialResolver
    )
    let invitation = try GoogleAdsRequests.inviteManagerLink(
      managerCustomerId: manager, clientCustomerId: clientCustomer,
      validateOnly: action == "validate", accessToken: credentials.accessToken,
      developerToken: credentials.developerToken
    )
    let invitationData = try await client.execute(invitation)
    if action == "validate" {
      guard let output = String(bytes: invitationData, encoding: .utf8) else {
        throw GatewayError("Google Ads returned invalid UTF-8 JSON", code: .invalidResponse)
      }
      return GatewayCommandResult(exitCode: 0, stdout: output + "\n")
    }
    let invitationResource = try Self.invitationResource(from: invitationData)
    let lookup = try GoogleAdsRequests.managerLinkID(
      managerCustomerId: manager, resourceName: invitationResource,
      accessToken: credentials.accessToken, developerToken: credentials.developerToken
    )
    let managerLinkId = try Self.managerLinkID(from: await client.execute(lookup))
    let acceptance = try GoogleAdsRequests.acceptManagerLink(
      clientCustomerId: clientCustomer, managerCustomerId: manager,
      managerLinkId: managerLinkId, validateOnly: false,
      accessToken: credentials.accessToken, developerToken: credentials.developerToken
    )
    let acceptanceData = try await client.execute(acceptance)
    guard let acceptanceOutput = String(bytes: acceptanceData, encoding: .utf8) else {
      throw GatewayError("Google Ads returned invalid UTF-8 JSON", code: .invalidResponse)
    }
    return GatewayCommandResult(exitCode: 0, stdout: try GoogleAdsMutationSupport.json(
      GoogleAdsManagerLinkResult(
        managerCustomerId: manager, clientCustomerId: clientCustomer,
        invitationResourceName: invitationResource, managerLinkId: managerLinkId,
        acceptanceResponse: acceptanceOutput
      )
    ))
  }

  private func runAccountCreate(
    arguments: [String],
    environment: [String: String]
  ) async throws -> GatewayCommandResult {
    guard arguments.count >= 4, ["plan", "apply"].contains(arguments[3]) else {
      throw GatewayError("Unknown or unavailable admin operation", code: .invalidArgument, exitCode: 2)
    }
    let action = arguments[3]
    let flags = try GoogleAdsMutationSupport.parse(
      Array(arguments.dropFirst(4)),
      allowed: ["request-file", "profile", "config", "confirm-manager-customer-id"]
    )
    let input = try GoogleAdsCustomerAccountInput.load(
      path: GoogleAdsMutationSupport.required(flags, "request-file")
    )
    let profile = try GoogleAdsMutationSupport.profile(
      capability: .admin, flags: flags, environment: environment
    )
    let loginCustomerId = try GoogleAdsMutationSupport.loginCustomerId(
      profile: profile, environment: environment
    )
    guard loginCustomerId == input.managerCustomerId else {
      throw GatewayError(
        "Admin profile login customer id must match the manager",
        code: .invalidProfile, exitCode: 2
      )
    }
    if action == "plan" {
      return GatewayCommandResult(exitCode: 0, stdout: try GoogleAdsMutationSupport.json(
        GoogleAdsCustomerAccountPlan(
          operation: "google-ads.client-accounts.create",
          managerCustomerId: input.managerCustomerId,
          descriptiveName: input.descriptiveName,
          currencyCode: input.currencyCode,
          timeZone: input.timeZone,
          profileId: profile.id,
          requestSent: false
        )
      ))
    }
    guard flags["confirm-manager-customer-id"] == input.managerCustomerId else {
      throw GatewayError(
        "Apply requires exact manager customer id confirmation",
        code: .invalidArgument, exitCode: 2
      )
    }
    let credentials = try GoogleAdsMutationSupport.credentials(
      profile: profile, environment: environment, resolver: credentialResolver
    )
    let request = try GoogleAdsRequests.createCustomerClient(
      input: input,
      accessToken: credentials.accessToken,
      developerToken: credentials.developerToken
    )
    let data = try await client.execute(request)
    guard let output = String(bytes: data, encoding: .utf8) else {
      throw GatewayError("Google Ads returned invalid UTF-8 JSON", code: .invalidResponse)
    }
    return GatewayCommandResult(exitCode: 0, stdout: output + "\n")
  }

  private static func invitationResource(from data: Data) throws -> String {
    do {
      return try JSONDecoder().decode(GoogleAdsManagerInvitationResponse.self, from: data).result.resourceName
    } catch {
      throw GatewayError("Google Ads invitation response is invalid", code: .invalidResponse)
    }
  }

  private static func managerLinkID(from data: Data) throws -> String {
    do {
      let value = try JSONDecoder().decode(GoogleAdsManagerLinkLookupResponse.self, from: data)
      guard value.results.count == 1 else {
        throw GatewayError("Google Ads manager link lookup was not unique", code: .invalidResponse)
      }
      return try GoogleAdsMutationSupport.validatedCustomerID(value.results[0].customerClientLink.managerLinkId)
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError("Google Ads manager link lookup response is invalid", code: .invalidResponse)
    }
  }

  public static let usage = """
  google-ads manager-links link <plan|validate|apply>
    --manager-customer-id <digits> --client-customer-id <digits>
    --profile <id> --config <path>
    [--confirm-manager-customer-id <digits> --confirm-client-customer-id <digits>]

  apply creates a PENDING CustomerClientLink from the manager, resolves its
  manager link id with GoogleAdsService.Search, and accepts it as ACTIVE from
  the client. Exact manager and client confirmations are required.

  google-ads client-accounts create <plan|apply> --request-file <path>
    --profile <id> --config <path> [--confirm-manager-customer-id <digits>]

  apply creates a new client account directly below the configured manager.
  The request fixes descriptive name, currency, and time zone at creation;
  exact manager confirmation is required. Google does not offer validateOnly
  for CreateCustomerClient, so plan is the only zero-write preview.
  """
}

private struct GoogleAdsCustomerAccountPlan: Encodable {
  let operation: String
  let managerCustomerId: String
  let descriptiveName: String
  let currencyCode: String
  let timeZone: String
  let profileId: String
  let requestSent: Bool
}

private struct GoogleAdsManagerLinkPlan: Encodable {
  let operation: String
  let managerCustomerId: String
  let clientCustomerId: String
  let profileId: String
  let validateOnly: Bool
  let requestSent: Bool
}

private struct GoogleAdsManagerLinkResult: Encodable {
  let managerCustomerId: String
  let clientCustomerId: String
  let invitationResourceName: String
  let managerLinkId: String
  let acceptanceResponse: String
}

private struct GoogleAdsManagerInvitationResponse: Decodable {
  struct Result: Decodable { let resourceName: String }
  let result: Result
}

private struct GoogleAdsManagerLinkLookupResponse: Decodable {
  struct Row: Decodable {
    let customerClientLink: GoogleAdsManagerLinkLookupLink
  }
  let results: [Row]
}

private struct GoogleAdsManagerLinkLookupLink: Decodable { let managerLinkId: String }
