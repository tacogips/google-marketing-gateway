import Foundation

public struct GoogleMarketingGatewayCLI: Sendable {
  private let mode: GatewayMode
  private let client: GoogleRESTClient
  private let credentialResolver: any ReaderCredentialResolving
  private let authManager: any ReaderAuthManaging
  private let writerCommand: AdMobNativeWriterCommand

  public init(
    mode: GatewayMode,
    transport: any HTTPTransport = URLSessionTransport(),
    credentialResolver: any ReaderCredentialResolving = ReaderCredentialResolver(refresher: OAuthClient()),
    authManager: any ReaderAuthManaging = ReaderAuthService()
  ) {
    let client = GoogleRESTClient(transport: transport)
    self.mode = mode
    self.client = client
    self.credentialResolver = credentialResolver
    self.authManager = authManager
    self.writerCommand = AdMobNativeWriterCommand()
  }

  public func run(
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) async -> GatewayCommandResult {
    do {
      if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
        return GatewayCommandResult(exitCode: 0, stdout: usage)
      }
      if arguments == ["--version"] || arguments == ["version"] {
        return GatewayCommandResult(exitCode: 0, stdout: GoogleMarketingGatewayVersion.current + "\n")
      }
      if arguments == ["catalog"] {
        return GatewayCommandResult(exitCode: 0, stdout: try OperationCatalog.encoded())
      }
      if mode == .writer {
        guard Array(arguments.prefix(3)) == ["admob", "adunits", "create-native"] else {
          throw GatewayError(
            "No writer operation is enabled for this command",
            code: .forbiddenCapability,
            exitCode: 2
          )
        }
        return try await writerCommand.run(
          arguments: arguments,
          environment: environment
        )
      }
      guard mode == .reader else {
        throw GatewayError(
          "No \(mode.rawValue) operations are enabled; reviewed mutation allowlists are empty",
          code: .forbiddenCapability,
          exitCode: 2
        )
      }
      if Array(arguments.prefix(2)) == ["config", "validate"] {
        return try configValidate(arguments: Array(arguments.dropFirst(2)), environment: environment)
      }
      if Array(arguments.prefix(2)) == ["config", "status"] {
        return try configStatus(arguments: Array(arguments.dropFirst(2)), environment: environment)
      }
      if Array(arguments.prefix(2)) == ["auth", "status"] {
        return try authStatus(arguments: Array(arguments.dropFirst(2)), environment: environment)
      }
      if Array(arguments.prefix(2)) == ["auth", "logout"] {
        return try authLogout(arguments: Array(arguments.dropFirst(2)), environment: environment)
      }
      if Array(arguments.prefix(2)) == ["auth", "login"] {
        return try authLogin(arguments: Array(arguments.dropFirst(2)), environment: environment)
      }
      return try await runReader(arguments: arguments, environment: environment)
    } catch let error as GatewayError {
      return errorResult(error)
    } catch {
      return errorResult(GatewayError("Unexpected gateway failure", code: .transportFailure))
    }
  }

  public var usage: String {
    var lines = [
      "Usage: \(mode.executableName) <command> [options]",
      "",
      "Commands:",
      "  catalog                              Print supported operations and OAuth scopes",
      "  version                              Print version"
    ]
    if mode == .reader {
      lines += [
        "  config validate --config <path>      Validate profiles without reading tokens",
        "  config status --config <path>        Print token availability without token values",
        "  auth login --profile <id> --config <path> [--no-browser] [--redirect-uri <loopback-uri>] [--timeout-seconds <1...600>]",
        "  auth status --profile <id> --config <path>",
        "  auth logout --profile <id> --config <path>",
        "  google-ads accessible-customers list",
        "  google-ads search --customer-id <digits> --query-file <path> [--page-token <token>]",
        "  google-ads customer-client-links list --customer-id <digits> [--page-token <token>]",
        "  google-ads customer-clients list --customer-id <digits> [--page-token <token>]",
        "  google-ads customer-users list --customer-id <digits> [--page-token <token>]",
        "  analytics-data metadata get --property properties/<digits>",
        "  analytics-data reports run --property properties/<digits> --start-date YYYY-MM-DD --end-date YYYY-MM-DD --metrics METRIC[,METRIC]",
        "  analytics-data compatibility check --property properties/<digits> --metrics METRIC[,METRIC]",
        "  search-console sites list",
        "  search-console sites get --site <property>",
        "  search-console search-analytics query --site <property> --request-file <path>",
        "  search-console sitemaps list --site <property> [--sitemap-index <url>]",
        "  search-console sitemaps get --site <property> --feedpath <url>",
        "  search-console url-inspection inspect --site <property> --inspection-url <url> [--language-code <BCP47>]",
        "  adsense accounts list",
        "  adsense payments list --account accounts/<id>",
        "  adsense adclients list --account accounts/<id>",
        "  adsense adunits list --ad-client accounts/<id>/adclients/<id>",
        "  adsense sites list --account accounts/<id>",
        "  adsense policy-issues list --account accounts/<id>",
        "  adsense reports generate --account accounts/<id> --start-date YYYY-MM-DD",
        "    --end-date YYYY-MM-DD --metrics METRIC[,METRIC]",
        "  admob accounts list",
        "  admob apps list --account accounts/<id>",
        "  admob adunits list --account accounts/<id>",
        "  admob network-report generate --account accounts/<id> --start-date YYYY-MM-DD",
        "    --end-date YYYY-MM-DD --metrics METRIC[,METRIC]",
        "  admob mediation-report generate --account accounts/<id> --start-date YYYY-MM-DD",
        "    --end-date YYYY-MM-DD --metrics METRIC[,METRIC]",
        "",
        "Reader selection:",
        "  Every reader operation requires --profile <id> and a config path supplied with",
        "  --config <path> or GOOGLE_MARKETING_GATEWAY_CONFIG.",
        "  Tokens are resolved from each profile's accessTokenEnvironmentVariable first, then its OAuth token store.",
        "",
        "Implemented operations and accepted OAuth scopes:"
      ]
      for operation in OperationCatalog.implementedOperations {
        lines.append("  \(operation.id)")
        lines += operation.oauthScopes.map { "    \($0)" }
      }
    } else {
      if mode == .writer {
        lines += ["  \(AdMobNativeWriterCommand.usage)", "  All other mutations remain unavailable."]
      } else {
        lines.append("  No mutations enabled: the reviewed \(mode.rawValue) allowlist is empty.")
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private func runReader(
    arguments: [String],
    environment: [String: String]
  ) async throws -> GatewayCommandResult {
    guard arguments.count >= 2 else {
      throw GatewayError("Unknown or unavailable reader operation", code: .invalidArgument, exitCode: 2)
    }
    let compactGoogleAdsSearch = Array(arguments.prefix(2)) == ["google-ads", "search"]
    let command = compactGoogleAdsSearch ? ["google-ads", "search", "run"] : Array(arguments.prefix(3))
    let route = try readerRoute(command)
    let flags = try parseFlags(
      Array(arguments.dropFirst(compactGoogleAdsSearch ? 2 : 3)),
      allowedNames: readerFlagNames(command)
    )
    let preparedSearchAnalyticsRequest = try prepareSearchConsoleInput(command: command, flags: flags)
    if let preparedSearchAnalyticsRequest {
      _ = try SearchConsoleRequests.searchAnalytics(
        site: try SearchConsoleProperty(requiredFlag(flags, "site")),
        request: preparedSearchAnalyticsRequest,
        accessToken: "validation-token"
      )
    } else {
      try validateReaderInput(command: command, flags: flags)
    }
    let profile = try selectedProfile(
      flags: flags,
      environment: environment,
      operationID: route.operationID,
      product: route.product
    )
    let accessToken: String
    do {
      accessToken = try credentialResolver.accessToken(profile: profile, environment: environment)
    } catch let error as GatewayError {
      throw GatewayError(
        "Credential resolution failed",
        code: error.code,
        exitCode: error.exitCode
      )
    } catch {
      throw GatewayError("Credential resolution failed", code: .missingCredential, exitCode: 2)
    }
    let developerToken = try developerToken(profile: profile, environment: environment)
    let request = try readerRequest(command: command, flags: flags, accessToken: accessToken, developerToken: developerToken, loginCustomerId: profile.loginCustomerId, searchAnalyticsRequest: preparedSearchAnalyticsRequest)
    let data = try await client.execute(request)
    guard let output = String(bytes: data, encoding: .utf8) else {
      throw GatewayError("Google returned non-UTF-8 JSON", code: .invalidResponse)
    }
    return GatewayCommandResult(exitCode: 0, stdout: output + "\n")
  }

  private func readerRoute(_ command: [String]) throws -> (operationID: String, product: MarketingProduct) {
    switch command {
    case ["adsense", "accounts", "list"]:
      ("adsense.accounts.list", .adsense)
    case ["adsense", "payments", "list"]:
      ("adsense.payments.list", .adsense)
    case ["adsense", "adclients", "list"]:
      ("adsense.accounts.adclients.list", .adsense)
    case ["adsense", "adunits", "list"]:
      ("adsense.accounts.adclients.adunits.list", .adsense)
    case ["adsense", "sites", "list"]:
      ("adsense.accounts.sites.list", .adsense)
    case ["adsense", "policy-issues", "list"]:
      ("adsense.accounts.policyIssues.list", .adsense)
    case ["adsense", "reports", "generate"]:
      ("adsense.accounts.reports.generate", .adsense)
    case ["admob", "accounts", "list"]:
      ("admob.accounts.list", .admob)
    case ["admob", "apps", "list"]:
      ("admob.accounts.apps.list", .admob)
    case ["admob", "adunits", "list"]:
      ("admob.accounts.adUnits.list", .admob)
    case ["admob", "network-report", "generate"]:
      ("admob.accounts.networkReport.generate", .admob)
    case ["admob", "mediation-report", "generate"]:
      ("admob.accounts.mediationReport.generate", .admob)
    case ["google-ads", "accessible-customers", "list"]:
      ("google-ads.accessible-customers.list", .googleAds)
    case ["google-ads", "search", "run"]:
      ("google-ads.search", .googleAds)
    case ["google-ads", "customer-client-links", "list"]:
      ("google-ads.customer-client-links.list", .googleAds)
    case ["google-ads", "customer-clients", "list"]:
      ("google-ads.customer-clients.list", .googleAds)
    case ["google-ads", "customer-users", "list"]:
      ("google-ads.customer-users.list", .googleAds)
    case ["analytics-data", "metadata", "get"]:
      ("analytics-data.metadata.get", .analyticsData)
    case ["analytics-data", "reports", "run"]:
      ("analytics-data.reports.run", .analyticsData)
    case ["analytics-data", "compatibility", "check"]:
      ("analytics-data.compatibility.check", .analyticsData)
    case ["search-console", "sites", "list"]:
      ("search-console.sites.list", .searchConsole)
    case ["search-console", "sites", "get"]:
      ("search-console.sites.get", .searchConsole)
    case ["search-console", "search-analytics", "query"]:
      ("search-console.search-analytics.query", .searchConsole)
    case ["search-console", "sitemaps", "list"]:
      ("search-console.sitemaps.list", .searchConsole)
    case ["search-console", "sitemaps", "get"]:
      ("search-console.sitemaps.get", .searchConsole)
    case ["search-console", "url-inspection", "inspect"]:
      ("search-console.url-inspection.inspect", .searchConsole)
    default:
      throw GatewayError("Unknown or unavailable reader operation", code: .invalidArgument, exitCode: 2)
    }
  }

  private func readerFlagNames(_ command: [String]) -> Set<String> {
    let selection = ["config", "profile"]
    switch command {
    case ["adsense", "accounts", "list"], ["admob", "accounts", "list"]:
      return Set(selection + ["page-size", "page-token"])
    case ["adsense", "payments", "list"]:
      return Set(selection + ["account"])
    case ["adsense", "adclients", "list"],
         ["adsense", "sites", "list"],
         ["adsense", "policy-issues", "list"],
         ["admob", "apps", "list"],
         ["admob", "adunits", "list"]:
      return Set(selection + ["account", "page-size", "page-token"])
    case ["adsense", "adunits", "list"]:
      return Set(selection + ["ad-client", "page-size", "page-token"])
    case ["adsense", "reports", "generate"]:
      return Set(selection + [
        "account", "start-date", "end-date", "dimensions", "metrics", "filters", "order-by",
        "language-code", "currency-code", "limit", "reporting-time-zone"
      ])
    case ["admob", "network-report", "generate"], ["admob", "mediation-report", "generate"]:
      return Set(selection + [
        "account", "start-date", "end-date", "dimensions", "metrics", "language-code",
        "currency-code", "max-report-rows", "time-zone"
      ])
    case ["google-ads", "accessible-customers", "list"]:
      return Set(selection)
    case ["google-ads", "search", "run"]:
      return Set(selection + ["customer-id", "query-file", "page-token"])
    case ["google-ads", "customer-client-links", "list"],
         ["google-ads", "customer-clients", "list"],
         ["google-ads", "customer-users", "list"]:
      return Set(selection + ["customer-id", "page-token"])
    case ["analytics-data", "metadata", "get"]:
      return Set(selection + ["property"])
    case ["analytics-data", "reports", "run"]:
      return Set(selection + ["property", "start-date", "end-date", "metrics", "dimensions", "offset", "limit", "currency-code", "keep-empty-rows", "return-property-quota"])
    case ["analytics-data", "compatibility", "check"]:
      return Set(selection + ["property", "metrics", "dimensions"])
    case ["search-console", "sites", "list"]:
      return Set(selection)
    case ["search-console", "sites", "get"]:
      return Set(selection + ["site"])
    case ["search-console", "search-analytics", "query"]:
      return Set(selection + ["site", "request-file"])
    case ["search-console", "sitemaps", "list"]:
      return Set(selection + ["site", "sitemap-index"])
    case ["search-console", "sitemaps", "get"]:
      return Set(selection + ["site", "feedpath"])
    case ["search-console", "url-inspection", "inspect"]:
      return Set(selection + ["site", "inspection-url", "language-code"])
    default:
      return []
    }
  }

  private func readerRequest(
    command: [String],
    flags: [String: String],
    accessToken: String,
    developerToken: String?,
    loginCustomerId: String?,
    searchAnalyticsRequest: SearchConsoleAnalyticsRequest? = nil
  ) throws -> URLRequest {
    switch command {
    case ["adsense", "accounts", "list"]:
      try PublisherRequests.adsenseAccounts(
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["adsense", "payments", "list"]:
      try PublisherRequests.adsensePayments(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken
      )
    case ["adsense", "adclients", "list"]:
      try PublisherRequests.adsenseAdClients(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["adsense", "adunits", "list"]:
      try PublisherRequests.adsenseAdUnits(
        adClient: try requiredFlag(flags, "ad-client"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["adsense", "sites", "list"]:
      try PublisherRequests.adsenseSites(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["adsense", "policy-issues", "list"]:
      try PublisherRequests.adsensePolicyIssues(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["adsense", "reports", "generate"]:
      try PublisherRequests.adsenseReport(
        account: try requiredFlag(flags, "account"),
        parameters: try adsenseReportParameters(flags),
        accessToken: accessToken
      )
    case ["admob", "accounts", "list"]:
      try PublisherRequests.admobAccounts(
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["admob", "apps", "list"]:
      try PublisherRequests.admobApps(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["admob", "adunits", "list"]:
      try PublisherRequests.admobAdUnits(
        account: try requiredFlag(flags, "account"),
        accessToken: accessToken,
        pageSize: try intFlag(flags, "page-size"),
        pageToken: flags["page-token"]
      )
    case ["admob", "network-report", "generate"]:
      try PublisherRequests.admobNetworkReport(
        account: try requiredFlag(flags, "account"),
        reportSpec: try admobReportSpec(flags),
        accessToken: accessToken
      )
    case ["admob", "mediation-report", "generate"]:
      try PublisherRequests.admobMediationReport(
        account: try requiredFlag(flags, "account"),
        reportSpec: try admobReportSpec(flags),
        accessToken: accessToken
      )
    case ["google-ads", "accessible-customers", "list"]:
      try GoogleAdsRequests.accessibleCustomers(accessToken: accessToken, developerToken: try requiredValue(developerToken, message: "Google Ads developer token is required"), loginCustomerId: loginCustomerId)
    case ["google-ads", "search", "run"]:
      try GoogleAdsRequests.search(customerId: try requiredFlag(flags, "customer-id"), query: try loadGAQL(path: try requiredFlag(flags, "query-file")), pageToken: flags["page-token"], accessToken: accessToken, developerToken: try requiredValue(developerToken, message: "Google Ads developer token is required"), loginCustomerId: loginCustomerId)
    case ["google-ads", "customer-client-links", "list"]:
      try GoogleAdsRequests.customerClientLinks(
        customerId: try requiredFlag(flags, "customer-id"),
        pageToken: flags["page-token"],
        accessToken: accessToken,
        developerToken: try requiredValue(developerToken, message: "Google Ads developer token is required"),
        loginCustomerId: loginCustomerId
      )
    case ["google-ads", "customer-clients", "list"]:
      try GoogleAdsRequests.customerClients(
        customerId: try requiredFlag(flags, "customer-id"),
        pageToken: flags["page-token"],
        accessToken: accessToken,
        developerToken: try requiredValue(developerToken, message: "Google Ads developer token is required"),
        loginCustomerId: loginCustomerId
      )
    case ["google-ads", "customer-users", "list"]:
      try GoogleAdsRequests.customerUsers(
        customerId: try requiredFlag(flags, "customer-id"),
        pageToken: flags["page-token"],
        accessToken: accessToken,
        developerToken: try requiredValue(developerToken, message: "Google Ads developer token is required"),
        loginCustomerId: loginCustomerId
      )
    case ["analytics-data", "metadata", "get"]:
      try AnalyticsDataRequests.metadata(property: try requiredFlag(flags, "property"), accessToken: accessToken)
    case ["analytics-data", "reports", "run"]:
      try AnalyticsDataRequests.runReport(property: try requiredFlag(flags, "property"), request: try AnalyticsDataRequests.reportRequest(metrics: try requiredCommaSeparatedFlag(flags, "metrics"), dimensions: commaSeparatedFlag(flags, "dimensions"), startDate: try requiredFlag(flags, "start-date"), endDate: try requiredFlag(flags, "end-date"), offset: flags["offset"], limit: flags["limit"], currencyCode: flags["currency-code"], keepEmptyRows: boolFlag(flags, "keep-empty-rows"), returnPropertyQuota: boolFlag(flags, "return-property-quota")), accessToken: accessToken)
    case ["analytics-data", "compatibility", "check"]:
      try AnalyticsDataRequests.compatibility(property: try requiredFlag(flags, "property"), metrics: try requiredCommaSeparatedFlag(flags, "metrics"), dimensions: commaSeparatedFlag(flags, "dimensions"), accessToken: accessToken)
    case ["search-console", "sites", "list"]:
      try SearchConsoleRequests.sitesList(accessToken: accessToken)
    case ["search-console", "sites", "get"]:
      try SearchConsoleRequests.sitesGet(site: try SearchConsoleProperty(requiredFlag(flags, "site")), accessToken: accessToken)
    case ["search-console", "search-analytics", "query"]:
      try SearchConsoleRequests.searchAnalytics(site: try SearchConsoleProperty(requiredFlag(flags, "site")), request: try requiredSearchAnalyticsRequest(searchAnalyticsRequest), accessToken: accessToken)
    case ["search-console", "sitemaps", "list"]:
      try SearchConsoleRequests.sitemapsList(site: try SearchConsoleProperty(requiredFlag(flags, "site")), sitemapIndex: try flags["sitemap-index"].map(SearchConsoleHTTPURL.init), accessToken: accessToken)
    case ["search-console", "sitemaps", "get"]:
      try SearchConsoleRequests.sitemapsGet(site: try SearchConsoleProperty(requiredFlag(flags, "site")), feedpath: try SearchConsoleHTTPURL(requiredFlag(flags, "feedpath")), accessToken: accessToken)
    case ["search-console", "url-inspection", "inspect"]:
      try SearchConsoleRequests.urlInspection(site: try SearchConsoleProperty(requiredFlag(flags, "site")), inspectionURL: try SearchConsoleHTTPURL(requiredFlag(flags, "inspection-url")), languageCode: try flags["language-code"].map(SearchConsoleLanguageCode.init), accessToken: accessToken)
    default:
      throw GatewayError("Unknown or unavailable reader operation", code: .invalidArgument, exitCode: 2)
    }
  }

  private func selectedProfile(
    flags: [String: String],
    environment: [String: String],
    operationID: String,
    product: MarketingProduct
  ) throws -> CredentialProfile {
    let configuration = try loadConfiguration(flags: flags, environment: environment)
    let profile = try configuration.profile(id: requiredFlag(flags, "profile"))
    guard profile.product == product, profile.capability == .reader else {
      throw GatewayError("Credential profile does not match the reader operation", code: .invalidProfile, exitCode: 2)
    }
    let operation = try OperationCatalog.operation(id: operationID)
    guard !Set(profile.oauthScopes).isDisjoint(with: operation.oauthScopes) else {
      throw GatewayError("Credential profile lacks an accepted operation scope", code: .invalidProfile, exitCode: 2)
    }
    return profile
  }

  private func configValidate(
    arguments: [String],
    environment: [String: String]
  ) throws -> GatewayCommandResult {
    let flags = try parseFlags(arguments, allowedNames: ["config"])
    let configuration = try loadConfiguration(flags: flags, environment: environment)
    return GatewayCommandResult(
      exitCode: 0,
      stdout: try encodedJSON(ConfigValidationOutput(valid: true, profileCount: configuration.profiles.count))
    )
  }

  private func configStatus(
    arguments: [String],
    environment: [String: String]
  ) throws -> GatewayCommandResult {
    let flags = try parseFlags(arguments, allowedNames: ["config"])
    let configuration = try loadConfiguration(flags: flags, environment: environment)
    let statuses = configuration.profiles.map { profile in
      CredentialProfileStatus(
        id: profile.id,
        product: profile.product,
        capability: profile.capability,
        oauthScopes: profile.oauthScopes,
        accessTokenEnvironmentVariable: profile.accessTokenEnvironmentVariable,
        tokenAvailable: !(environment[profile.accessTokenEnvironmentVariable] ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      )
    }
    return GatewayCommandResult(exitCode: 0, stdout: try encodedJSON(ConfigStatusOutput(profiles: statuses)))
  }

  private func authStatus(arguments: [String], environment: [String: String]) throws -> GatewayCommandResult {
    let flags = try parseFlags(arguments, allowedNames: ["config", "profile"])
    let profile = try loadConfiguration(flags: flags, environment: environment).profile(id: requiredFlag(flags, "profile"))
    return GatewayCommandResult(exitCode: 0, stdout: try encodedJSON(authManager.status(profile: profile, environment: environment)))
  }

  private func authLogout(arguments: [String], environment: [String: String]) throws -> GatewayCommandResult {
    let flags = try parseFlags(arguments, allowedNames: ["config", "profile"])
    let profile = try loadConfiguration(flags: flags, environment: environment).profile(id: requiredFlag(flags, "profile"))
    let deleted = try authManager.logout(profile: profile)
    return GatewayCommandResult(exitCode: 0, stdout: try encodedJSON(LogoutOutput(profileId: profile.id, product: profile.product, removed: deleted)))
  }

  private func authLogin(arguments: [String], environment: [String: String]) throws -> GatewayCommandResult {
    let flags = try parseFlags(arguments, allowedNames: ["config", "profile", "no-browser", "redirect-uri", "timeout-seconds"])
    let profile = try loadConfiguration(flags: flags, environment: environment).profile(id: requiredFlag(flags, "profile"))
    let timeoutSeconds = try intFlag(flags, "timeout-seconds") ?? 300
    guard (1...600).contains(timeoutSeconds) else { throw GatewayError("OAuth callback timeout is invalid", code: .invalidArgument, exitCode: 2) }
    return GatewayCommandResult(exitCode: 0, stdout: try encodedJSON(authManager.login(profile: profile, noBrowser: flags["no-browser"] != nil, redirectURI: flags["redirect-uri"], timeoutSeconds: Int32(timeoutSeconds))))
  }

  private func developerToken(profile: CredentialProfile, environment: [String: String]) throws -> String? {
    guard profile.product == .googleAds else { return nil }
    guard let variable = profile.developerTokenEnvironmentVariable,
      let value = environment[variable], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw GatewayError("Google Ads developer token environment value is required", code: .missingCredential, exitCode: 2)
    }
    return value
  }

  private func requiredValue(_ value: String?, message: String) throws -> String {
    guard let value else { throw GatewayError(message, code: .missingCredential, exitCode: 2) }
    return value
  }

  private func requiredSearchAnalyticsRequest(_ value: SearchConsoleAnalyticsRequest?) throws -> SearchConsoleAnalyticsRequest {
    guard let value else { throw GatewayError("Search Analytics request is invalid", code: .invalidArgument, exitCode: 2) }
    return value
  }

  private func loadGAQL(path: String) throws -> String {
    guard CredentialProfileConfiguration.isSafePath(path) else { throw GatewayError("GAQL file path is invalid", code: .invalidArgument, exitCode: 2) }
    let data: Data
    do { data = try SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1_048_576)
    } catch { throw GatewayError("GAQL input is unavailable or unsafe", code: .invalidArgument, exitCode: 2) }
    guard let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw GatewayError("GAQL input is empty, oversized, or invalid UTF-8", code: .invalidArgument, exitCode: 2)
    }
    return text
  }

  private func boolFlag(_ flags: [String: String], _ name: String) throws -> Bool? {
    guard let value = flags[name] else { return nil }
    guard value == "true" || value == "false" else { throw GatewayError("--\(name) must be true or false", code: .invalidArgument, exitCode: 2) }
    return value == "true"
  }

  private func validateReaderInput(command: [String], flags: [String: String]) throws {
    let developer = command.first == "google-ads" ? "validation-developer" : nil
    _ = try readerRequest(command: command, flags: flags, accessToken: "validation-token", developerToken: developer, loginCustomerId: nil)
  }

  private func prepareSearchConsoleInput(command: [String], flags: [String: String]) throws -> SearchConsoleAnalyticsRequest? {
    guard command == ["search-console", "search-analytics", "query"] else { return nil }
    return try SearchConsoleValidation.decodeRequestFile(path: requiredFlag(flags, "request-file"))
  }

  private func loadConfiguration(
    flags: [String: String],
    environment: [String: String]
  ) throws -> CredentialProfileConfiguration {
    guard let path = flags["config"] ?? environment["GOOGLE_MARKETING_GATEWAY_CONFIG"] else {
      throw GatewayError(
        "--config or GOOGLE_MARKETING_GATEWAY_CONFIG is required",
        code: .invalidConfiguration,
        exitCode: 2
      )
    }
    return try CredentialProfileConfiguration.load(path: path)
  }

  private func adsenseReportParameters(_ flags: [String: String]) throws -> AdSenseReportParameters {
    try AdSenseReportParameters(
      dateRange: try reportDateRange(flags),
      dimensions: commaSeparatedFlag(flags, "dimensions"),
      metrics: try requiredCommaSeparatedFlag(flags, "metrics"),
      filters: commaSeparatedFlag(flags, "filters"),
      orderBy: commaSeparatedFlag(flags, "order-by"),
      languageCode: flags["language-code"],
      currencyCode: flags["currency-code"],
      limit: try intFlag(flags, "limit"),
      reportingTimeZone: flags["reporting-time-zone"]
    )
  }

  private func admobReportSpec(_ flags: [String: String]) throws -> AdMobReportSpec {
    let localization: AdMobLocalizationSettings?
    if flags["currency-code"] != nil || flags["language-code"] != nil {
      localization = try AdMobLocalizationSettings(
        currencyCode: flags["currency-code"],
        languageCode: flags["language-code"]
      )
    } else {
      localization = nil
    }
    return try AdMobReportSpec(
      dateRange: reportDateRange(flags),
      dimensions: commaSeparatedFlag(flags, "dimensions"),
      metrics: requiredCommaSeparatedFlag(flags, "metrics"),
      localizationSettings: localization,
      maxReportRows: intFlag(flags, "max-report-rows"),
      timeZone: flags["time-zone"]
    )
  }

  private func reportDateRange(_ flags: [String: String]) throws -> MarketingDateRange {
    try MarketingDateRange(
      startDate: MarketingDate.parse(requiredFlag(flags, "start-date")),
      endDate: MarketingDate.parse(requiredFlag(flags, "end-date"))
    )
  }

  private func parseFlags(_ arguments: [String], allowedNames: Set<String>) throws -> [String: String] {
    var result: [String: String] = [:]
    var index = 0
    while index < arguments.count {
      let key = arguments[index]
      guard key.hasPrefix("--"), key.count > 2 else {
        throw GatewayError("Expected --name value option", code: .invalidArgument, exitCode: 2)
      }
      let name = String(key.dropFirst(2))
      guard allowedNames.contains(name) else {
        throw GatewayError("Option --\(name) is not allowed", code: .invalidArgument, exitCode: 2)
      }
      guard result[name] == nil else {
        throw GatewayError("Option --\(name) may be supplied only once", code: .invalidArgument, exitCode: 2)
      }
      if name == "no-browser" {
        result[name] = "true"
        index += 1
        continue
      }
      guard index + 1 < arguments.count else {
        throw GatewayError("Expected --name value option", code: .invalidArgument, exitCode: 2)
      }
      result[name] = arguments[index + 1]
      index += 2
    }
    return result
  }

  private func requiredFlag(_ flags: [String: String], _ name: String) throws -> String {
    guard let value = flags[name], !value.isEmpty else {
      throw GatewayError("--\(name) is required", code: .invalidArgument, exitCode: 2)
    }
    return value
  }

  private func intFlag(_ flags: [String: String], _ name: String) throws -> Int? {
    guard let value = flags[name] else { return nil }
    guard let parsed = Int(value) else {
      throw GatewayError("--\(name) must be an integer", code: .invalidArgument, exitCode: 2)
    }
    return parsed
  }

  private func commaSeparatedFlag(_ flags: [String: String], _ name: String) -> [String] {
    guard let value = flags[name] else { return [] }
    return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
  }

  private func requiredCommaSeparatedFlag(_ flags: [String: String], _ name: String) throws -> [String] {
    let values = commaSeparatedFlag(flags, name)
    guard !values.isEmpty else {
      throw GatewayError("--\(name) is required", code: .invalidArgument, exitCode: 2)
    }
    return values
  }

  private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard let output = String(bytes: data, encoding: .utf8) else {
      throw GatewayError("Unable to encode command output", code: .invalidResponse)
    }
    return output + "\n"
  }

  private func errorResult(_ error: GatewayError) -> GatewayCommandResult {
    let payload = ["error": ["code": error.code.rawValue, "message": error.message]]
    let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    return GatewayCommandResult(
      exitCode: error.exitCode,
      stderr: (String(bytes: data, encoding: .utf8) ?? "{\"error\":{\"code\":\"INVALID_RESPONSE\"}}") + "\n"
    )
  }
}

private struct ConfigValidationOutput: Encodable {
  let valid: Bool
  let profileCount: Int
}

private struct ConfigStatusOutput: Encodable {
  let profiles: [CredentialProfileStatus]
}

private struct CredentialProfileStatus: Encodable {
  let id: String
  let product: MarketingProduct
  let capability: GatewayMode
  let oauthScopes: [String]
  let accessTokenEnvironmentVariable: String
  let tokenAvailable: Bool
}

private struct LogoutOutput: Encodable {
  let profileId: String
  let product: MarketingProduct
  let removed: Bool
}
