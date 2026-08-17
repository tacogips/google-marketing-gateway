import Foundation
import GoogleMarketingGatewayCore

let result = await GoogleMarketingGatewayCLI(mode: .deleter).run(
  arguments: Array(CommandLine.arguments.dropFirst())
)
if !result.stdout.isEmpty { FileHandle.standardOutput.write(Data(result.stdout.utf8)) }
if !result.stderr.isEmpty { FileHandle.standardError.write(Data(result.stderr.utf8)) }
exit(result.exitCode)
