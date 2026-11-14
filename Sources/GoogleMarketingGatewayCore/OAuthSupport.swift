import CryptoKit
import Foundation

public struct OAuthDesktopClient: Decodable, Equatable, Sendable {
  static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
  static let tokenEndpoint = "https://oauth2.googleapis.com/token"

  public let clientId: String
  public let clientSecret: String?
  public let authUri: String
  public let tokenUri: String
  public let redirectUris: [String]

  enum RootKeys: String, CodingKey { case installed }
  enum CodingKeys: String, CodingKey {
    case clientId = "client_id"
    case clientSecret = "client_secret"
    case authUri = "auth_uri"
    case tokenUri = "token_uri"
    case redirectUris = "redirect_uris"
  }

  public init(from decoder: any Decoder) throws {
    let rawRoot = try decoder.container(keyedBy: OAuthAnyCodingKey.self)
    guard Set(rawRoot.allKeys.map(\.stringValue)) == Set([RootKeys.installed.rawValue]) else {
      throw GatewayError("OAuth client file contains unsupported fields", code: .invalidConfiguration, exitCode: 2)
    }
    let root = try decoder.container(keyedBy: RootKeys.self)
    let rawInstalled = try root.nestedContainer(keyedBy: OAuthAnyCodingKey.self, forKey: .installed)
    let allowed = Set(["client_id", "client_secret", "auth_uri", "token_uri", "redirect_uris"])
    guard rawInstalled.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError("OAuth client file contains unsupported fields", code: .invalidConfiguration, exitCode: 2)
    }
    let installed = try root.nestedContainer(keyedBy: CodingKeys.self, forKey: .installed)
    clientId = try installed.decode(String.self, forKey: .clientId)
    clientSecret = try installed.decodeIfPresent(String.self, forKey: .clientSecret)
    authUri = try installed.decode(String.self, forKey: .authUri)
    tokenUri = try installed.decode(String.self, forKey: .tokenUri)
    redirectUris = try installed.decode([String].self, forKey: .redirectUris)
    guard Self.isSafeField(clientId, maximum: 4_096),
      clientSecret.map({ Self.isSafeField($0, maximum: 16_384) }) ?? true,
      authUri == Self.authorizationEndpoint,
      tokenUri == Self.tokenEndpoint,
      redirectUris.count <= 32,
      redirectUris.allSatisfy({ Self.isSafeField($0, maximum: 1_024) }) else {
      throw GatewayError("OAuth client file is not an accepted desktop client", code: .invalidConfiguration, exitCode: 2)
    }
  }

  private static func isSafeField(_ value: String, maximum: Int) -> Bool {
    !value.isEmpty && value.utf8.count <= maximum && !value.utf8.contains(where: { $0 < 32 || $0 == 127 })
  }
}

public struct OAuthToken: Codable, Equatable, Sendable {
  public static let schemaVersion = 1
  public let storedSchemaVersion: Int
  public let profileId: String
  public let product: MarketingProduct
  public let accessToken: String
  public let refreshToken: String?
  public let tokenType: String
  public let expiry: Date
  public let updatedAt: Date
  public let scopes: [String]

  public func isNearExpiry(now: Date, leeway: TimeInterval = 60) -> Bool {
    expiry <= now.addingTimeInterval(leeway)
  }

  enum CodingKeys: String, CodingKey, CaseIterable {
    case storedSchemaVersion = "schemaVersion", profileId, product, accessToken, refreshToken, tokenType, expiry = "expiresAt", updatedAt, scopes
  }

  public init(
    profile: CredentialProfile,
    accessToken: String,
    refreshToken: String?,
    tokenType: String,
    expiry: Date,
    updatedAt: Date = Date(),
    scopes: [String]
  ) throws {
    guard OAuthToken.isCredential(accessToken), refreshToken.map(OAuthToken.isCredential) ?? true,
      tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
      !scopes.isEmpty, Set(scopes) == Set(profile.oauthScopes), scopes.count == Set(scopes).count,
      scopes.allSatisfy({ $0.utf8.count <= 512 }) else {
      throw GatewayError("OAuth token store is invalid", code: .invalidConfiguration, exitCode: 2)
    }
    storedSchemaVersion = Self.schemaVersion; profileId = profile.id; product = profile.product
    self.accessToken = accessToken; self.refreshToken = refreshToken; self.tokenType = tokenType; self.expiry = expiry; self.updatedAt = updatedAt; self.scopes = scopes
  }

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.container(keyedBy: OAuthAnyCodingKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.stringValue))
    guard raw.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError("OAuth token store contains unsupported fields", code: .invalidConfiguration, exitCode: 2)
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let schemaVersion = try container.decode(Int.self, forKey: .storedSchemaVersion)
    let profileId = try container.decode(String.self, forKey: .profileId)
    let product = try container.decode(MarketingProduct.self, forKey: .product)
    let scopes = try container.decode([String].self, forKey: .scopes)
    guard schemaVersion == Self.schemaVersion, !profileId.isEmpty,
      OAuthToken.isCredential(try container.decode(String.self, forKey: .accessToken)),
      (try container.decodeIfPresent(String.self, forKey: .refreshToken)).map(OAuthToken.isCredential) ?? true,
      (try container.decode(String.self, forKey: .tokenType)).caseInsensitiveCompare("Bearer") == .orderedSame,
      !scopes.isEmpty, scopes.count == Set(scopes).count else {
      throw GatewayError("OAuth token store is invalid", code: .invalidConfiguration, exitCode: 2)
    }
    storedSchemaVersion = schemaVersion; self.profileId = profileId; self.product = product
    accessToken = try container.decode(String.self, forKey: .accessToken)
    refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    tokenType = try container.decode(String.self, forKey: .tokenType)
    expiry = try container.decode(Date.self, forKey: .expiry)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    self.scopes = scopes
  }

  private static func isCredential(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 8_192 && !value.utf8.contains(where: { $0 < 33 || $0 == 127 })
  }
}

