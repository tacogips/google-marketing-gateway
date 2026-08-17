import Foundation

enum GoogleAdsMutationSupport {
  static let scope = "https://www.googleapis.com/auth/adwords"

  static func parse(
    _ arguments: [String],
    allowed: Set<String>,
    switches: Set<String> = []
  ) throws -> [String: String] {
    var flags: [String: String] = [:]
    var index = 0
    while index < arguments.count {
      let key = arguments[index]
      guard key.hasPrefix("--"), key.count > 2 else { throw invalidOption() }
      let name = String(key.dropFirst(2))
      guard allowed.contains(name), flags[name] == nil else { throw invalidOption() }
      if switches.contains(name) {
        flags[name] = "true"
        index += 1
        continue
      }
      guard index + 1 < arguments.count else { throw invalidOption() }
      flags[name] = arguments[index + 1]
      index += 2
    }
    return flags
  }

  static func required(_ flags: [String: String], _ name: String) throws -> String {
    guard let value = flags[name], !value.isEmpty else {
      throw GatewayError("--\(name) is required", code: .invalidArgument, exitCode: 2)
    }
    return value
  }

  static func profile(
    capability: GatewayMode,
    flags: [String: String],
    environment: [String: String]
  ) throws -> CredentialProfile {
    let path = flags["config"] ?? environment["GOOGLE_MARKETING_GATEWAY_CONFIG"]
    guard let path else {
      throw GatewayError(
        "--config or GOOGLE_MARKETING_GATEWAY_CONFIG is required",
        code: .invalidConfiguration,
        exitCode: 2
      )
    }
    let selected = try CredentialProfileConfiguration.load(path: path)
      .profile(id: required(flags, "profile"))
    guard selected.product == .googleAds,
      selected.capability == capability,
      selected.oauthScopes == [scope] else {
      throw GatewayError(
        "Credential profile does not match the Google Ads \(capability.rawValue) operation",
        code: .invalidProfile,
        exitCode: 2
      )
    }
    return selected
  }

  static func credentials(
    profile: CredentialProfile,
    environment: [String: String],
    resolver: any ReaderCredentialResolving
  ) throws -> (accessToken: String, developerToken: String) {
    let accessToken = try resolver.accessToken(profile: profile, environment: environment)
    guard let developerName = profile.developerTokenEnvironmentVariable,
      let developerToken = environment[developerName],
      HTTPHeaderValue.isCredential(developerToken, maximumBytes: 4_096) else {
      throw GatewayError("Google Ads developer token is unavailable", code: .missingCredential, exitCode: 2)
    }
    return (accessToken, developerToken)
  }

  static func loginCustomerId(
    profile: CredentialProfile,
    environment: [String: String]
  ) throws -> String? {
    guard let variable = profile.loginCustomerIdEnvironmentVariable else { return nil }
    guard let value = environment[variable],
      CredentialProfileConfiguration.isDigits(value, maximum: 20) else {
      throw GatewayError(
        "Google Ads login customer id environment value is required",
        code: .missingCredential,
        exitCode: 2
      )
    }
    return value
  }

  static func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard let output = String(bytes: data, encoding: .utf8) else {
      throw GatewayError("Unable to encode Google Ads mutation output", code: .invalidResponse)
    }
    return output + "\n"
  }

  static func validatedCustomerID(_ value: String) throws -> String {
    guard CredentialProfileConfiguration.isDigits(value, maximum: 20) else {
      throw GatewayError("Google Ads customer id is invalid", code: .invalidArgument, exitCode: 2)
    }
    return value
  }

  private static func invalidOption() -> GatewayError {
    GatewayError("Google Ads mutation option is not allowed", code: .invalidArgument, exitCode: 2)
  }
}
