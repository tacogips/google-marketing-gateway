import Foundation

extension CredentialProfile {
  func tokenSourceDiagnostic(environment: [String: String]) -> String {
    let input = try? MarketingCredentialInput(profile: self, environment: environment)
    let selectedEnvironment = input?.accessToken != nil
    let source = input?.tokenStoreJSON != nil ? "ENVIRONMENT_JSON" : (selectedEnvironment ? "ENVIRONMENT_TOKEN" : "FILE")
    let selected = selectedEnvironment ? accessTokenEnvironmentVariable : (input?.tokenStorePath ?? tokenStorePath ?? "MISSING")
    return "tokenSource=\(source); selected=\(selected). Unset \(accessTokenEnvironmentVariable) to select the configured token store."
  }
}
