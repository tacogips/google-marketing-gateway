import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import GoogleMarketingGatewayCore

private struct StubTransport: HTTPTransport {
  let statusCode: Int
  let body: String

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
    return (Data(body.utf8), response)
  }
}

@Test func readerExecutesAdMobAccountList() async {
  let cli = GoogleMarketingGatewayCLI(
    mode: .reader,
    transport: StubTransport(statusCode: 200, body: #"{"account":[{"name":"accounts/pub-1"}]}"#)
  )
  let result = await cli.run(
    arguments: [
      "admob", "accounts", "list",
      "--profile", "admob-reader",
      "--config", readerProfileFixturePath,
      "--page-size", "10"
    ],
    environment: ["ADMOB_TEST_ACCESS_TOKEN": "fixture-token"]
  )
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("accounts/pub-1"))
}

@Test func readerDoesNotEchoMissingOrProvidedToken() async {
  let cli = GoogleMarketingGatewayCLI(mode: .reader)
  let result = await cli.run(
    arguments: [
      "adsense", "accounts", "list",
      "--profile", "adsense-reader",
      "--config", readerProfileFixturePath
    ],
    environment: [:]
  )
  #expect(result.exitCode == 2)
  #expect(!result.stderr.contains("Bearer"))
}

@Test func readerRejectsTokenAndUnknownOptionsWithoutEchoingValues() async {
  let cli = GoogleMarketingGatewayCLI(mode: .reader)
  for option in ["access-token", "page-szie"] {
    let sensitiveValue = "do-not-echo-this"
    let result = await cli.run(
      arguments: [
        "adsense", "accounts", "list",
        "--profile", "adsense-reader",
        "--config", readerProfileFixturePath,
        "--\(option)", sensitiveValue
      ],
      environment: ["ADSENSE_TEST_ACCESS_TOKEN": "fixture-token"]
    )
    #expect(result.exitCode == 2)
    #expect(result.stderr.contains("INVALID_ARGUMENT"))
    #expect(!result.stderr.contains(sensitiveValue))
    #expect(!result.stderr.contains("fixture-token"))
  }
}

@Test func reportOnlyAdMobProfileCanListAccounts() async {
  let cli = GoogleMarketingGatewayCLI(
    mode: .reader,
    transport: StubTransport(statusCode: 200, body: #"{"account":[]}"#)
  )
  let result = await cli.run(
    arguments: [
      "admob", "accounts", "list",
      "--profile", "admob-report-reader",
      "--config", readerProfileFixturePath
    ],
    environment: ["ADMOB_REPORT_TEST_ACCESS_TOKEN": "fixture-token"]
  )
  #expect(result.exitCode == 0)
}

@Test func providerErrorExposesOnlyStructuredStatus() async {
  let cli = GoogleMarketingGatewayCLI(
    mode: .reader,
    transport: StubTransport(
      statusCode: 403,
      body: #"{"error":{"status":"PERMISSION_DENIED","message":"sensitive provider detail"}}"#
    )
  )
  let result = await cli.run(
    arguments: [
      "adsense", "accounts", "list",
      "--profile", "adsense-reader",
      "--config", readerProfileFixturePath
    ],
    environment: ["ADSENSE_TEST_ACCESS_TOKEN": "fixture-token"]
  )
  #expect(result.stderr.contains("PERMISSION_DENIED"))
  #expect(!result.stderr.contains("sensitive provider detail"))
  #expect(!result.stderr.contains("fixture-token"))
}

@Test func configStatusReportsAvailabilityWithoutTokenValues() async {
  let cli = GoogleMarketingGatewayCLI(mode: .reader)
  let result = await cli.run(
    arguments: ["config", "status", "--config", readerProfileFixturePath],
    environment: ["ADSENSE_TEST_ACCESS_TOKEN": "do-not-print-this"]
  )
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("adsense-reader"))
  #expect(result.stdout.contains("tokenAvailable"))
  #expect(!result.stdout.contains("do-not-print-this"))
}

@Test func readerRejectsProfileForDifferentProduct() async {
  let cli = GoogleMarketingGatewayCLI(mode: .reader)
  let result = await cli.run(
    arguments: [
      "adsense", "accounts", "list",
      "--profile", "admob-reader",
      "--config", readerProfileFixturePath
    ],
    environment: ["ADMOB_TEST_ACCESS_TOKEN": "fixture-token"]
  )
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("INVALID_PROFILE"))
  #expect(!result.stderr.contains("fixture-token"))
}

@Test func readerDispatchesEveryPublisherOperationThroughSelectedProfile() async {
  let cli = GoogleMarketingGatewayCLI(
    mode: .reader,
    transport: StubTransport(statusCode: 200, body: #"{"ok":true}"#)
  )
  let cases = [
    readerCase(["adsense", "adclients", "list", "--account", "accounts/pub-1"], "adsense-reader", "ADSENSE_TEST_ACCESS_TOKEN"),
    readerCase(["adsense", "adunits", "list", "--ad-client", "accounts/pub-1/adclients/ca-1"], "adsense-reader", "ADSENSE_TEST_ACCESS_TOKEN"),
    readerCase(["adsense", "sites", "list", "--account", "accounts/pub-1"], "adsense-reader", "ADSENSE_TEST_ACCESS_TOKEN"),
    readerCase(["adsense", "policy-issues", "list", "--account", "accounts/pub-1"], "adsense-reader", "ADSENSE_TEST_ACCESS_TOKEN"),
    readerCase([
      "adsense", "reports", "generate", "--account", "accounts/pub-1",
      "--start-date", "2026-08-01", "--end-date", "2026-08-02", "--metrics", "CLICKS"
    ], "adsense-reader", "ADSENSE_TEST_ACCESS_TOKEN"),
    readerCase(["admob", "apps", "list", "--account", "accounts/pub-1"], "admob-reader", "ADMOB_TEST_ACCESS_TOKEN"),
    readerCase(["admob", "adunits", "list", "--account", "accounts/pub-1"], "admob-reader", "ADMOB_TEST_ACCESS_TOKEN"),
    readerCase([
      "admob", "network-report", "generate", "--account", "accounts/pub-1",
      "--start-date", "2026-08-01", "--end-date", "2026-08-02", "--metrics", "CLICKS"
    ], "admob-reader", "ADMOB_TEST_ACCESS_TOKEN"),
    readerCase([
      "admob", "mediation-report", "generate", "--account", "accounts/pub-1",
      "--start-date", "2026-08-01", "--end-date", "2026-08-02", "--metrics", "CLICKS"
    ], "admob-reader", "ADMOB_TEST_ACCESS_TOKEN")
  ]
  for testCase in cases {
    let result = await cli.run(
      arguments: testCase.arguments + [
        "--profile", testCase.profile,
        "--config", readerProfileFixturePath
      ],
      environment: [testCase.tokenName: "fixture-token"]
    )
    #expect(result.exitCode == 0, "Failed command: \(testCase.arguments.joined(separator: " "))")
  }
}

private struct ReaderDispatchCase {
  let arguments: [String]
  let profile: String
  let tokenName: String
}

private func readerCase(_ arguments: [String], _ profile: String, _ tokenName: String) -> ReaderDispatchCase {
  ReaderDispatchCase(arguments: arguments, profile: profile, tokenName: tokenName)
}

private let readerProfileFixturePath = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .appendingPathComponent("Fixtures/reader-profiles.json")
  .path
