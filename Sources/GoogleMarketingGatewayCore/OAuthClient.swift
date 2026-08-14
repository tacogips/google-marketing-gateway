import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol OAuthHTTPHandling: Sendable {
  func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse)
}

public struct URLSessionOAuthHTTP: OAuthHTTPHandling, Sendable {
  private let session: URLSession
  private let waitTimeout: DispatchTimeInterval

  public init(configuration: URLSessionConfiguration = .ephemeral, timeoutSeconds: Int = 30) {
    configuration.timeoutIntervalForRequest = TimeInterval(timeoutSeconds)
    configuration.timeoutIntervalForResource = TimeInterval(timeoutSeconds)
    session = URLSession(
      configuration: configuration,
      delegate: RejectingRedirectDelegate.shared,
      delegateQueue: nil
    )
    waitTimeout = .seconds(timeoutSeconds + 1)
  }

  public func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    let semaphore = DispatchSemaphore(value: 0)
    let result = LockedOAuthResult()
    let task = session.dataTask(with: request) { data, response, error in
      result.set(data: data, response: response as? HTTPURLResponse, error: error)
      semaphore.signal()
    }
    task.resume()
    guard semaphore.wait(timeout: .now() + waitTimeout) == .success else {
      task.cancel()
      throw GatewayError("OAuth HTTP request timed out", code: .transportFailure)
    }
    return try result.get()
  }
}

private final class LockedOAuthResult: @unchecked Sendable {
  private let lock = NSLock(); private var result: Result<(Data, HTTPURLResponse), Error>?
  func set(data: Data?, response: HTTPURLResponse?, error: Error?) {
    lock.lock(); defer { lock.unlock() }
    if let error { result = .failure(error) }
    else if let data, let response { result = .success((data, response)) }
    else { result = .failure(GatewayError("OAuth HTTP request failed", code: .transportFailure)) }
  }
  func get() throws -> (Data, HTTPURLResponse) {
    lock.lock(); defer { lock.unlock() }
    return try result?.get() ?? { throw GatewayError("OAuth HTTP request failed", code: .transportFailure) }()
  }
}

public struct OAuthClient: OAuthTokenRefreshing, Sendable {
  private let http: any OAuthHTTPHandling
  private let now: @Sendable () -> Date
  public init(http: any OAuthHTTPHandling = URLSessionOAuthHTTP(), now: @escaping @Sendable () -> Date = Date.init) { self.http = http; self.now = now }

  public func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    guard let refreshToken = token.refreshToken, !refreshToken.isEmpty else { throw GatewayError("OAuth token cannot be refreshed", code: .missingCredential, exitCode: 2) }
    let client = try loadClient(path: clientPath)
    let response = try tokenRequest(client: client, values: ["grant_type": "refresh_token", "refresh_token": refreshToken])
    return try makeToken(response: response, profile: token.profile, fallbackRefreshToken: refreshToken, requiredScopes: requiredScopes)
  }

  public func exchange(clientPath: String, code: String, verifier: String, redirectURI: String, profile: CredentialProfile) throws -> OAuthToken {
    let client = try loadClient(path: clientPath)
    let response = try tokenRequest(client: client, values: ["grant_type": "authorization_code", "code": code, "code_verifier": verifier, "redirect_uri": redirectURI])
    let token = try makeToken(response: response, profile: profile, fallbackRefreshToken: nil, requiredScopes: profile.oauthScopes)
    guard let refreshToken = token.refreshToken, !refreshToken.isEmpty else {
      throw GatewayError("OAuth token response is invalid", code: .invalidResponse, exitCode: 2)
    }
    return token
  }

  public func loadClient(path: String) throws -> OAuthDesktopClient {
    do { return try JSONDecoder().decode(OAuthDesktopClient.self, from: SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1_048_576, requireCurrentUser: true))
    } catch let error as GatewayError { throw error
    } catch { throw GatewayError("OAuth client file is invalid", code: .invalidConfiguration, exitCode: 2) }
  }

  private func tokenRequest(client: OAuthDesktopClient, values: [String: String]) throws -> OAuthResponse {
    var body = values; body["client_id"] = client.clientId
    if let secret = client.clientSecret { body["client_secret"] = secret }
    guard let tokenURL = URL(string: OAuthDesktopClient.tokenEndpoint) else {
      throw GatewayError("OAuth token request failed", code: .transportFailure)
    }
    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = body.sorted { $0.key < $1.key }.map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }.joined(separator: "&").data(using: .utf8)
    let (data, response): (Data, HTTPURLResponse)
    do { (data, response) = try http.execute(request) } catch { throw GatewayError("OAuth token request failed", code: .transportFailure) }
    guard (200..<300).contains(response.statusCode) else { throw GatewayError("OAuth token request was rejected", code: .providerFailure, exitCode: 2) }
    do { return try JSONDecoder().decode(OAuthResponse.self, from: data) } catch { throw GatewayError("OAuth token response is invalid", code: .invalidResponse, exitCode: 2) }
  }

  private func makeToken(response: OAuthResponse, profile: CredentialProfile, fallbackRefreshToken: String?, requiredScopes: [String]) throws -> OAuthToken {
    guard let accessToken = response.accessToken, let expiresIn = response.expiresIn, (1...31_536_000).contains(expiresIn), response.tokenType?.caseInsensitiveCompare("Bearer") == .orderedSame else {
      throw GatewayError("OAuth token response is invalid", code: .invalidResponse, exitCode: 2)
    }
    let scopes = (response.scope ?? requiredScopes.joined(separator: " ")).split(separator: " ").map(String.init)
    guard Set(requiredScopes) == Set(scopes), scopes.count == Set(scopes).count else { throw GatewayError("OAuth token response scope is invalid", code: .invalidResponse, exitCode: 2) }
    let current = now()
    return try OAuthToken(profile: profile, accessToken: accessToken, refreshToken: response.refreshToken ?? fallbackRefreshToken, tokenType: "Bearer", expiry: current.addingTimeInterval(TimeInterval(expiresIn)), updatedAt: current, scopes: scopes)
  }
}

private extension OAuthToken {
  var profile: CredentialProfile {
    CredentialProfile(
      id: profileId,
      product: product,
      capability: .reader,
      oauthScopes: scopes,
      accessTokenEnvironmentVariable: "OAUTH_TOKEN_STORE"
    )
  }
}

private struct OAuthResponse: Decodable {
  let accessToken: String?; let refreshToken: String?; let tokenType: String?; let expiresIn: Int?; let scope: String?
  enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", tokenType = "token_type", expiresIn = "expires_in", scope }
}

private extension String {
  var urlFormEncoded: String { addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
}
