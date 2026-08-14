import Foundation

public struct CredentialProfile: Codable, Equatable, Sendable {
  public let id: String
  public let product: MarketingProduct
  public let capability: GatewayMode
  public let oauthScopes: [String]
  public let accessTokenEnvironmentVariable: String
  public let oauthClientJSONPath: String?
  public let tokenStorePath: String?
  public let developerTokenEnvironmentVariable: String?
  public let loginCustomerId: String?

  public init(
    id: String,
    product: MarketingProduct,
    capability: GatewayMode,
    oauthScopes: [String],
    accessTokenEnvironmentVariable: String,
    oauthClientJSONPath: String? = nil,
    tokenStorePath: String? = nil,
    developerTokenEnvironmentVariable: String? = nil,
    loginCustomerId: String? = nil
  ) {
    self.id = id
    self.product = product
    self.capability = capability
    self.oauthScopes = oauthScopes
    self.accessTokenEnvironmentVariable = accessTokenEnvironmentVariable
    self.oauthClientJSONPath = oauthClientJSONPath
    self.tokenStorePath = tokenStorePath
    self.developerTokenEnvironmentVariable = developerTokenEnvironmentVariable
    self.loginCustomerId = loginCustomerId
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, product, capability, oauthScopes, accessTokenEnvironmentVariable
    case oauthClientJSONPath, tokenStorePath, developerTokenEnvironmentVariable, loginCustomerId
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try decoder.container(keyedBy: AnyCodingKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.rawValue))
    guard raw.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError("Credential profile contains an unsupported field", code: .invalidConfiguration, exitCode: 2)
    }
    self.init(
      id: try container.decode(String.self, forKey: .id),
      product: try container.decode(MarketingProduct.self, forKey: .product),
      capability: try container.decode(GatewayMode.self, forKey: .capability),
      oauthScopes: try container.decode([String].self, forKey: .oauthScopes),
      accessTokenEnvironmentVariable: try container.decode(String.self, forKey: .accessTokenEnvironmentVariable),
      oauthClientJSONPath: try container.decodeIfPresent(String.self, forKey: .oauthClientJSONPath),
      tokenStorePath: try container.decodeIfPresent(String.self, forKey: .tokenStorePath),
      developerTokenEnvironmentVariable: try container.decodeIfPresent(String.self, forKey: .developerTokenEnvironmentVariable),
      loginCustomerId: try container.decodeIfPresent(String.self, forKey: .loginCustomerId)
    )
  }
}

private struct AnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
  init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

public struct CredentialProfileConfiguration: Codable, Equatable, Sendable {
  public let profiles: [CredentialProfile]

  private enum CodingKeys: String, CodingKey, CaseIterable { case profiles }

  public init(profiles: [CredentialProfile]) throws { self.profiles = profiles; try validate() }

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.container(keyedBy: AnyCodingKey.self)
    guard raw.allKeys.allSatisfy({ $0.stringValue == CodingKeys.profiles.rawValue }) else {
      throw GatewayError("Credential profile config contains an unsupported field", code: .invalidConfiguration, exitCode: 2)
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(profiles: container.decode([CredentialProfile].self, forKey: .profiles))
  }

  public static func decode(_ data: Data) throws -> CredentialProfileConfiguration {
    do {
      let configuration = try JSONDecoder().decode(CredentialProfileConfiguration.self, from: data)
      try configuration.validate()
      return configuration
    } catch let error as GatewayError { throw error
    } catch { throw GatewayError("Credential profile config is not valid JSON", code: .invalidConfiguration, exitCode: 2) }
  }

  public static func load(path: String) throws -> CredentialProfileConfiguration {
    guard CredentialProfileConfiguration.isSafePath(path) else {
      throw GatewayError("Credential profile config path is invalid", code: .invalidArgument, exitCode: 2)
    }
    let configURL = URL(fileURLWithPath: path).standardizedFileURL
    do {
      return try decode(Data(contentsOf: configURL)).resolvingPaths(
        relativeTo: configURL.deletingLastPathComponent(),
        configURL: configURL
      )
    } catch let error as GatewayError { throw error
    } catch { throw GatewayError("Unable to read credential profile config", code: .invalidConfiguration, exitCode: 2) }
  }

  public func profile(id: String) throws -> CredentialProfile {
    guard let profile = profiles.first(where: { $0.id == id }) else {
      throw GatewayError("Credential profile was not found", code: .invalidProfile, exitCode: 2)
    }
    return profile
  }

  private func resolvingPaths(relativeTo directory: URL, configURL: URL) throws -> CredentialProfileConfiguration {
    let resolvedProfiles = try profiles.map { profile in
      CredentialProfile(
        id: profile.id,
        product: profile.product,
        capability: profile.capability,
        oauthScopes: profile.oauthScopes,
        accessTokenEnvironmentVariable: profile.accessTokenEnvironmentVariable,
        oauthClientJSONPath: try resolvedPath(profile.oauthClientJSONPath, relativeTo: directory),
        tokenStorePath: try resolvedPath(profile.tokenStorePath, relativeTo: directory),
        developerTokenEnvironmentVariable: profile.developerTokenEnvironmentVariable,
        loginCustomerId: profile.loginCustomerId
      )
    }
    try validateResolvedPaths(profiles: resolvedProfiles, configURL: configURL)
    return try CredentialProfileConfiguration(profiles: resolvedProfiles)
  }

