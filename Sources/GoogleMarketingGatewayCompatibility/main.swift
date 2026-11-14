import GoogleGatewayAuth
import Foundation
import GoogleMarketingGatewayCore

FileHandle.standardError.write(Data(
  "Deprecated: use google-marketing-gateway-reader instead.\n".utf8
))
let gatewayInvocation = GatewayAuthBootstrap.prepareOrExit(product: .marketing, role: "reader")

let result = await GoogleMarketingGatewayCLI(mode: .reader).run(
  arguments: gatewayInvocation.arguments,
  environment: gatewayInvocation.environment
)
if !result.stdout.isEmpty { FileHandle.standardOutput.write(Data(result.stdout.utf8)) }
if !result.stderr.isEmpty { FileHandle.standardError.write(Data(result.stderr.utf8)) }
exit(gatewayInvocation.complete(exitCode: result.exitCode))
