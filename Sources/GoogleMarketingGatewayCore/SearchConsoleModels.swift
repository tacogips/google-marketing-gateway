import Foundation

public enum SearchConsoleDimension: String, Codable, CaseIterable, Sendable {
  case query, page, country, device, date, hour, searchAppearance
}

public enum SearchConsoleSearchType: String, Codable, CaseIterable, Sendable {
  case web, image, video, news, discover, googleNews
}

public enum SearchConsoleAggregationType: String, Codable, CaseIterable, Sendable {
  case auto, byPage, byProperty, byNewsShowcasePanel
}

public enum SearchConsoleDataState: String, Codable, CaseIterable, Sendable {
  case all, final
  case hourlyAll = "hourly_all"
}

public enum SearchConsoleFilterDimension: String, Codable, CaseIterable, Sendable {
  case country, device, page, query, searchAppearance
}

public enum SearchConsoleFilterOperator: String, Codable, CaseIterable, Sendable {
  case equals, notEquals, contains, notContains, includingRegex, excludingRegex
}

public struct SearchConsoleDimensionFilter: Codable, Equatable, Sendable {
  public let dimension: SearchConsoleFilterDimension
  public let expression: String
  public let `operator`: SearchConsoleFilterOperator?

  private enum CodingKeys: String, CodingKey, CaseIterable { case dimension, expression, `operator` }

  public init(dimension: SearchConsoleFilterDimension, expression: String, operator: SearchConsoleFilterOperator? = nil) throws {
    self.dimension = dimension
    self.expression = expression
    self.operator = `operator`
    try SearchConsoleValidation.validate(expression: expression)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try SearchConsoleValidation.rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.stringValue))
    try self.init(
      dimension: container.decode(SearchConsoleFilterDimension.self, forKey: .dimension),
      expression: container.decode(String.self, forKey: .expression),
      operator: container.decodeIfPresent(SearchConsoleFilterOperator.self, forKey: .operator)
    )
  }
}

public struct SearchConsoleDimensionFilterGroup: Codable, Equatable, Sendable {
  public let groupType: String
  public let filters: [SearchConsoleDimensionFilter]

  private enum CodingKeys: String, CodingKey, CaseIterable { case groupType, filters }

  public init(groupType: String, filters: [SearchConsoleDimensionFilter]) throws {
    guard groupType == "and", !filters.isEmpty else {
      throw GatewayError("Search Analytics filter group is invalid", code: .invalidArgument, exitCode: 2)
    }
    self.groupType = groupType
    self.filters = filters
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try SearchConsoleValidation.rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.stringValue))
    try self.init(groupType: container.decode(String.self, forKey: .groupType), filters: container.decode([SearchConsoleDimensionFilter].self, forKey: .filters))
  }
}

public struct SearchConsoleAnalyticsRequest: Codable, Equatable, Sendable {
  public let startDate: String
  public let endDate: String
  public let dimensions: [SearchConsoleDimension]?
  public let type: SearchConsoleSearchType?
  public let aggregationType: SearchConsoleAggregationType?
  public let rowLimit: Int?
  public let startRow: Int?
  public let dataState: SearchConsoleDataState?
  public let dimensionFilterGroups: [SearchConsoleDimensionFilterGroup]?

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case startDate, endDate, dimensions, type, aggregationType, rowLimit, startRow, dataState, dimensionFilterGroups
  }

  public init(
    startDate: String,
    endDate: String,
    dimensions: [SearchConsoleDimension]? = nil,
    type: SearchConsoleSearchType? = nil,
    aggregationType: SearchConsoleAggregationType? = nil,
    rowLimit: Int? = nil,
    startRow: Int? = nil,
    dataState: SearchConsoleDataState? = nil,
    dimensionFilterGroups: [SearchConsoleDimensionFilterGroup]? = nil
  ) throws {
    try SearchConsoleValidation.validateDates(startDate: startDate, endDate: endDate)
    if let dimensions {
      guard dimensions.count <= SearchConsoleDimension.allCases.count, Set(dimensions).count == dimensions.count else {
        throw GatewayError("Search Analytics dimensions are invalid", code: .invalidArgument, exitCode: 2)
      }
    }
    if let rowLimit, !(1...25_000).contains(rowLimit) {
      throw GatewayError("Search Analytics row limit is invalid", code: .invalidArgument, exitCode: 2)
    }
    if let startRow, startRow < 0 {
      throw GatewayError("Search Analytics start row is invalid", code: .invalidArgument, exitCode: 2)
    }
    if let groups = dimensionFilterGroups {
      guard (1...100).contains(groups.count), groups.reduce(0, { $0 + $1.filters.count }) <= 100 else {
        throw GatewayError("Search Analytics filter groups are invalid", code: .invalidArgument, exitCode: 2)
      }
    }
    self.startDate = startDate
    self.endDate = endDate
    self.dimensions = dimensions
    self.type = type
    self.aggregationType = aggregationType
    self.rowLimit = rowLimit
    self.startRow = startRow
    self.dataState = dataState
    self.dimensionFilterGroups = dimensionFilterGroups
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try SearchConsoleValidation.rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.stringValue))
    try self.init(
      startDate: container.decode(String.self, forKey: .startDate),
      endDate: container.decode(String.self, forKey: .endDate),
      dimensions: container.decodeIfPresent([SearchConsoleDimension].self, forKey: .dimensions),
      type: container.decodeIfPresent(SearchConsoleSearchType.self, forKey: .type),
      aggregationType: container.decodeIfPresent(SearchConsoleAggregationType.self, forKey: .aggregationType),
      rowLimit: container.decodeIfPresent(Int.self, forKey: .rowLimit),
      startRow: container.decodeIfPresent(Int.self, forKey: .startRow),
      dataState: container.decodeIfPresent(SearchConsoleDataState.self, forKey: .dataState),
      dimensionFilterGroups: container.decodeIfPresent([SearchConsoleDimensionFilterGroup].self, forKey: .dimensionFilterGroups)
    )
  }
}
