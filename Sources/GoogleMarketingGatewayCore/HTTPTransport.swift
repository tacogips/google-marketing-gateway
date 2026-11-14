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
      isSafeProviderCode(status)
    else { return "" }
    let codes = googleAdsErrorCodes(error)
    let suffix = codes.isEmpty ? "" : ": \(codes.joined(separator: ", "))"
    return " (\(status)\(suffix))"
  }

  private static func googleAdsErrorCodes(_ error: [String: Any]) -> [String] {
    guard let details = error["details"] as? [[String: Any]] else { return [] }
    let codes = details.flatMap { detail -> [String] in
      guard let errors = detail["errors"] as? [[String: Any]] else { return [] }
      return errors.flatMap { item -> [String] in
        guard let errorCode = item["errorCode"] as? [String: Any] else { return [] }
        return errorCode.values.compactMap { value in
          guard let code = value as? String, isSafeProviderCode(code) else { return nil }
          return code
        }
      }
    }
    return Array(Set(codes)).sorted()
  }

  private static func isSafeProviderCode(_ value: String) -> Bool {
    value.range(of: #"^[A-Z][A-Z0-9_]{0,79}$"#, options: .regularExpression) != nil
  }
}
