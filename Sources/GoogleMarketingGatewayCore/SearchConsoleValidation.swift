import Foundation

public struct SearchConsoleProperty: Equatable, Sendable {
  public let value: String
  public init(_ value: String) throws {
    guard SearchConsoleValidation.isBoundedSafeText(value, maximumBytes: 4_096) else { throw SearchConsoleValidation.invalid("Search Console property") }
    if value.hasPrefix("sc-domain:") {
      let domain = String(value.dropFirst("sc-domain:".count))
      guard SearchConsoleValidation.isDomain(domain) else { throw SearchConsoleValidation.invalid("Search Console domain property") }
    } else {
      try SearchConsoleValidation.validateHTTPURL(value, maximumBytes: 4_096, requiresTrailingSlash: true)
    }
    self.value = value
  }
}

public struct SearchConsoleHTTPURL: Equatable, Sendable {
  public let value: String
  public init(_ value: String) throws {
    try SearchConsoleValidation.validateHTTPURL(value, maximumBytes: 8_192, requiresTrailingSlash: false)
    self.value = value
  }
}

public struct SearchConsoleLanguageCode: Equatable, Sendable {
  public let value: String
  public init(_ value: String) throws {
    let bytes = Array(value.utf8)
    guard !bytes.isEmpty, bytes.count <= 255, bytes.allSatisfy({ $0 < 128 }),
      SearchConsoleValidation.isBCP47(value) else {
      throw SearchConsoleValidation.invalid("Search Console language code")
    }
    self.value = value
  }
}

enum SearchConsoleValidation {
  static func invalid(_ subject: String) -> GatewayError {
    GatewayError("\(subject) is invalid", code: .invalidArgument, exitCode: 2)
  }

  static func isBoundedSafeText(_ value: String, maximumBytes: Int) -> Bool {
    !value.isEmpty && value.utf8.count <= maximumBytes && !value.utf8.contains(where: { $0 < 32 || $0 == 127 || $0 == 92 })
  }

  static func validateHTTPURL(_ value: String, maximumBytes: Int, requiresTrailingSlash: Bool) throws {
    guard isBoundedSafeText(value, maximumBytes: maximumBytes), !value.contains("%") || hasValidPercentEscapes(value),
      let components = URLComponents(string: value), (components.scheme == "http" || components.scheme == "https"),
      components.host != nil, !(components.host?.isEmpty ?? true), components.user == nil, components.password == nil,
      components.fragment == nil, components.string == value, components.url != nil else { throw invalid("Search Console URL") }
    if requiresTrailingSlash { guard components.percentEncodedPath.hasSuffix("/") else { throw invalid("Search Console URL-prefix property") } }
  }

  static func validateDates(startDate: String, endDate: String) throws {
    guard isGregorianDate(startDate), isGregorianDate(endDate), startDate <= endDate else { throw invalid("Search Analytics dates") }
  }

  static func validate(expression: String) throws {
    let spaces = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !spaces.isEmpty, expression.count <= 4_096, expression.utf8.count <= 16_384,
      !expression.utf8.contains(where: { $0 < 32 || $0 == 127 }) else { throw invalid("Search Analytics filter expression") }
  }

  static func rejectUnknownKeys(_ decoder: any Decoder, allowed: [String]) throws {
    let container = try decoder.container(keyedBy: SearchConsoleAnyCodingKey.self)
    guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else { throw invalid("Search Analytics request field") }
  }

  static func decodeRequestFile(path: String) throws -> SearchConsoleAnalyticsRequest {
    let data: Data
    do { data = try SecureLocalFiles.readStableRegularFile(path: path, maximumBytes: 1_048_576) }
    catch { throw GatewayError("Search Analytics request file is unavailable or unsafe", code: .invalidArgument, exitCode: 2) }
    guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { throw invalid("Search Analytics request JSON") }
    do { try SearchConsoleStrictJSON.verifySingleObjectWithoutDuplicateKeys(text) }
    catch { throw invalid("Search Analytics request JSON") }
    do { return try JSONDecoder().decode(SearchConsoleAnalyticsRequest.self, from: data) }
    catch let error as GatewayError { throw error }
    catch { throw invalid("Search Analytics request JSON") }
  }

