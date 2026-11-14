import Foundation

public protocol ReaderCredentialResolving: Sendable {
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String
}

public protocol OAuthTokenRefreshing: Sendable {
  func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
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
    if let token = environment[profile.accessTokenEnvironmentVariable]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
      return token
    }
    guard let storePath = profile.tokenStorePath else {
      throw GatewayError("No environment access token or configured OAuth token store is available", code: .missingCredential, exitCode: 2)
    }
    let lock = TokenStoreRefreshLock.lock(for: storePath)
    lock.lock()
    defer { lock.unlock() }
    let token = try tokenStore.read(path: storePath, profile: profile)
    guard !token.isNearExpiry(now: now()) else {
      guard let clientPath = profile.oauthClientJSONPath, let refresher else {
        throw GatewayError("OAuth token requires refresh; run auth login", code: .missingCredential, exitCode: 2)
      }
      let refreshed = try refresher.refresh(clientPath: clientPath, token: token, requiredScopes: profile.oauthScopes)
      try tokenStore.write(refreshed, path: storePath, profile: profile)
      return refreshed.accessToken
    }
    return token.accessToken
  }

  public func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus {
    let environmentTokenAvailable = !(environment[profile.accessTokenEnvironmentVariable] ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let configuredPath = profile.tokenStorePath
    guard let path = configuredPath else {
      return ReaderAuthStatus(profile: profile, environmentTokenAvailable: environmentTokenAvailable, tokenStoreExists: false, state: environmentTokenAvailable ? "ready" : "missing", expiresAt: nil, hasRefreshToken: false)
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

  init(
    profile: CredentialProfile,
    environmentTokenAvailable: Bool,
    tokenStoreExists: Bool,
    state: String,
    expiresAt: Date?,
    hasRefreshToken: Bool
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
  }
}