  private func resolvedPath(_ value: String?, relativeTo directory: URL) throws -> String? {
    guard let value else { return nil }
    guard Self.isSafePath(value) else { throw configurationError("Configured path is unsafe") }
    let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : directory.appendingPathComponent(value)
    return url.standardizedFileURL.path
  }

  private func validateResolvedPaths(profiles: [CredentialProfile], configURL: URL) throws {
    let configPath = configURL.path
    var storePaths = Set<String>()
    var clientPaths = Set<String>()
    for profile in profiles {
      if let store = profile.tokenStorePath {
        guard store != configPath, storePaths.insert(store).inserted, !clientPaths.contains(store) else {
          throw configurationError("Token-store path collides with another configured path")
        }
      }
      if let client = profile.oauthClientJSONPath {
        guard client != configPath, !storePaths.contains(client) else {
          throw configurationError("OAuth client path collides with another configured path")
        }
        clientPaths.insert(client)
      }
    }
  }

  private func validate() throws {
    guard !profiles.isEmpty else { throw configurationError("At least one credential profile is required") }
    var ids = Set<String>()
    for profile in profiles {
      guard Self.isSafeProfileID(profile.id), ids.insert(profile.id).inserted else {
        throw configurationError("Credential profile id is invalid or duplicated")
      }
      guard profile.capability == .reader else { throw configurationError("Credential profiles must use reader capability") }
      let configuredScopes = Set(profile.oauthScopes)
      let allowedScopes = Set(profile.product.readerOAuthScopes)
      guard !configuredScopes.isEmpty, configuredScopes.count == profile.oauthScopes.count,
        configuredScopes.isSubset(of: allowedScopes) else {
        throw configurationError("Credential profile OAuth scopes do not match its product reader scopes")
      }
      if profile.product == .googleAds || profile.product == .analyticsData || profile.product == .searchConsole {
        guard configuredScopes == allowedScopes else { throw configurationError("Credential profile OAuth scope bundle is not exact") }
      }
      guard Self.isSafeEnvironmentVariable(profile.accessTokenEnvironmentVariable) else {
        throw configurationError("Access-token environment-variable name is unsafe")
      }
      let clientPath = profile.oauthClientJSONPath
      let storePath = profile.tokenStorePath
      guard (clientPath == nil) == (storePath == nil) else {
        throw configurationError("OAuth client and token-store paths must be configured together")
      }
      if let clientPath, !Self.isSafePath(clientPath) { throw configurationError("OAuth client path is unsafe") }
      if let storePath, !Self.isSafePath(storePath) { throw configurationError("Token-store path is unsafe") }
      if profile.product == .googleAds {
        guard let developer = profile.developerTokenEnvironmentVariable, Self.isSafeEnvironmentVariable(developer) else {
          throw configurationError("Google Ads profiles require a developer-token environment-variable reference")
        }
        if let login = profile.loginCustomerId, !Self.isDigits(login, maximum: 20) {
          throw configurationError("Google Ads login customer id is invalid")
        }
      } else if profile.developerTokenEnvironmentVariable != nil || profile.loginCustomerId != nil {
        throw configurationError("Google Ads fields are not allowed for this product")
      }
    }
  }

  static func isSafePath(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 1_024 && !value.utf8.contains(where: { $0 < 32 || $0 == 127 })
  }
  static func isDigits(_ value: String, maximum: Int) -> Bool {
    !value.isEmpty && value.utf8.count <= maximum && value.utf8.allSatisfy { (48...57).contains($0) }
  }
  private static func isSafeProfileID(_ value: String) -> Bool {
    guard (1...80).contains(value.count), let first = value.utf8.first, isASCIILetterOrNumber(first) else { return false }
    return value.utf8.allSatisfy { isASCIILetterOrNumber($0) || $0 == 45 || $0 == 95 }
  }
  static func isSafeEnvironmentVariable(_ value: String) -> Bool {
    guard (1...128).contains(value.count), let first = value.utf8.first, isASCIIUppercase(first) || first == 95 else { return false }
    return value.utf8.allSatisfy { isASCIIUppercase($0) || (48...57).contains($0) || $0 == 95 }
  }
  private static func isASCIILetterOrNumber(_ byte: UInt8) -> Bool { (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) }
  private static func isASCIIUppercase(_ byte: UInt8) -> Bool { (65...90).contains(byte) }
  private func configurationError(_ message: String) -> GatewayError { GatewayError(message, code: .invalidConfiguration, exitCode: 2) }
}

public extension MarketingProduct {
  var readerOAuthScopes: [String] {
    switch self {
    case .googleAds: ["https://www.googleapis.com/auth/adwords"]
    case .adsense: ["https://www.googleapis.com/auth/adsense.readonly"]
    case .admob: ["https://www.googleapis.com/auth/admob.readonly", "https://www.googleapis.com/auth/admob.report"]
    case .analyticsData: ["https://www.googleapis.com/auth/analytics.readonly"]
    case .searchConsole: ["https://www.googleapis.com/auth/webmasters.readonly"]
    default: []
    }
  }
}
