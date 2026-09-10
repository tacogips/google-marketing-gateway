import Foundation

extension CredentialProfile {
  func tokenSourceDiagnostic(environment: [String: String]) -> String {
    let selectedEnvironment = !(environment[accessTokenEnvironmentVariable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let source = selectedEnvironment ? "ENVIRONMENT_TOKEN" : "FILE"
    let selected = selectedEnvironment ? accessTokenEnvironmentVariable : (tokenStorePath ?? "MISSING")
    return "tokenSource=\(source); selected=\(selected). Unset \(accessTokenEnvironmentVariable) to select the configured token store."
  }
}
