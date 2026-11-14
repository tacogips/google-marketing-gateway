import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport, Sendable {
  private let session: URLSession

  /// Uses a dedicated session so redirects cannot carry a validated request's
  /// private body outside its fixed provider origin.
  public init(configuration: URLSessionConfiguration = .ephemeral) {
    session = URLSession(
      configuration: configuration,
      delegate: RejectingRedirectDelegate.shared,
      delegateQueue: nil
    )
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GatewayError("Google returned a non-HTTP response", code: .invalidResponse)
    }
    return (data, httpResponse)
  }
}

final class RejectingRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  static let shared = RejectingRedirectDelegate()

  func urlSession(
    _: URLSession,
    task _: URLSessionTask,
    willPerformHTTPRedirection _: HTTPURLResponse,
    newRequest _: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

public struct GoogleRESTClient: Sendable {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public func execute(_ request: URLRequest) async throws -> Data {
    do {
      let (data, response) = try await transport.data(for: request)
      guard (200..<300).contains(response.statusCode) else {
        let providerMessage = Self.sanitizedProviderMessage(data)
        throw GatewayError(
          "Google API returned HTTP \(response.statusCode)\(providerMessage)",
          code: .providerFailure
        )
      }
      guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
        throw GatewayError("Google returned invalid JSON", code: .invalidResponse)
      }
      return data
    } catch let error as GatewayError where error.code == .providerFailure || error.code == .invalidResponse {
      throw error
    } catch {
      throw GatewayError("Google API request failed", code: .transportFailure)
    }
  }

  private static func sanitizedProviderMessage(_ data: Data) -> String {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = object["error"] as? [String: Any],
      let status = error["status"] as? String,
      status.range(of: #"^[A-Z0-9_]{1,80}$"#, options: .regularExpression) != nil
    else { return "" }
    return " (\(status))"
  }
}
