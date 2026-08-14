import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func writerPlanIsZeroNetworkAndUsesExactProfile() async throws {
  let configuration = try temporaryWriterConfiguration()
  defer { try? FileManager.default.removeItem(at: configuration.deletingLastPathComponent()) }
  let result = await GoogleMarketingGatewayCLI(mode: .writer).run(
    arguments: [
      "admob", "adunits", "create-native", "plan",
      "--account", "accounts/pub-9876543210987654",
      "--app-id", "ca-app-pub-9876543210987654~0123456789",
      "--display-name", "Local verification only",
      "--ad-types", "VIDEO,RICH_MEDIA",
      "--profile", "fixture-admob-writer", "--config", configuration.path
    ],
    environment: ["ADMOB_WRITER_PLAN_TEST_TOKEN": "fixture-token-not-a-secret"]
  )
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("\"requestSent\" : false"))
  #expect(result.stdout.contains("\"applyAvailable\" : false"))
  #expect(!result.stdout.contains("planToken"))
  #expect(result.stdout.contains("RICH_MEDIA"))
  #expect(result.stdout.contains("VIDEO"))
}

@Test func writerApplyRemainsFailClosed() async {
  let result = await GoogleMarketingGatewayCLI(mode: .writer).run(
    arguments: ["admob", "adunits", "create-native", "apply", "--plan-token-stdin"]
  )
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("Unknown or unavailable writer operation"))
}

@Test func writerRejectsArbitraryMutationAndPreviewDoesNotReadToken() async throws {
  let configuration = try temporaryWriterConfiguration()
  defer { try? FileManager.default.removeItem(at: configuration.deletingLastPathComponent()) }
  let cli = GoogleMarketingGatewayCLI(mode: .writer)
  let wrongCommand = await cli.run(arguments: ["admob", "apps", "create"])
  #expect(wrongCommand.exitCode == 2)
  let previewWithoutToken = await cli.run(
    arguments: [
      "admob", "adunits", "create-native", "plan",
      "--account", "accounts/pub-9876543210987654",
      "--app-id", "ca-app-pub-9876543210987654~0123456789",
      "--display-name", "Native", "--ad-types", "RICH_MEDIA",
      "--profile", "fixture-admob-writer", "--config", configuration.path
    ],
    environment: [:]
  )
  #expect(previewWithoutToken.exitCode == 0)
  #expect(!previewWithoutToken.stdout.contains("ADMOB_WRITER_PLAN_TEST_TOKEN"))
  #expect(!previewWithoutToken.stderr.contains("ADMOB_WRITER_PLAN_TEST_TOKEN"))
}

private func temporaryWriterConfiguration() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  let configuration = directory.appendingPathComponent("admob-writer.json")
  try Data("""
  {"profiles":[{"id":"fixture-admob-writer","product":"admob","capability":"writer","oauthScopes":["https://www.googleapis.com/auth/admob.monetization"],"accessTokenEnvironmentVariable":"ADMOB_WRITER_PLAN_TEST_TOKEN"}]}
  """.utf8).write(to: configuration)
  return configuration
}
