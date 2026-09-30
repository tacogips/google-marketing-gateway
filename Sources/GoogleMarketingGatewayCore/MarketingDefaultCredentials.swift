import Foundation

/// Synthesizes the same product/role profile for login and ordinary requests.
enum MarketingDefaultCredentials {
  static func profile(
    product: MarketingProduct, capability: GatewayMode,
    flags: [String: String], environment: [String: String]
  ) throws -> CredentialProfile {
    if let path = flags["config"] ?? environment["GOOGLE_MARKETING_GATEWAY_CONFIG"] {
      let configuration = try CredentialProfileConfiguration.load(path: path)
      let selected: CredentialProfile
      if let id = flags["profile"] { selected = try configuration.profile(id: id) } else {
        let eligible = configuration.profiles.filter { $0.product == product && $0.capability == capability }
        guard eligible.count == 1, let only = eligible.first else {
          throw GatewayError("Select --profile; configuration has no unique matching profile", code: .invalidProfile, exitCode: 2)
        }
        selected = only
      }
      guard selected.product == product, selected.capability == capability else {
        throw GatewayError("Credential profile does not match this product and executable", code: .invalidProfile, exitCode: 2)
      }
      let effective = try marketingProfilePaths(selected, environment: environment)
      if let tokenPath = effective.tokenStorePath,
         URL(fileURLWithPath: tokenPath).standardizedFileURL == URL(fileURLWithPath: path).standardizedFileURL {
        throw GatewayError("Token-store path must differ from configuration path", code: .invalidConfiguration, exitCode: 2)
      }
      return effective
    }
    let scopes: [String]
    if capability == .reader { scopes = product.readerOAuthScopes
    } else if product == .googleAds { scopes = [GoogleAdsMutationSupport.scope]
    } else if product == .admob && capability == .writer { scopes = ["https://www.googleapis.com/auth/admob.monetization"]
    } else { scopes = [] }
    guard !scopes.isEmpty else {
      throw GatewayError("This product has no implemented OAuth profile for this executable", code: .invalidProfile, exitCode: 2)
    }
    let id = flags["profile"] ?? product.rawValue + "-" + capability.rawValue
    let root: URL
    if let state = environment["XDG_STATE_HOME"], !state.isEmpty {
      guard state.hasPrefix("/"), CredentialProfileConfiguration.isSafePath(state) else {
        throw GatewayError("XDG_STATE_HOME must be an absolute safe path", code: .invalidConfiguration, exitCode: 2)
      }
      root = URL(fileURLWithPath: state)
    } else { root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/state") }
    // Validate identifiers before using them in filesystem paths.
    let template = CredentialProfile(
      id: id, product: product, capability: capability, oauthScopes: scopes,
      accessTokenEnvironmentVariable: "GOOGLE_MARKETING_GATEWAY_ACCESS_TOKEN",
      developerTokenEnvironmentVariable: product == .googleAds ? "GOOGLE_MARKETING_GATEWAY_DEVELOPER_TOKEN" : nil
    )
    _ = try CredentialProfileConfiguration(profiles: [template])
    let path = root.appendingPathComponent("google-marketing-gateway/credentials")
      .appendingPathComponent(product.rawValue).appendingPathComponent(capability.rawValue)
      .appendingPathComponent(id + ".json").path
    let selected = try marketingProfilePaths(CredentialProfile(
      id: id, product: product, capability: capability, oauthScopes: scopes,
      accessTokenEnvironmentVariable: template.accessTokenEnvironmentVariable, tokenStorePath: path,
      developerTokenEnvironmentVariable: template.developerTokenEnvironmentVariable
    ), environment: environment)
    _ = try CredentialProfileConfiguration(profiles: [selected])
    if let clientPath = selected.oauthClientJSONPath,
       URL(fileURLWithPath: clientPath).standardizedFileURL.path == URL(fileURLWithPath: selected.tokenStorePath ?? path).standardizedFileURL.path {
      throw GatewayError("OAuth client and token-store paths must differ", code: .invalidConfiguration, exitCode: 2)
    }
    return selected
  }
}
