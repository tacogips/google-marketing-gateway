import Foundation

public struct MarketingDate: Codable, Equatable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  public init(year: Int, month: Int, day: Int) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    let components = DateComponents(year: year, month: month, day: day)
    guard let date = calendar.date(from: components) else {
      throw GatewayError("Report date is invalid", code: .invalidArgument, exitCode: 2)
    }
    let resolved = calendar.dateComponents([.year, .month, .day], from: date)
    guard resolved.year == year, resolved.month == month, resolved.day == day else {
      throw GatewayError("Report date is invalid", code: .invalidArgument, exitCode: 2)
    }
    self.year = year
    self.month = month
    self.day = day
  }

  public static func parse(_ value: String) throws -> MarketingDate {
    let components = value.split(separator: "-", omittingEmptySubsequences: false)
    guard components.count == 3,
          components[0].count == 4,
          components[1].count == 2,
          components[2].count == 2,
          let year = Int(components[0]),
          let month = Int(components[1]),
          let day = Int(components[2]) else {
      throw GatewayError("Report dates must use YYYY-MM-DD", code: .invalidArgument, exitCode: 2)
    }
    return try MarketingDate(year: year, month: month, day: day)
  }
}

public struct MarketingDateRange: Codable, Equatable, Sendable {
  public let startDate: MarketingDate
  public let endDate: MarketingDate

  public init(startDate: MarketingDate, endDate: MarketingDate) throws {
    let start = (startDate.year, startDate.month, startDate.day)
    let end = (endDate.year, endDate.month, endDate.day)
    guard start <= end else {
      throw GatewayError("Report start date must not be after end date", code: .invalidArgument, exitCode: 2)
    }
    self.startDate = startDate
    self.endDate = endDate
  }
}

public struct AdSenseReportParameters: Equatable, Sendable {
  public let dateRange: MarketingDateRange
  public let dimensions: [String]
  public let metrics: [String]
  public let filters: [String]
  public let orderBy: [String]
  public let languageCode: String?
  public let currencyCode: String?
  public let limit: Int?
  public let reportingTimeZone: String?

  public init(
    dateRange: MarketingDateRange,
    dimensions: [String] = [],
    metrics: [String],
    filters: [String] = [],
    orderBy: [String] = [],
    languageCode: String? = nil,
    currencyCode: String? = nil,
    limit: Int? = nil,
    reportingTimeZone: String? = nil
  ) throws {
    guard !metrics.isEmpty, metrics.allSatisfy(Self.isEnumName), dimensions.allSatisfy(Self.isEnumName) else {
      throw GatewayError("Report metrics and dimensions must use official enum names", code: .invalidArgument, exitCode: 2)
    }
    if let limit, !(1...100_000).contains(limit) {
      throw GatewayError("AdSense report limit must be between 1 and 100000", code: .invalidArgument, exitCode: 2)
    }
    try Self.validateLocalization(languageCode: languageCode, currencyCode: currencyCode)
    self.dateRange = dateRange
    self.dimensions = dimensions
    self.metrics = metrics
    self.filters = filters
    self.orderBy = orderBy
    self.languageCode = languageCode
    self.currencyCode = currencyCode
    self.limit = limit
    self.reportingTimeZone = reportingTimeZone
  }

  static func isEnumName(_ value: String) -> Bool {
    guard !value.isEmpty, let first = value.utf8.first, (65...90).contains(first) else { return false }
    return value.utf8.allSatisfy { (65...90).contains($0) || (48...57).contains($0) || $0 == 95 }
  }

  static func validateLocalization(languageCode: String?, currencyCode: String?) throws {
    if let currencyCode,
       currencyCode.count != 3 || !currencyCode.utf8.allSatisfy({ (65...90).contains($0) }) {
      throw GatewayError("Currency code must be a three-letter uppercase code", code: .invalidArgument, exitCode: 2)
    }
    if let languageCode,
       languageCode.isEmpty || !languageCode.utf8.allSatisfy({
         (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
       }) {
      throw GatewayError("Language code must be a BCP-47 tag", code: .invalidArgument, exitCode: 2)
    }
  }
}

public struct AdMobLocalizationSettings: Codable, Equatable, Sendable {
  public let currencyCode: String?
  public let languageCode: String?

  public init(currencyCode: String? = nil, languageCode: String? = nil) throws {
    try AdSenseReportParameters.validateLocalization(
      languageCode: languageCode,
      currencyCode: currencyCode
    )
    self.currencyCode = currencyCode
    self.languageCode = languageCode
  }
}

public struct AdMobReportSpec: Codable, Equatable, Sendable {
  public let dateRange: MarketingDateRange
  public let dimensions: [String]
  public let metrics: [String]
  public let localizationSettings: AdMobLocalizationSettings?
  public let maxReportRows: Int?
  public let timeZone: String?

  public init(
    dateRange: MarketingDateRange,
    dimensions: [String] = [],
    metrics: [String],
    localizationSettings: AdMobLocalizationSettings? = nil,
    maxReportRows: Int? = nil,
    timeZone: String? = nil
  ) throws {
    guard !metrics.isEmpty,
          metrics.allSatisfy(AdSenseReportParameters.isEnumName),
          dimensions.allSatisfy(AdSenseReportParameters.isEnumName) else {
      throw GatewayError("Report metrics and dimensions must use official enum names", code: .invalidArgument, exitCode: 2)
    }
    if let maxReportRows, !(1...100_000).contains(maxReportRows) {
      throw GatewayError("AdMob max report rows must be between 1 and 100000", code: .invalidArgument, exitCode: 2)
    }
    if let timeZone, timeZone != "America/Los_Angeles" {
      throw GatewayError(
        "AdMob currently supports only America/Los_Angeles report time zone",
        code: .invalidArgument,
        exitCode: 2
      )
    }
    self.dateRange = dateRange
    self.dimensions = dimensions
    self.metrics = metrics
    self.localizationSettings = localizationSettings
    self.maxReportRows = maxReportRows
    self.timeZone = timeZone
  }
}

struct AdMobGenerateReportRequest: Codable, Equatable, Sendable {
  let reportSpec: AdMobReportSpec
}