  private static func isGregorianDate(_ value: String) -> Bool {
    guard value.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return false }
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
    return formatter.date(from: value).map { formatter.string(from: $0) == value } ?? false
  }

  static func isDomain(_ value: String) -> Bool {
    guard !value.isEmpty, value.utf8.count <= 253, !value.hasPrefix("."), !value.hasSuffix("."), !value.contains(".."), !value.contains("*") else { return false }
    return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
      let chars = Array(label.utf8)
      return !chars.isEmpty && chars.count <= 63 && chars.first != 45 && chars.last != 45 && chars.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }
    }
  }

  private static func hasValidPercentEscapes(_ value: String) -> Bool {
    let bytes = Array(value.utf8); var index = 0
    while index < bytes.count { if bytes[index] == 37 { guard index + 2 < bytes.count, isHex(bytes[index + 1]), isHex(bytes[index + 2]) else { return false }; index += 3 } else { index += 1 } }
    return true
  }
  private static func isHex(_ byte: UInt8) -> Bool { (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte) }

  static func isBCP47(_ value: String) -> Bool {
    let normalized = value.lowercased()
    if grandfatheredTags.contains(normalized) { return true }
    let parts = value.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
    guard !parts.contains("") else { return false }
    if parts[0].lowercased() == "x" {
      return parts.count > 1 && parts.dropFirst().allSatisfy { isAlphanumeric($0, 1...8) }
    }
    var index = 0
    guard isLetters(parts[index], 2...8) else { return false }
    let primaryLength = parts[index].utf8.count
    index += 1
    if primaryLength <= 3 {
      var extlangCount = 0
      while index < parts.count, extlangCount < 3, isLetters(parts[index], 3...3) {
        index += 1
        extlangCount += 1
      }
    }
    if index < parts.count, isLetters(parts[index], 4...4) { index += 1 }
    if index < parts.count, isLetters(parts[index], 2...2) || isDigits(parts[index], 3...3) { index += 1 }
    var variants = Set<String>()
    while index < parts.count, isVariant(parts[index]) {
      guard variants.insert(parts[index].lowercased()).inserted else { return false }
      index += 1
    }
    var extensions = Set<String>()
    while index < parts.count, isAlphanumeric(parts[index], 1...1), parts[index].lowercased() != "x" {
      let singleton = parts[index].lowercased()
      guard extensions.insert(singleton).inserted else { return false }
      index += 1
      let start = index
      while index < parts.count, isAlphanumeric(parts[index], 2...8) { index += 1 }
      guard index > start else { return false }
    }
    if index < parts.count, parts[index].lowercased() == "x" {
      index += 1
      let start = index
      while index < parts.count, isAlphanumeric(parts[index], 1...8) { index += 1 }
      guard index > start else { return false }
    }
    return index == parts.count
  }

  private static func isLetters(_ value: String, _ range: ClosedRange<Int>) -> Bool {
    isASCII(value, range) { (65...90).contains($0) || (97...122).contains($0) }
  }
  private static func isDigits(_ value: String, _ range: ClosedRange<Int>) -> Bool {
    isASCII(value, range) { (48...57).contains($0) }
  }
  private static func isAlphanumeric(_ value: String, _ range: ClosedRange<Int>) -> Bool {
    isASCII(value, range) { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }
  }
  private static func isVariant(_ value: String) -> Bool {
    isAlphanumeric(value, 5...8) || (
      value.utf8.count == 4 &&
      value.utf8.first.map { (48...57).contains($0) } == true &&
      value.utf8.dropFirst().allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }
    )
  }
  private static func isASCII(_ value: String, _ range: ClosedRange<Int>, _ predicate: (UInt8) -> Bool) -> Bool {
    range.contains(value.utf8.count) && value.utf8.allSatisfy(predicate)
  }

  private static let grandfatheredTags: Set<String> = [
    "art-lojban", "cel-gaulish", "en-gb-oed", "i-ami", "i-bnn", "i-default",
    "i-enochian", "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn",
    "i-tao", "i-tay", "i-tsu", "no-bok", "no-nyn", "sgn-be-fr", "sgn-be-nl",
    "sgn-ch-de", "zh-guoyu", "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang"
  ]
}

private struct SearchConsoleAnyCodingKey: CodingKey { let stringValue: String; let intValue: Int? = nil; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { self.stringValue = String(intValue) } }

