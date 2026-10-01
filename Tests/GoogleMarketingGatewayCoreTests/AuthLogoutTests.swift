import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func everyMarketingProductAndRolePreservesExternalLogoutCredentials() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("external.json")
  let bytes = Data("external-fixture".utf8)
  try bytes.write(to: file)
  for mode in GatewayMode.allCases {
    for product in MarketingProduct.allCases {
      for source in ["ACCESS_TOKEN": "external-fixture", "TOKEN_STORE_JSON": "external-fixture", "TOKEN_STORE_PATH": file.path] {
        let env = ["XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
                   "GOOGLE_MARKETING_GATEWAY_" + source.key: source.value]
        let result = await GoogleMarketingGatewayCLI(mode: mode).run(
          arguments: ["auth", "logout", "--product", product.rawValue], environment: env)
        let supported = mode == .reader ? !product.readerOAuthScopes.isEmpty
          : product == .googleAds || product == .admob && mode == .writer
        if supported {
          #expect(result.exitCode == 0, "\(product.rawValue)/\(mode.rawValue): \(result.stderr)")
          #expect(result.stdout.contains("EXTERNAL_CREDENTIAL_PRESERVED"))
        } else {
          #expect(result.exitCode == 2)
          #expect(result.stderr.contains("INVALID_PROFILE"))
        }
        #expect(try Data(contentsOf: file) == bytes)
      }
    }
  }
}
