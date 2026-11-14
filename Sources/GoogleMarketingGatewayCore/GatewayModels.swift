import Foundation

public enum GatewayMode: String, Sendable, Codable, CaseIterable {
  case reader
  case writer
  case admin

  public var executableName: String {
    "google-marketing-gateway-\(rawValue)"
  }
}

public struct GatewayCommandResult: Sendable, Equatable {
  public let exitCode: Int32
  public let stdout: String
  public let stderr: String

  public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
    self.exitCode = exitCode
    self.stdout = stdout
    self.stderr = stderr
  }
}

public struct GatewayError: Error, Sendable, Equatable {
  public enum Code: String, Sendable, Codable {
    case invalidArgument = "INVALID_ARGUMENT"
    case invalidConfiguration = "INVALID_CONFIGURATION"
    case invalidProfile = "INVALID_PROFILE"
    case missingCredential = "MISSING_CREDENTIAL"
    case forbiddenCapability = "FORBIDDEN_CAPABILITY"
    case transportFailure = "TRANSPORT_FAILURE"
    case providerFailure = "PROVIDER_FAILURE"
    case invalidResponse = "INVALID_RESPONSE"
  }

  public let code: Code
  public let message: String
  public let exitCode: Int32

  public init(_ message: String, code: Code, exitCode: Int32 = 1) {
    self.message = message
    self.code = code
    self.exitCode = exitCode
  }
}

enum HTTPHeaderValue {
  static func isCredential(_ value: String, maximumBytes: Int = 8_192) -> Bool {
    !value.isEmpty
      && value.utf8.count <= maximumBytes
      && !value.utf8.contains(where: { $0 < 33 || $0 > 126 })
  }
}
