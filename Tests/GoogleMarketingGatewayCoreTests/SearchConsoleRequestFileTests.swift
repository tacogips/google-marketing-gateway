import Darwin
import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func searchConsoleRequestFileAcceptsExactlyOneMiB() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("exact.json")
  var data = Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8)
  data.append(Data(repeating: 32, count: 1_048_576 - data.count))
  try data.write(to: file)
  #expect(try SearchConsoleValidation.decodeRequestFile(path: file.path).startDate == "2026-01-01")
}

@Test func searchConsoleRequestFileRejectsOverOneMiB() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("oversized.json")
  try Data(repeating: 32, count: 1_048_577).write(to: file)
  #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: file.path) }
}

@Test func searchConsoleRequestFileRejectsEmptyInput() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("empty.json")
  try Data().write(to: file)
  #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: file.path) }
}

@Test func stableSearchConsoleRequestFileRejectsNanosecondOnlyTimestampChanges() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("nanoseconds.json")
  try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8).write(to: file)
  try searchConsoleSetTimes(file, seconds: 1_700_000_000, nanoseconds: 100)
  let before = try searchConsoleStat(file)
  #expect(throws: GatewayError.self) {
    _ = try SecureLocalFiles.readStableRegularFile(path: file.path, maximumBytes: 1_048_576) {
      try searchConsoleSetTimes(file, seconds: 1_700_000_000, nanoseconds: 200)
      let after = try searchConsoleStat(file)
      #expect(before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec)
      #expect(before.st_mtimespec.tv_nsec != after.st_mtimespec.tv_nsec)
    }
  }
}

@Test func stableSearchConsoleRequestFileRejectsInjectedRaces() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let original = Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8)
  let mutations: [(String, (URL) throws -> Void)] = [
    ("overwrite", { try Data(#"{"startDate":"2026-01-03","endDate":"2026-01-04"}"#.utf8).write(to: $0) }),
    ("truncate", { try Data("{}".utf8).write(to: $0) }),
    ("growth", {
      let handle = try FileHandle(forWritingTo: $0)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: Data(repeating: 32, count: 128))
    }),
    ("timestamp", { try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: $0.path) }),
    ("identity", { let replacement = $0.deletingLastPathComponent().appendingPathComponent("replacement.json"); try original.write(to: replacement); try FileManager.default.replaceItemAt($0, withItemAt: replacement) }),
    ("type", { try FileManager.default.removeItem(at: $0); try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: false) })
  ]
  for (name, mutate) in mutations {
    let file = directory.appendingPathComponent("\(name).json")
    try original.write(to: file)
    #expect(throws: GatewayError.self) {
      _ = try SecureLocalFiles.readStableRegularFile(path: file.path, maximumBytes: 1_048_576) {
        try mutate(file)
      }
    }
  }
}

