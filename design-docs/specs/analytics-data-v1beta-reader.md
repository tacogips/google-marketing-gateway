# Analytics Data v1beta reader

**Status**: Implemented and independently adversarially reviewed
**Implementation closure**: 2026-08-14 deterministic non-network verification
passes with no unresolved high or medium finding. Live Analytics access remains
intentionally outside this contract.
**Feature ID**: `analytics-data-v1beta-reader`
**Workflow mode**: `issue-resolution`
**Issue reference**: `workflow-input:analytics-data-v1beta-reader`
**Last contract review**: 2026-08-13

## Decision summary

Add three read-only Google Analytics Data API v1beta operations to
`google-marketing-gateway-reader`:

| CLI command | Catalog operation ID | HTTP contract |
| --- | --- | --- |
| `analytics-data metadata get --property properties/<digits>` | `analytics-data.metadata.get` | `GET https://analyticsdata.googleapis.com/v1beta/properties/<digits>/metadata` |
| `analytics-data reports run ...` | `analytics-data.reports.run` | `POST https://analyticsdata.googleapis.com/v1beta/properties/<digits>:runReport` |
| `analytics-data compatibility check ...` | `analytics-data.compatibility.check` | `POST https://analyticsdata.googleapis.com/v1beta/properties/<digits>:checkCompatibility` |

All operations require a selected reader profile whose product is exactly
`analytics-data` and whose only configured OAuth scope is
`https://www.googleapis.com/auth/analytics.readonly`. Requests use the existing
injected async transport, a compile-time fixed origin and versioned paths. The
CLI never accepts an origin, arbitrary path, header, request body, or access
token.

## Scope

### In scope

- Extend the Analytics Data product's reader-scope contract with the exact
  read-only scope.
- Add typed `Codable` request values for dimensions, metrics, a single date
  range, report options, and compatibility input.
- Build fixed-origin requests for metadata, report, and compatibility reads.
- Add CLI parsing, product/profile selection, operation-catalog entries, help,
  README examples, and deterministic tests for all three operations.
- Integrate with the shared credential resolver delivered by the installed-app
  OAuth slice while preserving environment-token profile compatibility.
- Record delivery evidence in this design, the feature plan, and the parent
  foundation plan when the implementation slice is executed.

### Out of scope

- Analytics Admin, realtime, pivot, batch, funnel, audience export, filter,
  ordering, cohort, comparison, and mutation operations.
- Fetching metadata to prevalidate metric or dimension names.
- Provider calls, live OAuth, response-domain modeling, pagination loops, retries,
  caching, or response transformation.
- User-supplied HTTP origins, paths, query fields, headers, or raw JSON bodies.
- Changes to the installed-app OAuth protocol, token-store schema, Google Ads
  operations, or other product profiles. Those are dependencies owned by their
  respective slices.

## Existing boundaries and dependencies

Implementation remains in the existing `GoogleMarketingGatewayCore` SwiftPM
target and its existing test target. No new package dependency or module is
needed.

The current code provides:

- `MarketingProduct.analyticsData` in
  `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`;
- product-isolated `CredentialProfile` validation in
  `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`;
- fixed-origin request construction and an injected async `HTTPTransport` in
  `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift` and
  `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift`;
- exact command routing and sanitized JSON errors in
  `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`.

The OAuth/config slice must expose an access-token resolver that selects the
configured environment value first and otherwise safely reads or refreshes the
selected profile's token store. This feature consumes that resolver and must not
duplicate token loading or persistence. An Analytics Data request is not built
until the resolver has validated the selected profile's product, capability, and
scope.

The mail-gateway references are patterns, not code to copy verbatim:

- `<mail-gateway-checkout>/Sources/MailGatewayCore/ConfigLoading.swift`
  demonstrates path/reference-only configuration and profile-specific path
  resolution; this gateway retains JSON profiles and product isolation.
- `<mail-gateway-checkout>/README.md` demonstrates concise setup
  and command documentation; this gateway must document the exact Analytics Data
  version, scope, profile, and non-network examples.

## Public command contract

Every command requires `--profile <id>` and either `--config <path>` or
`GOOGLE_MARKETING_GATEWAY_CONFIG`, following the existing selection contract.
Options may appear only once. Unknown options and positional residue fail with
`INVALID_ARGUMENT` and do not echo supplied values.

