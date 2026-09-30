import GoogleGatewayAuth
import Foundation
import GoogleMarketingGatewayCore

let gatewayInvocation = GatewayAuthBootstrap.prepareOrExit(product: .marketing, role: "writer")

let result = await GoogleMarketingGatewayCLI(mode: .writer).run(
  arguments: gatewayInvocation.arguments,
  environment: gatewayInvocation.environment
)
if !result.stdout.isEmpty { FileHandle.standardOutput.write(Data(result.stdout.utf8)) }
if !result.stderr.isEmpty { FileHandle.standardError.write(Data(result.stderr.utf8)) }
exit(gatewayInvocation.complete(exitCode: result.exitCode))
