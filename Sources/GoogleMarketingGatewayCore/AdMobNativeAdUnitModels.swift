import Foundation

/// The deliberately small writable subset of AdMob's v1beta `AdUnit` schema.
/// Provider-owned fields are intentionally absent so callers cannot smuggle a
/// generic create request through this gateway.
public struct AdMobNativeAdUnitInput: Codable, Equatable, Sendable {
  public enum AdType: String, Codable, CaseIterable, Sendable {
    case richMedia = "RICH_MEDIA"
    case video = "VIDEO"
  }

  public let account: String
  public let appID: String
  public let displayName: String
  public let adTypes: [AdType]

  public init(account: String, appID: String, displayName: String, adTypes: [AdType]) throws {
    try Self.validateAccount(account)
    try Self.validateAppID(appID, account: account)
    try Self.validateDisplayName(displayName)
    guard !adTypes.isEmpty, Set(adTypes).count == adTypes.count else {
      throw GatewayError("AdMob Native ad types must be a non-empty unique set", code: .invalidArgument, exitCode: 2)
    }
    self.account = account
    self.appID = appID
    self.displayName = displayName
    self.adTypes = AdType.allCases.filter(adTypes.contains)
  }

  static func validateAccount(_ value: String) throws {
    let prefix = "accounts/pub-"
    guard value.hasPrefix(prefix) else { throw invalidInput() }
    let digits = String(value.dropFirst(prefix.count))
    guard CredentialProfileConfiguration.isDigits(digits, maximum: 32) else { throw invalidInput() }
  }

  static func validateAppID(_ value: String, account: String) throws {
    let prefix = "ca-app-pub-"
    guard value.hasPrefix(prefix) else { throw invalidInput() }
    let pieces = value.dropFirst(prefix.count).split(separator: "~", omittingEmptySubsequences: false)
    guard pieces.count == 2,
      CredentialProfileConfiguration.isDigits(String(pieces[0]), maximum: 32),
      CredentialProfileConfiguration.isDigits(String(pieces[1]), maximum: 32),
      String(pieces[0]) == String(account.dropFirst("accounts/pub-".count)) else { throw invalidInput() }
  }

  static func validateDisplayName(_ value: String) throws {
    guard (1...80).contains(value.count), value.utf8.count <= 1_024,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !value.unicodeScalars.contains(where: { scalar in
        scalar.value <= 31 || (127...159).contains(scalar.value)
      }) else { throw invalidInput() }
  }

  private static func invalidInput() -> GatewayError {
    GatewayError("AdMob Native ad-unit input is invalid", code: .invalidArgument, exitCode: 2)
  }
}

public struct AdMobNativeAdUnitCreateBody: Codable, Equatable, Sendable {
  public let appId: String
  public let displayName: String
  public let adFormat: String
  public let adTypes: [AdMobNativeAdUnitInput.AdType]

  public init(input: AdMobNativeAdUnitInput) {
    appId = input.appID
    displayName = input.displayName
    adFormat = "NATIVE"
    adTypes = input.adTypes
  }
}