```text
analytics-data metadata get
  --property properties/<digits>
  --profile <id> --config <path>

analytics-data reports run
  --property properties/<digits>
  --start-date YYYY-MM-DD --end-date YYYY-MM-DD
  --metrics <name>[,<name>...]
  [--dimensions <name>[,<name>...]]
  [--offset <0...Int64.max>]
  [--limit <1...250000>]
  [--currency-code <AAA>]
  [--keep-empty-rows true|false]
  [--return-property-quota true|false]
  --profile <id> --config <path>

analytics-data compatibility check
  --property properties/<digits>
  --metrics <name>[,<name>...]
  [--dimensions <name>[,<name>...]]
  --profile <id> --config <path>
```

Boolean options require an explicit lowercase `true` or `false`. This keeps the
current `--name value` parser contract deterministic and distinguishes omission
from an explicitly encoded `false`.

## Profile and authorization contract

`MarketingProduct.analyticsData.readerOAuthScopes` is exactly:

```text
https://www.googleapis.com/auth/analytics.readonly
```

An Analytics Data profile must use:

- `product: "analytics-data"`;
- `capability: "reader"`;
- `oauthScopes` containing exactly the one scope above;
- the shared credential-reference fields required by its selected environment
  or token-store authentication mode.

The config continues to hold references and paths only. It must not hold OAuth
client JSON, client secrets, access tokens, refresh tokens, or any other secret
value. A profile carrying an Analytics Admin, Google Ads, AdSense, AdMob, or
other product scope is invalid even if it also contains `analytics.readonly`.
Operation dispatch additionally verifies the selected profile product and exact
operation scope before token resolution or network activity.

Only the resolved access token is added as `Authorization: Bearer <token>` by
the shared request builder. The value must never be logged, placed in a command
result, included in an error, or exposed through catalog/status output.

## Input validation

Validation is local, deterministic, and occurs before transport execution.
Provider-owned semantic compatibility remains provider validation.

### Property resource

Accept only the anchored shape `properties/[0-9]+`, using ASCII digits with at
least one digit and no sign, whitespace, extra slash, percent encoding, query,
fragment, or dot segment. Preserve the digits as a string. Do not parse the
property ID into a fixed-width integer or impose an undocumented provider
maximum. `properties/0` is structurally valid; the official metadata operation
uses it for universal metadata, while other operation semantics remain provider
owned.

### Dates

This CLI slice intentionally exposes the documented absolute-date subset only.
Both dates must be real Gregorian dates in exact zero-padded `YYYY-MM-DD` form,
and `startDate <= endDate`. Relative provider forms such as `today`, `yesterday`,
and `NdaysAgo` are not part of this bounded CLI contract. The encoded values are
the original validated strings.

### Metrics and dimensions

- Report and compatibility requests require 1 through 10 metrics.
- Both operations permit 0 through 9 dimensions.
- Comma parsing rejects an empty list, empty elements, leading/trailing
  whitespace within an element, ASCII control characters, and duplicates.
- Names otherwise remain opaque provider identifiers. In particular, do not
  restrict names to alphanumerics because property-specific custom identifiers
  can contain punctuation such as `customEvent:achievement_id`.
- The gateway does not maintain a mutable allowlist or claim that locally valid
  names exist or are compatible for the selected property.

The 10-metric and 9-dimension limits are official request limits. Duplicate
rejection is a deterministic CLI ambiguity rule, not a claim about provider
semantics.

### Numeric and optional values

- `offset` is optional and, when present, parses as a decimal `Int64` in
  `0...Int64.max` with no sign, separators, whitespace, or alternate radix.
- `limit` is optional and, when present, parses as a decimal `Int64` in
  `1...250_000`; the API defaults to 10,000 and returns at most 250,000 rows per
  request.
- The JSON request encodes both fields as decimal strings because the REST schema
  declares int64 values as JSON strings.
- `currencyCode` is optional and accepts exactly three uppercase ASCII letters,
  the ISO 4217 wire format. Membership in the evolving ISO table is provider
  validation.
- Boolean values accept only `true` or `false`; invalid or differently cased
  input fails locally.

## Typed wire models

Use small `Sendable`, `Equatable`, `Codable` value types grouped by Analytics
Data responsibility, with internal validation at their construction boundary:

