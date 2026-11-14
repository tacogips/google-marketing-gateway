// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "google-marketing-gateway",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "GoogleMarketingGatewayCore", targets: ["GoogleMarketingGatewayCore"]),
    .executable(name: "google-marketing-gateway", targets: ["GoogleMarketingGatewayCompatibility"]),
    .executable(name: "google-marketing-gateway-reader", targets: ["GoogleMarketingGatewayReader"]),
    .executable(name: "google-marketing-gateway-writer", targets: ["GoogleMarketingGatewayWriter"]),
    .executable(name: "google-marketing-gateway-admin", targets: ["GoogleMarketingGatewayAdmin"])
  ],
  targets: [
    .target(name: "GoogleMarketingGatewayCore"),
    .executableTarget(
      name: "GoogleMarketingGatewayCompatibility",
      dependencies: ["GoogleMarketingGatewayCore"]
    ),
    .executableTarget(name: "GoogleMarketingGatewayReader", dependencies: ["GoogleMarketingGatewayCore"]),
    .executableTarget(name: "GoogleMarketingGatewayWriter", dependencies: ["GoogleMarketingGatewayCore"]),
    .executableTarget(name: "GoogleMarketingGatewayAdmin", dependencies: ["GoogleMarketingGatewayCore"]),
    .testTarget(
      name: "GoogleMarketingGatewayCoreTests",
      dependencies: ["GoogleMarketingGatewayCore"],
      resources: [.copy("Fixtures")]
    )
  ],
  swiftLanguageModes: [.v6]
)
