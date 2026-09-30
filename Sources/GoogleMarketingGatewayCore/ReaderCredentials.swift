import Foundation

public protocol ReaderCredentialResolving: Sendable {
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String
}

public protocol OAuthTokenRefreshing: Sendable {
  func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
  func refresh(client: OAuthDesktopClient, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
}

public extension OAuthTokenRefreshing {
  func refresh(client: OAuthDesktopClient, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    throw GatewayError("This refresher does not support inline OAuth clients", code: .missingCredential, exitCode: 2)
  }
}

public struct ReaderCredentialResolver: ReaderCredentialResolving, Sendable {
  private let tokenStore: any OAuthTokenStoring
  private let refresher: (any OAuthTokenRefreshing)?
  private let now: @Sendable () -> Date

  public init(
    tokenStore: any OAuthTokenStoring = OAuthTokenStore(),
    refresher: (any OAuthTokenRefreshing)? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.tokenStore = tokenStore
    self.refresher = refresher
    self.now = now
  }

  public func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String {
    do {
      return try selectedAccessToken(profile: profile, environment: environment)
    } catch let error as GatewayError {
      throw GatewayError("Credential resolution failed: \(profile.tokenSourceDiagnostic(environment: environment)); \(error.message)", code: error.code, exitCode: error.exitCode)
    }
  }

  private func selectedAccessToken(profile: CredentialProfile, environment: [String: String]) throws -> String {
    let input = try MarketingCredentialInput(profile: profile, environment: environment)
    let profile = try marketingProfilePaths(profile, environment: environment)
    if let token = input.accessToken { return token }
    if let json = input.tokenStoreJSON {
      let token = try OAuthTokenStore().decode(Data(json.utf8), profile: profile)
      guard !token.isNearExpiry(now: now()) else {
        throw GatewayError("Inline token JSON is expired; supply replacement credentials", code: .missingCredential, exitCode: 2)
      }
      return token.accessToken
    }
    guard let storePath = input.tokenStorePath ?? profile.tokenStorePath else {
      throw GatewayError("No environment access token or configured OAuth token store is available", code: .missingCredential, exitCode: 2)
    }
    let lock = TokenStoreRefreshLock.lock(for: storePath)
    lock.lock()
    defer { lock.unlock() }
    let token = try tokenStore.read(path: storePath, profile: profile)
    guard !token.isNearExpiry(now: now()) else {
      guard profile.oauthClientJSON != nil || profile.oauthClientJSONPath != nil, let refresher else {
        throw GatewayError("OAuth token requires refresh; run auth login", code: .missingCredential, exitCode: 2)
      }
      let refreshed: OAuthToken
      if let json = profile.oauthClientJSON {
        refreshed = try refresher.refresh(client: OAuthClient().loadClient(json: json), token: token, requiredScopes: profile.oauthScopes)
      } else if let path = profile.oauthClientJSONPath {
        refreshed = try refresher.refresh(clientPath: path, token: token, requiredScopes: profile.oauthScopes)
      } else {
        throw GatewayError("OAuth application client is missing", code: .missingCredential, exitCode: 2)
      }
      try tokenStore.write(refreshed, path: storePath, profile: profile)
      return refreshed.accessToken
    }
    return token.accessToken
  }

  public func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus {
    guard let input = try? MarketingCredentialInput(profile: profile, environment: environment) else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                              state: "invalid", expiresAt: nil, hasRefreshToken: false)
    }
    guard let profile = try? marketingProfilePaths(profile, environment: environment) else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                              state: "invalid", expiresAt: nil, hasRefreshToken: false)
    }
    let environmentTokenAvailable = input.accessToken != nil
    if let json = input.tokenStoreJSON {
      let token = try? OAuthTokenStore().decode(Data(json.utf8), profile: profile)
      let state = token.map { $0.expiry <= now() ? "expired" : ($0.isNearExpiry(now: now()) ? "near-expiry" : "ready") } ?? "invalid"
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                              state: state, expiresAt: token?.expiry, hasRefreshToken: token?.refreshToken != nil,
                              source: "ENVIRONMENT_JSON")
    }
    if environmentTokenAvailable {
      return ReaderAuthStatus(
        profile: profile, environmentTokenAvailable: true,
        tokenStoreExists: profile.tokenStorePath.map { SecureLocalFiles.pathEntryExists(path: $0) } ?? false,
        state: "ready", expiresAt: nil, hasRefreshToken: false
      )
    }
    let configuredPath = input.tokenStorePath ?? profile.tokenStorePath
    guard let path = configuredPath else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: environmentTokenAvailable, tokenStoreExists: false,
                              state: environmentTokenAvailable ? "ready" : "missing", expiresAt: nil, hasRefreshToken: false)
    }
    let storeExists = SecureLocalFiles.pathEntryExists(path: path)
    guard storeExists else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: environmentTokenAvailable, tokenStoreExists: false, state: "missing", expiresAt: nil, hasRefreshToken: false)
    }
    guard let token = try? tokenStore.read(path: path, profile: profile) else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: environmentTokenAvailable, tokenStoreExists: true, state: "invalid", expiresAt: nil, hasRefreshToken: false)
    }
    let current = now()
    let state: String
    if token.expiry <= current {
      state = "expired"
    } else if token.isNearExpiry(now: current) {
      state = "near-expiry"
    } else {
      state = "ready"
    }
    return ReaderAuthStatus(profile: profile, environmentTokenAvailable: environmentTokenAvailable, tokenStoreExists: true, state: state, expiresAt: token.expiry, hasRefreshToken: token.refreshToken != nil)
  }

  public func logout(profile: CredentialProfile) throws -> Bool {
    guard let path = profile.tokenStorePath else { return false }
    return try tokenStore.delete(path: path, profile: profile)
  }
}

private enum TokenStoreRefreshLock {
  private static let registryLock = NSLock()
  nonisolated(unsafe) private static var locks: [String: NSLock] = [:]

  static func lock(for path: String) -> NSLock {
    registryLock.lock()
    defer { registryLock.unlock() }
    if let lock = locks[path] { return lock }
    let lock = NSLock()
    locks[path] = lock
    return lock
  }
}

public struct ReaderAuthStatus: Encodable, Equatable, Sendable {
  public let product: MarketingProduct
  public let oauthScopes: [String]
  public let profileId: String
  public let environmentTokenAvailable: Bool
  public let tokenStoreConfigured: Bool
  public let tokenStoreExists: Bool
  public let state: String
  public let expiresAt: Date?
  public let hasRefreshToken: Bool
  public let tokenSource: String
  public let tokenEnvironmentVariable: String?
  public let tokenStorePath: String?

  init(
    profile: CredentialProfile,
    environmentTokenAvailable: Bool,
    tokenStoreExists: Bool,
    state: String,
    expiresAt: Date?,
    hasRefreshToken: Bool,
    source: String? = nil
  ) {
    product = profile.product
    oauthScopes = profile.oauthScopes
    profileId = profile.id
    self.environmentTokenAvailable = environmentTokenAvailable
    tokenStoreConfigured = profile.tokenStorePath != nil
    self.tokenStoreExists = tokenStoreExists
    self.state = state
    self.expiresAt = expiresAt
    self.hasRefreshToken = hasRefreshToken
    tokenSource = source ?? (environmentTokenAvailable ? "ENVIRONMENT_TOKEN" : "FILE")
    tokenEnvironmentVariable = environmentTokenAvailable ? profile.accessTokenEnvironmentVariable : nil
    tokenStorePath = environmentTokenAvailable || source == "ENVIRONMENT_JSON" ? nil : profile.tokenStorePath
  }
}