```swift
struct AnalyticsDataDimension: Codable { let name: String }
struct AnalyticsDataMetric: Codable { let name: String }
struct AnalyticsDataDateRange: Codable {
  let startDate: String
  let endDate: String
}
struct AnalyticsDataRunReportRequest: Codable {
  let dimensions: [AnalyticsDataDimension]
  let metrics: [AnalyticsDataMetric]
  let dateRanges: [AnalyticsDataDateRange]
  let offset: String?
  let limit: String?
  let currencyCode: String?
  let keepEmptyRows: Bool?
  let returnPropertyQuota: Bool?
}
struct AnalyticsDataCheckCompatibilityRequest: Codable {
  let dimensions: [AnalyticsDataDimension]
  let metrics: [AnalyticsDataMetric]
}
```

The model uses Swift camelCase property names so default `JSONEncoder` keys are
the official camelCase field names. The request builder omits nil optionals,
encodes arrays as objects with `name`, and emits one `dateRanges` element for
`runReport`. `checkCompatibility` contains only `dimensions` and `metrics` for
this slice. Metadata has no request body.

## Request construction

Place Analytics Data models and request construction in dedicated files rather
than growing `PublisherRequests.swift` or `GatewayCLI.swift` into mixed-product
monoliths. Expected implementation surfaces are:

- `Sources/GoogleMarketingGatewayCore/AnalyticsDataModels.swift`;
- `Sources/GoogleMarketingGatewayCore/AnalyticsDataRequests.swift`;
- a focused Analytics Data CLI routing/parameter extension if needed to keep
  `GatewayCLI.swift` cohesive and below 1,000 lines;
- matching focused test files under
  `Tests/GoogleMarketingGatewayCoreTests/`.

The request builder accepts validated domain values plus the access token. It
constructs `URLComponents` from the constant
`https://analyticsdata.googleapis.com`, assigns only the three constant v1beta
path templates, and never accepts caller-supplied URL components or headers.

| Operation | Method | Path | Body |
| --- | --- | --- | --- |
| Metadata | `GET` | `/v1beta/{property}/metadata` | none |
| Run report | `POST` | `/v1beta/{property}:runReport` | `AnalyticsDataRunReportRequest` |
| Check compatibility | `POST` | `/v1beta/{property}:checkCompatibility` | `AnalyticsDataCheckCompatibilityRequest` |

All requests set `Accept: application/json`; POST requests also set
`Content-Type: application/json`. No query string is used. The API response
continues through `GoogleRESTClient`, which verifies 2xx status and JSON and
returns provider JSON unchanged. Non-2xx output exposes only the sanitized HTTP
status/category already allowed by shared error handling.

## Catalog, help, and documentation

The catalog adds exactly three implemented reader descriptors with product
`analytics-data`, capability `reader`, and only the `analytics.readonly` scope.
Reader help lists complete command spellings and option value forms. README
documents:

- Analytics Data API `v1beta` and fixed service origin;
- a path/reference-only Analytics Data reader profile;
- environment-token compatibility and installed-app login dependency;
- non-secret command examples for metadata, reports, and compatibility;
- the 250,000 report limit and explicit boolean syntax;
- that no live provider calls are part of verification.

The implementation updates evidence/status in this design and the plan, and
updates `impl-plans/completed/foundation-publisher-readers.md` only during the
implementation slice requested by the parent issue.

## Error and security behavior

- Invalid resources, dates, lists, numerics, booleans, config/profile selection,
  and unsupported flags fail before token resolution or transport use.
- Error messages name the invalid option or rule but never echo its supplied
  value, request JSON, configuration contents, filesystem content, headers, or
  credentials.
- Request tests inspect authorization using fixture values, but failures must not
  print those values.
- Fixed origin and anchored property validation prevent origin override, path
  traversal, query injection, fragment injection, and arbitrary action suffixes.
- The feature performs only read/report POST operations explicitly cataloged as
  reader capabilities. POST is required by the provider and does not authorize
  mutation exposure.
- Response JSON is provider-controlled and intentionally printed on success, as
  with existing reader operations; tests use deterministic fixtures and no live
  customer data.
- Token-store symlink, ownership, permission, refresh, logout deletion-scope,
  and callback attack defenses remain requirements of the shared OAuth slice and
  are not weakened or bypassed here.

## Test strategy