@Test func searchConsoleRequestFileRejectsEveryStrictJSONFailureClass() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let fixtures: [(String, Data)] = [
    ("unknown-root", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","extra":true}"#.utf8)),
    ("deprecated-search-type", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","searchType":"web"}"#.utf8)),
    ("unknown-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x"}],"extra":true}]}"#.utf8)),
    ("unknown-filter", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x","extra":true}]}]}"#.utf8)),
    ("duplicate-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","groupType":"and","filters":[{"dimension":"query","expression":"x"}]}]}"#.utf8)),
    ("duplicate-filter", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"x","expression":"y"}]}]}"#.utf8)),
    ("escaped-duplicate-root", Data(#"{"startDate":"2026-01-01","st\u0061rtDate":"2026-01-02","endDate":"2026-01-03"}"#.utf8)),
    ("unsupported-enum", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","type":"maps"}"#.utf8)),
    ("numeric-string", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":"1"}"#.utf8)),
    ("fraction", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","rowLimit":1.0}"#.utf8)),
    ("exponent", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":1e3}"#.utf8)),
    ("boolean", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":true}"#.utf8)),
    ("overflow", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","startRow":999999999999999999999999999999999999}"#.utf8)),
    ("empty-group", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[]}]}"#.utf8)),
    ("trailing", Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"} {}"#.utf8)),
    ("array", Data(#"[]"#.utf8)),
    ("malformed", Data(#"{"startDate":"2026-01-01""#.utf8)),
    ("utf8", Data([0xFF, 0xFE]))
  ]
  for (name, data) in fixtures {
    let file = directory.appendingPathComponent("\(name).json")
    try data.write(to: file)
    #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: file.path) }
  }
}

@Test func searchConsoleRequestFileRejectsExcessiveJSONNesting() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("deep.json")
  let accepted = searchConsoleNestedJSON(arrayDepth: 63)
  let rejected = searchConsoleNestedJSON(arrayDepth: 64)
  try SearchConsoleStrictJSON.verifySingleObjectWithoutDuplicateKeys(accepted)
  #expect(throws: Error.self) {
    try SearchConsoleStrictJSON.verifySingleObjectWithoutDuplicateKeys(rejected)
  }
  try Data(rejected.utf8).write(to: file)
  #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: file.path) }
}

@Test func searchConsoleRequestFileHandlesUTF16SurrogateEscapes() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let valid = directory.appendingPathComponent("surrogate.json")
  try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"\uD83D\uDE00"}]}]}"#.utf8).write(to: valid)
  #expect(try SearchConsoleValidation.decodeRequestFile(path: valid.path).dimensionFilterGroups?.first?.filters.first?.expression == "😀")
  for (name, json) in [
    ("lone-high", #"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"\uD83D"}]}]}"#),
    ("lone-low", #"{"startDate":"2026-01-01","endDate":"2026-01-02","dimensionFilterGroups":[{"groupType":"and","filters":[{"dimension":"query","expression":"\uDE00"}]}]}"#)
  ] {
    let file = directory.appendingPathComponent("\(name).json")
    try Data(json.utf8).write(to: file)
    #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: file.path) }
  }
}

@Test func searchConsoleRequestFileRejectsNonRegularAndUnsafeEntries() throws {
  let directory = try searchConsoleFileTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
  let regular = directory.appendingPathComponent("regular.json")
  try Data(#"{"startDate":"2026-01-01","endDate":"2026-01-02"}"#.utf8).write(to: regular)
  let terminalLink = directory.appendingPathComponent("terminal-link.json")
  try FileManager.default.createSymbolicLink(at: terminalLink, withDestinationURL: regular)
  let parentLink = directory.appendingPathComponent("parent-link", isDirectory: true)
  try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: directory)
  let childDirectory = directory.appendingPathComponent("directory.json", isDirectory: true)
  try FileManager.default.createDirectory(at: childDirectory, withIntermediateDirectories: false)
  let fifo = directory.appendingPathComponent("request.fifo")
  guard mkfifo(fifo.path, mode_t(S_IRUSR | S_IWUSR)) == 0 else {
    throw GatewayError("Unable to create request-file test FIFO", code: .invalidResponse)
  }
  for path in [
    terminalLink.path,
    parentLink.appendingPathComponent("regular.json").path,
    childDirectory.path,
    fifo.path,
    "/dev/null"
  ] {
    #expect(throws: GatewayError.self) { _ = try SearchConsoleValidation.decodeRequestFile(path: path) }
  }
}

private func searchConsoleFileTemporaryDirectory() throws -> URL {
  let base = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path.replacingOccurrences(of: "/var/", with: "/private/var/"), isDirectory: true)
  let directory = base.appendingPathComponent("search-console-file-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  return directory
}

private func searchConsoleNestedJSON(arrayDepth: Int) -> String {
  #"{"unexpected":"# + String(repeating: "[", count: arrayDepth) + "null" + String(repeating: "]", count: arrayDepth) + "}"
}

private func searchConsoleSetTimes(_ file: URL, seconds: Int, nanoseconds: Int) throws {
  var values = [
    timespec(tv_sec: seconds, tv_nsec: nanoseconds),
    timespec(tv_sec: seconds, tv_nsec: nanoseconds)
  ]
  guard utimensat(AT_FDCWD, file.path, &values, 0) == 0 else {
    throw GatewayError("Unable to set request-file timestamp", code: .invalidResponse)
  }
}

private func searchConsoleStat(_ file: URL) throws -> stat {
  var result = stat()
  guard lstat(file.path, &result) == 0 else {
    throw GatewayError("Unable to inspect request-file timestamp", code: .invalidResponse)
  }
  return result
}
