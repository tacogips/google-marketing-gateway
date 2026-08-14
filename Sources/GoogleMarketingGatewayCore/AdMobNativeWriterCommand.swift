import Foundation

public struct AdMobNativeWriterCommand: Sendable {
  public init() {}

  public func run(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    switch Array(arguments.prefix(4)) {
    case ["admob", "adunits", "create-native", "plan"]:
      return try await plan(arguments: Array(arguments.dropFirst(4)), environment: environment)
    default:
      throw GatewayError("Unknown or unavailable writer operation", code: .invalidArgument, exitCode: 2)
    }
  }

  public static let usage = """
  admob adunits create-native plan --account accounts/pub-<digits> --app-id ca-app-pub-<digits>~<digits> --display-name <name> --ad-types RICH_MEDIA[,VIDEO] --profile <id> --config <path>

  This command is a zero-network request preview. Apply remains unavailable
  until the durable anti-replay store is implemented and reviewed.
  """

  private func plan(arguments: [String], environment: [String: String]) async throws -> GatewayCommandResult {
    let flags = try parse(arguments, allowed: ["account", "app-id", "display-name", "ad-types", "profile", "config"])
    let input = try AdMobNativeAdUnitInput(
      account: required(flags, "account"), appID: required(flags, "app-id"),
      displayName: required(flags, "display-name"), adTypes: try adTypes(required(flags, "ad-types"))
    )
    let profile = try writerProfile(flags: flags, environment: environment)
    return GatewayCommandResult(exitCode: 0, stdout: try json(PlanOutput(
      operation: "admob.accounts.adUnits.createNative", method: "POST", origin: "https://admob.googleapis.com",
      path: "/v1beta/\(input.account)/adUnits", input: AdMobNativeAdUnitCreateBody(input: input),
      profileID: profile.id, applyAvailable: false, requestSent: false
    )))
  }

  private func writerProfile(flags: [String: String], environment: [String: String]) throws -> CredentialProfile {
    let path = flags["config"] ?? environment["GOOGLE_MARKETING_GATEWAY_CONFIG"]
    guard let path else { throw GatewayError("--config or GOOGLE_MARKETING_GATEWAY_CONFIG is required", code: .invalidConfiguration, exitCode: 2) }
    let profile = try CredentialProfileConfiguration.load(path: path).profile(id: required(flags, "profile"))
    let expectedScope = "https://www.googleapis.com/auth/admob.monetization"
    guard profile.product == .admob, profile.capability == .writer, profile.oauthScopes == [expectedScope] else {
      throw GatewayError("Writer profile does not match the AdMob Native create operation", code: .invalidProfile, exitCode: 2)
    }
    return profile
  }

  private func adTypes(_ raw: String) throws -> [AdMobNativeAdUnitInput.AdType] {
    let values = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    guard !values.isEmpty else { throw GatewayError("--ad-types is invalid", code: .invalidArgument, exitCode: 2) }
    return try values.map {
      guard let value = AdMobNativeAdUnitInput.AdType(rawValue: $0) else {
        throw GatewayError("--ad-types is invalid", code: .invalidArgument, exitCode: 2)
      }
      return value
    }
  }

  private func parse(_ arguments: [String], allowed: Set<String>, switches: Set<String> = []) throws -> [String: String] {
    var flags: [String: String] = [:]
    var index = 0
    while index < arguments.count {
      let key = arguments[index]
      guard key.hasPrefix("--"), key.count > 2 else { throw GatewayError("Expected --name value option", code: .invalidArgument, exitCode: 2) }
      let name = String(key.dropFirst(2))
      guard allowed.contains(name), flags[name] == nil else { throw GatewayError("Writer option is not allowed", code: .invalidArgument, exitCode: 2) }
      if switches.contains(name) { flags[name] = "true"; index += 1; continue }
      guard index + 1 < arguments.count else { throw GatewayError("Expected --name value option", code: .invalidArgument, exitCode: 2) }
      flags[name] = arguments[index + 1]
      index += 2
    }
    return flags
  }

  private func required(_ flags: [String: String], _ name: String) throws -> String {
    guard let value = flags[name], !value.isEmpty else { throw GatewayError("--\(name) is required", code: .invalidArgument, exitCode: 2) }
    return value
  }

  private func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
  }
}

private struct PlanOutput: Encodable {
  let operation: String
  let method: String
  let origin: String
  let path: String
  let input: AdMobNativeAdUnitCreateBody
  let profileID: String
  let applyAvailable: Bool
  let requestSent: Bool
}
