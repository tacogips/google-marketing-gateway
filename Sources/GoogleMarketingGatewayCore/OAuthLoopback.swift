import Darwin
import Foundation

public protocol OAuthLoopbackReceiving: Sendable {
  var redirectURI: String { get }
  func waitForCode(expectedState: String, timeoutSeconds: Int32) throws -> String
}

public final class OAuthLoopbackReceiver: OAuthLoopbackReceiving, @unchecked Sendable {
  public static let defaultCallbackPath = "/oauth2callback"
  private static let connectionTimeoutMilliseconds: Int32 = 1_000
  private static let maximumInvalidConnections = 32
  private static let maximumRequestLineBytes = 8_192
  private static let maximumHeaderBytes = 16_384
  private static let maximumRequestBytes = 32_768

  public let redirectURI: String
  private let socketFD: Int32
  private let callbackPath: String

  public init(redirectURI requestedRedirectURI: String? = nil) throws {
    let requested = try Self.requestedEndpoint(requestedRedirectURI)
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw GatewayError("Unable to create OAuth callback listener", code: .transportFailure, exitCode: 2) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = requested.port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bound == 0, listen(fd, Int32(Self.maximumInvalidConnections)) == 0 else {
      close(fd)
      throw GatewayError("Unable to bind OAuth callback listener", code: .transportFailure, exitCode: 2)
    }
    var actual = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    guard withUnsafeMutablePointer(to: &actual, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
    }) == 0 else {
      close(fd)
      throw GatewayError("Unable to resolve OAuth callback port", code: .transportFailure, exitCode: 2)
    }
    socketFD = fd
    callbackPath = requested.path
    redirectURI = "http://127.0.0.1:\(UInt16(bigEndian: actual.sin_port))\(requested.path)"
  }

  deinit { close(socketFD) }

  public func waitForCode(expectedState: String, timeoutSeconds: Int32 = 300) throws -> String {
    guard (1...600).contains(timeoutSeconds), expectedState.utf8.count == 43 else {
      throw GatewayError("OAuth callback timeout or state is invalid", code: .invalidArgument, exitCode: 2)
    }
    let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
    var rejected = 0
    while Date() < deadline, rejected < Self.maximumInvalidConnections {
      let remaining = max(1, Int32(min(deadline.timeIntervalSinceNow * 1_000, Double(Int32.max))))
      var input = pollfd(fd: socketFD, events: Int16(POLLIN), revents: 0)
      guard poll(&input, 1, remaining) > 0 else { break }
      var peer = sockaddr_in()
      var length = socklen_t(MemoryLayout<sockaddr_in>.size)
      let client = withUnsafeMutablePointer(to: &peer) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(socketFD, $0, &length) }
      }
      guard client >= 0 else { throw GatewayError("OAuth callback failed", code: .transportFailure, exitCode: 2) }
      defer { close(client) }
      var noSigPipe: Int32 = 1
      guard setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw GatewayError("OAuth callback failed", code: .transportFailure, exitCode: 2)
      }
      guard peer.sin_addr.s_addr == inet_addr("127.0.0.1") else { rejected += 1; continue }
      do {
        let request = try requestText(client: client)
        switch try Self.callbackOutcome(request: request, expectedState: expectedState, callbackPath: callbackPath) {
        case let .code(code):
          writeResponse(client: client, status: "200 OK", body: "OK")
          return code
        case .providerError:
          writeResponse(client: client, status: "400 Bad Request", body: "")
          throw GatewayError("OAuth authorization was denied", code: .providerFailure, exitCode: 2)
        }
      } catch let error as GatewayError where error.code == .providerFailure {
        throw error
      } catch {
        writeResponse(client: client, status: "400 Bad Request", body: "")
        rejected += 1
      }
    }
    throw GatewayError("OAuth callback timed out or validation failed", code: .invalidResponse, exitCode: 2)
  }

  static func callbackCode(request: String, expectedState: String, callbackPath: String = defaultCallbackPath) throws -> String {
    switch try callbackOutcome(request: request, expectedState: expectedState, callbackPath: callbackPath) {
    case let .code(code): return code
    case .providerError: throw GatewayError("OAuth authorization was denied", code: .providerFailure, exitCode: 2)
    }
  }

  private static func callbackOutcome(request: String, expectedState: String, callbackPath: String) throws -> CallbackOutcome {
    guard let first = request.split(separator: "\r\n").first else {
      throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2)
    }
    let parts = first.split(separator: " ")
    guard parts.count == 3, parts[0] == "GET", parts[2] == "HTTP/1.1" else {
      throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2)
    }
    let target = String(parts[1])
    let targetParts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    guard targetParts.count == 2, String(targetParts[0]) == callbackPath, !target.contains("#") else {
      throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2)
    }
    let items = URLComponents(string: "http://callback/?\(targetParts[1])")?.queryItems ?? []
    guard !items.isEmpty, items.count == Set(items.map(\.name)).count,
      let state = items.first(where: { $0.name == "state" })?.value, state == expectedState else {
      throw GatewayError("OAuth callback validation failed", code: .invalidResponse, exitCode: 2)
    }
    if let error = items.first(where: { $0.name == "error" })?.value, !error.isEmpty {
      return .providerError
    }
    guard items.count == 2, Set(items.map(\.name)) == Set(["state", "code"]),
      let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty, code.utf8.count <= 8_192,
      code.utf8.allSatisfy({ $0 >= 33 && $0 != 127 }) else {
      throw GatewayError("OAuth callback validation failed", code: .invalidResponse, exitCode: 2)
    }
    return .code(code)
  }

  private func requestText(client: Int32) throws -> String {
    let deadline = Date().addingTimeInterval(TimeInterval(Self.connectionTimeoutMilliseconds) / 1_000)
    var bytes = [UInt8]()
    var chunk = [UInt8](repeating: 0, count: 4_096)
    while Date() < deadline {
      let remaining = max(1, Int32(min(deadline.timeIntervalSinceNow * 1_000, Double(Int32.max))))
      var input = pollfd(fd: client, events: Int16(POLLIN), revents: 0)
      guard poll(&input, 1, remaining) > 0 else { break }
      let count = read(client, &chunk, chunk.count)
      guard count > 0 else { throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2) }
      bytes.append(contentsOf: chunk.prefix(count))
      guard bytes.count <= Self.maximumRequestBytes, let request = String(bytes: bytes, encoding: .utf8) else {
        throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2)
      }
      if let end = request.range(of: "\r\n\r\n") {
        let headers = request[..<end.upperBound]
        guard headers.utf8.count <= Self.maximumHeaderBytes,
          let line = request.range(of: "\r\n"), request[..<line.lowerBound].utf8.count <= Self.maximumRequestLineBytes else {
          throw GatewayError("OAuth callback is invalid", code: .invalidResponse, exitCode: 2)
        }
        return request
      }
    }
    throw GatewayError("OAuth callback connection timed out", code: .invalidResponse, exitCode: 2)
  }

  private static func requestedEndpoint(_ redirectURI: String?) throws -> (port: UInt16, path: String) {
    guard let redirectURI else { return (0, Self.defaultCallbackPath) }
    guard !redirectURI.contains("%"), let components = URLComponents(string: redirectURI),
      components.scheme == "http", components.host == "127.0.0.1", components.port != nil,
      components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
      let port = components.port, (1...65_535).contains(port), isSafeCallbackPath(components.path) else {
      throw GatewayError("OAuth callback path is invalid", code: .invalidArgument, exitCode: 2)
    }
    return (UInt16(port), components.path)
  }

  private static func isSafeCallbackPath(_ path: String) -> Bool {
    path.utf8.count >= 1 && path.utf8.count <= 1_024 && path.hasPrefix("/") &&
      !path.contains("..") && !path.utf8.contains(where: { $0 < 33 || $0 > 126 })
  }

  private func writeResponse(client: Int32, status: String, body: String) {
    let response = "HTTP/1.1 \(status)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    _ = response.withCString { write(client, $0, strlen($0)) }
  }
}

private enum CallbackOutcome {
  case code(String)
  case providerError
}