private struct OAuthAnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
  init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

public enum OAuthPKCE {
  public static func challenge(for verifier: String) throws -> String {
    guard (43...128).contains(verifier.utf8.count), verifier.utf8.allSatisfy({
      (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || "-._~".utf8.contains($0)
    }) else { throw GatewayError("OAuth verifier is invalid", code: .invalidArgument, exitCode: 2) }
    return Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
  }

  public static func authorizationURL(client: OAuthDesktopClient, scopes: [String], redirectURI: String, state: String, verifier: String) throws -> URL {
    guard let redirect = URLComponents(string: redirectURI), redirect.scheme == "http", redirect.host == "127.0.0.1",
      redirect.port != nil, redirect.user == nil, redirect.password == nil, redirect.query == nil, redirect.fragment == nil,
      redirect.path.hasPrefix("/"), redirect.path.utf8.count <= 1_024, !redirect.path.contains(".."),
      !redirect.path.utf8.contains(where: { $0 < 33 || $0 > 126 }), !redirectURI.contains("%"),
      state.range(of: #"^[A-Za-z0-9_-]{43}$"#, options: .regularExpression) != nil else {
      throw GatewayError("OAuth callback configuration is invalid", code: .invalidArgument, exitCode: 2)
    }
    guard var components = URLComponents(string: OAuthDesktopClient.authorizationEndpoint) else {
      throw GatewayError("Unable to create OAuth authorization URL", code: .invalidArgument, exitCode: 2)
    }
    components.queryItems = [
      URLQueryItem(name: "client_id", value: client.clientId), URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "state", value: state), URLQueryItem(name: "code_challenge", value: try challenge(for: verifier)),
      URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "include_granted_scopes", value: "false"), URLQueryItem(name: "prompt", value: "consent")
    ]
    guard let url = components.url else { throw GatewayError("Unable to create OAuth authorization URL", code: .invalidArgument, exitCode: 2) }
    return url
  }
}

private extension Data {
  func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}

public protocol OAuthTokenStoring: Sendable {
  func read(path: String, profile: CredentialProfile) throws -> OAuthToken
  func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws
  func delete(path: String, profile: CredentialProfile) throws -> Bool
}

public struct OAuthTokenStore: OAuthTokenStoring, Sendable {
  public init() {}
  public func read(path: String, profile: CredentialProfile) throws -> OAuthToken {
    do {
      return try decode(SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1_048_576, requireCurrentUser: true, requirePrivateMode: true, requirePrivateParent: true), profile: profile)
    } catch let error as GatewayError { throw error
    } catch { throw GatewayError("OAuth token store is invalid", code: .invalidConfiguration, exitCode: 2) }
  }
  public func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws {
    guard token.profileId == profile.id, token.product == profile.product,
      Set(token.scopes) == Set(profile.oauthScopes), token.scopes.count == profile.oauthScopes.count else {
      throw GatewayError("OAuth token store does not match selected profile", code: .invalidConfiguration, exitCode: 2)
    }
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
    try SecureLocalFiles.writePrivateFile(try encoder.encode(token), path: path)
  }
  public func delete(path: String, profile: CredentialProfile) throws -> Bool {
    try SecureLocalFiles.readAndDeletePrivateFile(path: path, maximumBytes: 1_048_576) { data in
      _ = try decode(data, profile: profile)
    }
  }

  private func decode(_ data: Data, profile: CredentialProfile) throws -> OAuthToken {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let token = try decoder.decode(OAuthToken.self, from: data)
    guard token.profileId == profile.id, token.product == profile.product, Set(token.scopes) == Set(profile.oauthScopes), token.scopes.count == profile.oauthScopes.count else {
      throw GatewayError("OAuth token store does not match selected profile", code: .invalidConfiguration, exitCode: 2)
    }
    return token
  }
}