Deterministic tests use injected transport and temporary local fixture files.
No test opens a browser or calls Google.

### Model and request tests

- Exact method, scheme, host, v1beta path, absent query, headers, and body for
  each operation.
- Metadata body is nil; report/check bodies use official camelCase keys.
- `offset` and `limit` are JSON strings; booleans encode when explicitly present
  including `false`; nil options are absent.
- Property traversal, extra segments, signs, Unicode digits, whitespace, query,
  and fragment forms are rejected before transport.
- Real/leap dates, malformed dates, and reverse ranges are covered.
- Metric counts 0, 1, 10, and 11; dimension counts 0, 9, and 10; empty/duplicate
  elements and custom-name punctuation are covered.
- Offset boundaries `0` and `Int64.max`, overflow, negative/sign forms; limit
  boundaries `1` and `250000`, zero, overflow, and `250001` are covered.
- Currency and boolean accepted/rejected forms are covered.

### Profile, dispatch, and redaction tests

- Analytics Data profiles accept only the exact product/scope/capability tuple;
  cross-product and multi-product bundles are rejected.
- Existing environment-token profile fixtures continue decoding unchanged.
- Each new command dispatches through the matching catalog operation and selected
  profile to a recording transport; product mismatch fails before transport.
- Every command's required and optional flags are exercised, including explicit
  `false` values.
- Unknown/duplicate options and sensitive fixture strings never appear in stdout
  or stderr.
- Provider error bodies expose only the existing sanitized status and never echo
  request bodies, authorization, config, or token values.
- Catalog and help contain all three operation IDs/commands, the exact scope, and
  v1beta paths where documented.

Tests must compare independently specified URL and JSON fixtures rather than
constructing expectations through production request helpers.

## Acceptance criteria

The design is implemented when:

1. All three commands dispatch with the exact fixed contracts and typed bodies.
2. Product/scope isolation and all local validation rules above execute before
   network activity.
3. Old environment-only fixtures remain compatible with the shared optional OAuth
   profile extensions.
4. Catalog, help, README, design evidence, and active foundation plan state the
   exact scope and v1beta operation inventory.
5. No non-generated Swift file exceeds 1,000 lines.
6. The focused tests plus full lint, test, build, smoke, diff, and secret/path
   reviews pass without live OAuth or provider calls.

## Verification contract

The implementation slice must run and record exact results for:

```bash
mise run lint
mise run test
mise run build
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/reader-profiles.json
swift run google-marketing-gateway-reader config status --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/reader-profiles.json
swift run google-marketing-gateway-reader auth status --profile <fixture-profile> --config <temporary-fixture-config>
git diff --check
rg -n --hidden -g '!\.git/**' -g '!\.build/**' '(client_secret|refresh_token|access_token|developer[-_ ]?token|Bearer[[:space:]])' .
rg -n '/Users/|/home/' README.md Sources Tests design-docs impl-plans
for file in $(rg --files -g '*.swift'); do test "$(wc -l < "$file")" -lt 1000; done
```

The secret-pattern matches require manual classification: expected field names,
fixture placeholders, and redaction tests may remain, but credential values may
not. The absolute-path review permits this design's explicit external reference
paths only; production code, fixtures, README examples, and generated output may
not contain machine-local paths.

## Source contracts

- Google Analytics Data API v1beta REST service, `properties.runReport`,
  `properties.checkCompatibility`, and `properties.getMetadata`, reviewed
  2026-08-13.
- Google Analytics Data API v1beta `DateRange`, `Dimension`, and `Metric` types,
  reviewed 2026-08-13.
- Parent workflow issue `workflow-input:analytics-data-v1beta-reader`.
- Codex-agent implementation references listed under Existing boundaries and
  dependencies.

## Review record

### Design self-review

- 2026-08-13: Scope, exact endpoints, typed wire fields, validation boundaries,
  product isolation, failure redaction, file-size constraints, deterministic
  tests, and implementation dependencies were checked against the feature
  contract. No unresolved high or medium design finding remains before
  independent review.

### Independent design review

- 2026-08-13: Accepted with no high or medium design defects. Two plan-only
  concerns were deferred to the feature implementation plan: explicitly parse
  and validate operation input before credential resolution, and coordinate
  shared-file changes from the OAuth/Google Ads slices while retaining old
  environment-token fixture compatibility.
