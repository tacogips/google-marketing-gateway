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
    .executable(name: "google-marketing-gateway-deleter", targets: ["GoogleMarketingGatewayDeleter"]),
    .executable(name: "google-marketing-gateway-admin", targets: ["GoogleMarketingGatewayAdmin"])
  ],
  dependencies: [.package(url: "https://github.com/tacogips/google-gateway-auth.git", revision: "2951cd8829d94d0b16e2a3bfdca301e57bb1f862")],
  targets: [
    .target(name: "GoogleMarketingGatewayCore", dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth")]),
    .executableTarget(
      name: "GoogleMarketingGatewayCompatibility",
      dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleMarketingGatewayCore"]
    ),
    .executableTarget(name: "GoogleMarketingGatewayReader", dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleMarketingGatewayCore"]),
    .executableTarget(name: "GoogleMarketingGatewayWriter", dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleMarketingGatewayCore"]),
    .executableTarget(name: "GoogleMarketingGatewayDeleter", dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleMarketingGatewayCore"]),
    .executableTarget(name: "GoogleMarketingGatewayAdmin", dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleMarketingGatewayCore"]),
    .testTarget(
      name: "GoogleMarketingGatewayCoreTests",
      dependencies: ["GoogleMarketingGatewayCore"],
      resources: [.copy("Fixtures")]
    )
  ],
  swiftLanguageModes: [.v6]
)
