import Foundation

public struct GoogleAdsKeywordIdeasInput: Codable, Equatable, Sendable {
  public let customerId: String
  public let languageConstantId: String
  public let geoTargetConstantIds: [String]
  public let keywords: [String]
  public let url: String?
  public let pageSize: Int?

  public func validate() throws {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(customerId)
    guard CredentialProfileConfiguration.isDigits(languageConstantId, maximum: 20),
      (1...10).contains(geoTargetConstantIds.count),
      geoTargetConstantIds.allSatisfy({ CredentialProfileConfiguration.isDigits($0, maximum: 20) }),
      geoTargetConstantIds.count == Set(geoTargetConstantIds).count,
      keywords.count <= 20,
      keywords.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 80 }),
      !keywords.isEmpty || url != nil,
      pageSize.map({ (1...1_000).contains($0) }) ?? true else {
      throw GatewayError("Google Ads keyword ideas input is invalid", code: .invalidArgument, exitCode: 2)
    }
    if let url {
      guard url.utf8.count <= 2_048,
        let components = URLComponents(string: url),
        components.scheme == "https", components.host != nil,
        components.user == nil, components.password == nil, components.fragment == nil else {
        throw GatewayError("Google Ads keyword ideas URL is invalid", code: .invalidArgument, exitCode: 2)
      }
    }
  }

  public static func load(path: String) throws -> Self {
    guard CredentialProfileConfiguration.isSafePath(path) else {
      throw GatewayError("Keyword ideas request path is invalid", code: .invalidArgument, exitCode: 2)
    }
    do {
      let data = try SecureLocalFiles.readRegularFile(path: path, maximumBytes: 65_536)
      let input = try JSONDecoder().decode(Self.self, from: data)
      try input.validate()
      return input
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError("Keyword ideas request is unavailable or invalid", code: .invalidArgument, exitCode: 2)
    }
  }
}

public struct GoogleAdsCustomerAccountInput: Codable, Equatable, Sendable {
  public let managerCustomerId: String
  public let descriptiveName: String
  public let currencyCode: String
  public let timeZone: String

  public func validate() throws {
    _ = try GoogleAdsMutationSupport.validatedCustomerID(managerCustomerId)
    guard (1...80).contains(descriptiveName.count),
      descriptiveName.utf8.allSatisfy({ $0 >= 32 && $0 != 127 }),
      currencyCode.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
      (1...100).contains(timeZone.count),
      timeZone.range(of: "^[A-Za-z0-9_+.-]+/[A-Za-z0-9_+./-]+$", options: .regularExpression) != nil else {
      throw GatewayError("Google Ads customer account input is invalid", code: .invalidArgument, exitCode: 2)
    }
  }

  public static func load(path: String) throws -> Self {
    guard CredentialProfileConfiguration.isSafePath(path) else {
      throw GatewayError("Customer account request path is invalid", code: .invalidArgument, exitCode: 2)
    }
    do {
      let data = try SecureLocalFiles.readRegularFile(path: path, maximumBytes: 16_384)
      let input = try JSONDecoder().decode(Self.self, from: data)
      try input.validate()
      return input
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError("Customer account request is unavailable or invalid", code: .invalidArgument, exitCode: 2)
    }
  }
}
