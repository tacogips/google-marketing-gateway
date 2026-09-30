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
  dependencies: [.package(url: "https://github.com/tacogips/google-gateway-auth.git", revision: "dda86daa5ca1b9a761977e4a9891e4e4380cf4dd")],
  targets: [
    .target(name: "GoogleMarketingGatewayCore"),
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