enum SearchConsoleStrictJSON {
  static func verifySingleObjectWithoutDuplicateKeys(_ text: String) throws {
    var parser = Parser(bytes: Array(text.utf8)); try parser.object(depth: 1); parser.skipWhitespace(); guard parser.index == parser.bytes.count else { throw ParserError.invalid }
  }
  private enum ParserError: Error { case invalid }
  private struct Parser {
    private static let maximumNestingDepth = 64
    let bytes: [UInt8]; var index = 0
    mutating func skipWhitespace() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
    mutating func object(depth: Int) throws { try ensureDepth(depth); try token(123); skipWhitespace(); var keys = Set<String>(); if peek(125) { index += 1; return }; while true { skipWhitespace(); let key = try string(); guard keys.insert(key).inserted else { throw ParserError.invalid }; skipWhitespace(); try token(58); try value(depth: depth); skipWhitespace(); if peek(125) { index += 1; return }; try token(44) } }
    mutating func array(depth: Int) throws { try ensureDepth(depth); try token(91); skipWhitespace(); if peek(93) { index += 1; return }; while true { try value(depth: depth); skipWhitespace(); if peek(93) { index += 1; return }; try token(44) } }
    mutating func value(depth: Int) throws { skipWhitespace(); guard index < bytes.count else { throw ParserError.invalid }; switch bytes[index] { case 123: try object(depth: depth + 1); case 91: try array(depth: depth + 1); case 34: _ = try string(); case 116: try literal("true"); case 102: try literal("false"); case 110: try literal("null"); case 45, 48...57: try number(); default: throw ParserError.invalid } }
    mutating func string() throws -> String {
      try token(34)
      var output = ""
      while index < bytes.count {
        let byte = bytes[index]
        guard byte >= 32 else { throw ParserError.invalid }
        if byte == 34 { index += 1; return output }
        if byte != 92 { output += try stringSegment(); continue }
        index += 1
        guard index < bytes.count else { throw ParserError.invalid }
        switch bytes[index] {
        case 34: output.append("\"")
        case 92: output.append("\\")
        case 47: output.append("/")
        case 98: output.append("\u{08}")
        case 102: output.append("\u{0C}")
        case 110: output.append("\n")
        case 114: output.append("\r")
        case 116: output.append("\t")
        case 117: output.append(try unicodeScalar())
        default: throw ParserError.invalid
        }
        index += 1
      }
      throw ParserError.invalid
    }
    mutating func stringSegment() throws -> String {
      let start = index
      while index < bytes.count, bytes[index] >= 32, bytes[index] != 34, bytes[index] != 92 { index += 1 }
      guard start < index, let value = String(bytes: bytes[start..<index], encoding: .utf8) else { throw ParserError.invalid }
      return value
    }
    mutating func unicodeScalar() throws -> Character {
      guard index + 4 < bytes.count else { throw ParserError.invalid }
      let hex = bytes[(index + 1)...(index + 4)]
      guard let text = String(bytes: hex, encoding: .ascii), let code = UInt32(text, radix: 16) else { throw ParserError.invalid }
      if (0xD800...0xDBFF).contains(code) {
        guard index + 10 < bytes.count, bytes[index + 5] == 92, bytes[index + 6] == 117,
          let lowText = String(bytes: bytes[(index + 7)...(index + 10)], encoding: .ascii),
          let low = UInt32(lowText, radix: 16), (0xDC00...0xDFFF).contains(low),
          let scalar = UnicodeScalar(0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)) else { throw ParserError.invalid }
        index += 10
        return Character(String(scalar))
      }
      guard !(0xDC00...0xDFFF).contains(code), let scalar = UnicodeScalar(code) else { throw ParserError.invalid }
      index += 4
      return Character(String(scalar))
    }
    mutating func number() throws { if peek(45) { index += 1 }; guard index < bytes.count else { throw ParserError.invalid }; if peek(48) { index += 1; guard index == bytes.count || !(48...57).contains(bytes[index]) else { throw ParserError.invalid } } else { try digits() }; guard !peek(46), !peek(69), !peek(101) else { throw ParserError.invalid } }
    mutating func digits() throws { let start = index; while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }; guard index > start else { throw ParserError.invalid } }
    mutating func literal(_ value: String) throws { let wanted = Array(value.utf8); guard bytes.dropFirst(index).starts(with: wanted) else { throw ParserError.invalid }; index += wanted.count }
    mutating func token(_ byte: UInt8) throws { skipWhitespace(); guard peek(byte) else { throw ParserError.invalid }; index += 1 }
    func ensureDepth(_ depth: Int) throws { guard depth <= Self.maximumNestingDepth else { throw ParserError.invalid } }
    func peek(_ byte: UInt8) -> Bool { index < bytes.count && bytes[index] == byte }
  }
}
