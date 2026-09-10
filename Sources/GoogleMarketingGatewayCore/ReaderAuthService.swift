import AppKit
import Foundation

public protocol ReaderAuthManaging: Sendable {
  func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus
  func logout(profile: CredentialProfile) throws -> Bool
  func login(profile: CredentialProfile, noBrowser: Bool, redirectURI: String?, timeoutSeconds: Int32) throws -> ReaderAuthLoginOutput
}

public struct ReaderAuthLoginOutput: Encodable, Equatable, Sendable {
  public let profileId: String
  public let state: String
  public let authorizationURL: String?
  public let tokenSource: String
  public let tokenStorePath: String?
  public let tokenSourceHint: String?

  public init(profileId: String, state: String, authorizationURL: String?, tokenStorePath: String? = nil, tokenSourceHint: String? = nil) {
    self.profileId = profileId
    self.state = state
    self.authorizationURL = authorizationURL
    tokenSource = "FILE"
    self.tokenStorePath = tokenStorePath
    self.tokenSourceHint = tokenSourceHint
  }
}

public struct ReaderAuthService: ReaderAuthManaging, Sendable {
  private let resolver: ReaderCredentialResolver
  private let oauth: OAuthClient
  private let openURL: @Sendable (URL) -> Bool
  private let makeReceiver: @Sendable (String?) throws -> any OAuthLoopbackReceiving
  private let randomString: @Sendable (Int) throws -> String
  private let tokenStore: any OAuthTokenStoring

  public init(
    resolver: ReaderCredentialResolver = ReaderCredentialResolver(refresher: OAuthClient()),
    oauth: OAuthClient = OAuthClient(),
    openURL: @escaping @Sendable (URL) -> Bool = { NSWorkspace.shared.open($0) },
    makeReceiver: @escaping @Sendable (String?) throws -> any OAuthLoopbackReceiving = { try OAuthLoopbackReceiver(redirectURI: $0) },
    randomString: @escaping @Sendable (Int) throws -> String = ReaderAuthService.defaultRandomString,
    tokenStore: any OAuthTokenStoring = OAuthTokenStore()
  ) {
    self.resolver = resolver
    self.oauth = oauth
    self.openURL = openURL
    self.makeReceiver = makeReceiver
    self.randomString = randomString
    self.tokenStore = tokenStore
  }
  public func status(profile: CredentialProfile, environment: [String: String]) -> ReaderAuthStatus { resolver.status(profile: profile, environment: environment) }
  public func logout(profile: CredentialProfile) throws -> Bool { try resolver.logout(profile: profile) }
  public func login(profile: CredentialProfile, noBrowser: Bool, redirectURI: String? = nil, timeoutSeconds: Int32 = 300) throws -> ReaderAuthLoginOutput {
    guard let clientPath = profile.oauthClientJSONPath, let storePath = profile.tokenStorePath else { throw GatewayError("Selected profile does not support installed OAuth login", code: .invalidProfile, exitCode: 2) }
    let client = try oauth.loadClient(path: clientPath)
    let receiver = try makeReceiver(redirectURI)
    let state = try randomString(43)
    let verifier = try randomString(64)
    let url = try OAuthPKCE.authorizationURL(client: client, scopes: profile.oauthScopes, redirectURI: receiver.redirectURI, state: state, verifier: verifier)
    if noBrowser {
      FileHandle.standardOutput.write(Data((url.absoluteString + "\n").utf8))
    } else if !openURL(url) {
      throw GatewayError("Unable to open OAuth authorization URL", code: .transportFailure, exitCode: 2)
    }
    let code = try receiver.waitForCode(expectedState: state, timeoutSeconds: timeoutSeconds)
    let token = try oauth.exchange(clientPath: clientPath, code: code, verifier: verifier, redirectURI: receiver.redirectURI, profile: profile)
    try tokenStore.write(token, path: storePath, profile: profile)
    return ReaderAuthLoginOutput(
      profileId: profile.id, state: "ready", authorizationURL: nil, tokenStorePath: storePath,
      tokenSourceHint: "Unset \(profile.accessTokenEnvironmentVariable) and select this profile/configuration to use the written token; environment access tokens override the token store."
    )
  }
  public static func defaultRandomString(length: Int) throws -> String {
    guard length > 0 else { throw GatewayError("OAuth random value length is invalid", code: .invalidArgument, exitCode: 2) }
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    var generator = SystemRandomNumberGenerator()
    return String((0..<length).map { _ in alphabet[Int.random(in: alphabet.indices, using: &generator)] })
  }
}
