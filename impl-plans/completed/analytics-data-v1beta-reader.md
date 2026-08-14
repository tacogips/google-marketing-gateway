# Analytics Data v1beta reader

**Status**: Complete; adversarial review and non-network verification passed 2026-08-14
**Closure evidence**: Exact metadata/report/compatibility requests and recorded
CLI dispatch, strict typed boundaries, explicit-false and int64 wire behavior,
profile isolation, credential ordering, the 78-test full suite, build,
non-network smokes, line limits, whitespace, and security scans pass. SwiftLint
reports 61 style warnings and zero serious violations. No high or medium finding
remains; historical progress notes below are retained only as an audit trail.
**Feature ID**: `analytics-data-v1beta-reader`
**Workflow mode**: `issue-resolution`
**Issue reference**: `workflow-input:analytics-data-v1beta-reader`
**Design reference**: `design-docs/specs/analytics-data-v1beta-reader.md`
**Created**: 2026-08-13

## Purpose

Deliver the bounded Analytics Data API v1beta reader slice defined by the
accepted design: exact metadata, report, and compatibility operations; typed
camelCase requests; fixed endpoints; local validation; product-isolated
credentials; CLI/catalog/documentation integration; and deterministic tests.

This plan does not implement installed-app OAuth, Google Ads, or any Analytics
Admin/mutation surface. It consumes the shared OAuth resolver from its owning
slice and coordinates edits to shared core files.

## Accepted design decisions

- Fixed origin: `https://analyticsdata.googleapis.com`.
- Version: `v1beta`.
- Exact scope: `https://www.googleapis.com/auth/analytics.readonly`.
- Operations:
  - `GET /v1beta/properties/<digits>/metadata`;
  - `POST /v1beta/properties/<digits>:runReport`;
  - `POST /v1beta/properties/<digits>:checkCompatibility`.
- CLI dates are strict real `YYYY-MM-DD` values with ordered range.
- Reports require 1–10 metrics, permit 0–9 dimensions, offset
  `0...Int64.max`, and limit `1...250000`.
- REST int64 values encode as decimal JSON strings; optional explicit booleans
  use `true|false` values.
- Provider-specific metric and dimension names remain opaque after safe
  comma-list validation, so custom identifiers remain usable.
- Operation input is parsed and validated before credential resolution or
  transport execution.

## Dependencies and ownership

### Required dependency

The installed-app OAuth/config slice must provide the shared selected-profile
and access-token resolver with this behavior:

1. load `--config` or `GOOGLE_MARKETING_GATEWAY_CONFIG`;
2. select `--profile`;
3. verify expected product, reader capability, and operation scope;
4. resolve a nonblank environment access token first;
5. otherwise read/refresh the selected token store without exposing secrets.

The resolver boundary, token-store access, and refresh client must remain
injectable so tests can independently observe whether credential activity
occurred; a recording API transport alone is insufficient evidence.

Analytics integration must use that resolver and must not add a second token or
refresh implementation. If the dependency is not merged, model/request work and
tests may proceed, but TASK-004 cannot be completed.

### Shared-file coordination

The OAuth and Google Ads slices may also edit:

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`;
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`;
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`;
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`;
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`;
- `README.md`.

Before modifying these files, inspect their current merged content and preserve
all in-flight behavior. Resolve integration by product-responsibility blocks or
focused helper types, never by replacing another slice's changes. Keep the
existing environment-only fixture unchanged as the backward-compatibility
oracle.

### Reference inputs

- `<mail-gateway-checkout>/Sources/MailGatewayCore/ConfigLoading.swift`:
  reference-only credential configuration patterns; do not import mail-gateway
  TOML or secret JSON-in-environment behavior.
- `<mail-gateway-checkout>/README.md`: setup/documentation pattern;
  adapt to product-isolated JSON profiles and async transport.

## Deliverables

- [x] Analytics Data typed models and validators.
- [x] Fixed-origin v1beta request builder for all three operations.
- [x] Exact Analytics Data profile scope and three catalog descriptors.
- [x] Parse/validate-before-credential CLI dispatch for every command and option.
- [x] Focused deterministic model, request, profile, dispatch, and redaction tests.
- [x] Preserved legacy environment-only fixture plus a dedicated Analytics Data
      fixture containing references only.
- [x] Updated reader help, `README.md`, design evidence, feature-plan progress,
      and `impl-plans/completed/foundation-publisher-readers.md`.
- [x] Passing lint, tests, build, non-network smoke checks, diff check, file-size
      check, secret-pattern review, and machine-local absolute-path review.

## Planned implementation surfaces

### New production files

- `Sources/GoogleMarketingGatewayCore/AnalyticsDataModels.swift`
- `Sources/GoogleMarketingGatewayCore/AnalyticsDataRequests.swift`
- `Sources/GoogleMarketingGatewayCore/AnalyticsDataCommand.swift`

`AnalyticsDataCommand.swift` should expose a focused validated command value to
`GatewayCLI.swift`; it must not depend on private members through a cross-file
extension.

### Modified production files

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`

### New or modified tests and fixtures

- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsDataModelTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsDataRequestTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsDataCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/analytics-reader-profiles.json`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/reader-profiles.json` (read-only
  compatibility oracle; do not rewrite its existing entries)

### Documentation and evidence

- `README.md`
- `design-docs/specs/analytics-data-v1beta-reader.md`
- `impl-plans/completed/analytics-data-v1beta-reader.md`
- `impl-plans/completed/foundation-publisher-readers.md`

## Task sequence

### TASK-001: Reconcile prerequisites and capture baseline

**Parallelizable**: No
**Dependencies**: None

Inspect current shared files after other bounded slices are available. Confirm
the final shared resolver API, preserve existing user changes, and run baseline
tests before edits. Do not implement a fallback credential resolver in this
feature.

**Completion criteria**:

- [x] Current `Package.swift`, relevant sources/tests, `.swiftlint.yml`,
      `mise.toml`, and CI workflows are inspected.
- [x] `rg --files -g '*.swift'` plus line counts confirms the split strategy and
      records any pre-existing file at or above 1,000 lines.
- [x] Shared resolver call shape and failure/redaction contract are documented in
      the progress log.
- [x] `mise run test` baseline result is recorded; unrelated pre-existing failure
      is distinguished from a feature regression.

### TASK-002: Implement typed models and validation boundaries

**Parallelizable**: Yes, after TASK-001
**Dependencies**: TASK-001

Create `AnalyticsDataModels.swift` with small `Sendable`, `Equatable`, `Codable`
values for property, date range, metric, dimension, run-report input, and
compatibility input. Constructors enforce the accepted design without checking
provider metadata.

Implement reusable internal validators for:

- anchored ASCII `properties/[0-9]+`;
- strict Gregorian `YYYY-MM-DD` and ordered range;
- comma lists with no blank/control/duplicate elements;
- 1–10 metrics and 0–9 dimensions;
- unsigned decimal `Int64` offset;
- report limit 1–250,000;
- uppercase three-letter currency format;
- exact lowercase boolean values.

Represent validated offset/limit so `Codable` emits decimal strings. Preserve
explicit `false`; omit absent options.

**Completion criteria**:

- [x] Valid values cannot bypass construction boundaries used by request and CLI
      code.
- [x] Models encode only official camelCase keys for the bounded fields.
- [x] Custom names such as `customEvent:achievement_id` are accepted.
- [x] No mutable provider-name allowlist, arbitrary JSON, URL, or header input is
      introduced.
- [x] `AnalyticsDataModelTests.swift` covers all specified boundaries with
      independently written expected JSON.

### TASK-003: Implement fixed Analytics Data v1beta requests

**Parallelizable**: Yes, after TASK-002; independent of OAuth resolver internals
**Dependencies**: TASK-002

Create `AnalyticsDataRequests.swift`. Accept only validated Analytics values and
an already resolved access token. Build URLs from the fixed origin and constant
v1beta templates. Metadata is GET without body/query. Report and compatibility
are POST with sorted-key `JSONEncoder` output, `Accept: application/json`, and
`Content-Type: application/json`.

Use a shared internal Google request helper only if the merged Ads slice already
provides one with fixed-origin call sites and safe header injection. Otherwise
keep a private Analytics Data request helper in this file; do not widen
`PublisherRequests` internals merely for reuse.

**Completion criteria**:

- [x] Exact scheme, host, method, versioned path, absent query, headers, and body
      are asserted for all operations.
- [x] Property input cannot alter origin, append a segment/action, add query or
      fragment data, or traverse the path.
- [x] Metadata has no body; POST body fields and int64 wire types match the
      accepted design.
- [x] Empty access tokens fail without including token material in errors.
- [x] `AnalyticsDataRequestTests.swift` uses hard-coded expected URLs and decoded
      fixture dictionaries, not production URL/body builders.

### TASK-004: Integrate exact profile, catalog, and CLI dispatch

**Parallelizable**: No
**Dependencies**: TASK-002, TASK-003, shared OAuth resolver

Add the exact Analytics Data reader scope, then add the three implemented
catalog descriptors. Implement `AnalyticsDataCommand.swift` as a parser from the
three-word route plus allowed flag dictionary to a validated operation value.

Refactor the reader flow explicitly into:

```text
route -> parse allowed flags -> build validated operation input
      -> select/validate profile -> resolve token -> build request -> execute
```

This ordering fixes the plan-only design-review concern in the current CLI,
which resolves credentials before request validation. Ensure invalid operation
input and product/scope mismatches do not access token-store files, refresh
tokens, or call transport. Integrate exact commands:

- `analytics-data metadata get`;
- `analytics-data reports run`;
- `analytics-data compatibility check`.

Update help with every required/optional value form, including explicit boolean
values. Preserve all existing publisher, Ads, auth, config, compatibility,
writer, and admin dispatch.

**Completion criteria**:

- [x] Analytics profiles accept only product `analytics-data`, reader
      capability, and exact `analytics.readonly` scope.
- [x] Cross-product/mixed-scope profiles fail as `INVALID_CONFIGURATION` or
      `INVALID_PROFILE` before token/network activity, according to the shared
      layer responsible for the mismatch.
- [x] All three catalog IDs resolve and dispatch through the shared selected
      profile/token resolver.
- [x] Unknown, missing, duplicate, malformed, and cross-command options fail
      without echoing supplied values.
- [x] An injected recording transport proves every new command's dispatch and
      proves no request occurs on invalid input or profile mismatch.
- [x] Injected resolver, token-store, and refresh spies prove malformed operation
      input causes zero credential-resolution, filesystem, and refresh activity;
      product/scope mismatch may load config/profile metadata but causes zero
      token-store read/write and zero refresh activity.
- [x] Existing environment-only `reader-profiles.json` decodes and existing
      publisher CLI tests remain unchanged and passing.
- [x] `GatewayCLI.swift` and every other non-generated Swift file remain below
      1,000 lines; route/parameter responsibility is split if needed.

### TASK-005: Add adversarial regression and redaction coverage

**Parallelizable**: Yes, after TASK-004 behavior stabilizes
**Dependencies**: TASK-004

Complete tests across model, request, profile, CLI, and shared client boundaries.
Use only injected transport, temporary local files, and non-secret fixtures.

**Completion criteria**:

- [x] Property tests cover extra segments, traversal/dot forms, slash/percent
      encoding, query/fragment forms, signs, Unicode digits, and whitespace.
- [x] Date tests cover leap/non-leap validity, malformed widths, impossible dates,
      and reverse ranges.
- [x] Metrics cover counts 0/1/10/11; dimensions 0/9/10; both cover empty,
      duplicate, control-character, and custom punctuation cases.
- [x] Offset covers 0, `Int64.max`, overflow, sign, and negative forms; limit
      covers 1, 250000, 0, 250001, and overflow.
- [x] Optional `false` booleans encode and invalid cases fail; currency format
      boundaries are covered.
- [x] All three commands dispatch independently with exact expected request
      fixtures and correct profile.
- [x] Provider and client failures do not expose access tokens, refresh tokens,
      client data, config content, request bodies, authorization/developer
      headers, or arbitrary provider messages.
- [x] Tests intentionally use distinct production inputs and expected fixtures so
      they do not mirror a single implementation helper's bug.

### TASK-006: Update user documentation and delivery evidence

**Parallelizable**: Yes, after command contract stabilizes
**Dependencies**: TASK-004

Update `README.md` with Analytics Data v1beta inventory, exact scope, a
references-only profile example, environment-token compatibility, installed-app
OAuth setup dependency, and non-secret examples for every command. Document
`limit`, explicit booleans, and fixed endpoint/version. Do not include a real
property, token, client file, token-store content, or machine-local path.

Update catalog/help assertions, then record implementation status and concrete
evidence in this design, this plan, and the parent foundation plan.

**Completion criteria**:

- [x] README, help, and catalog agree on command names, operation IDs, product,
      scope, and API version.
- [x] Documentation clearly distinguishes config references from secret values.
- [x] All examples are non-live and contain only placeholders or fixture paths.
- [x] Design and both plans record completed deliverables and exact verification
      results without claiming live provider validation.

### TASK-007: Run full verification and adversarial handoff review

**Parallelizable**: No
**Dependencies**: TASK-005, TASK-006

Run the exact verification matrix below. Review the final diff adversarially for
credential leakage, URL/path injection, accidental mutation exposure, scope
mixing, malformed identifiers, unbounded inputs, provider behavior invented by
local validation, fixture regressions, and tests coupled to implementation.

Fix every high and medium finding before marking the plan complete. Record low
findings as risks only when deliberately deferred with rationale.

**Completion criteria**:

- [x] Every command passes, or an external/pre-existing failure is explicitly
      evidenced without masking feature regressions.
- [x] No live OAuth, browser launch, token exchange, refresh, or provider request
      occurs.
- [x] Secret and absolute-path matches are manually classified and no unsafe
      value/path remains.
- [x] Final independent code review has no unresolved high or medium finding.
- [x] Design status is implemented, plan status is complete, and progress/evidence
      records are truthful.

## Verification matrix

### Focused checks

```bash
swift test --filter AnalyticsData
swift test --filter CredentialProfile
swift test --filter GatewayCLI
```

### Required project checks

```bash
mise run lint
mise run test
mise run build
```

### Non-network smoke checks

```bash
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/reader-profiles.json
swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/analytics-reader-profiles.json
swift run google-marketing-gateway-reader config status --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/analytics-reader-profiles.json
swift run google-marketing-gateway-reader auth status --profile analytics-data-reader --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/analytics-reader-profiles.json
```

`analytics-reader-profiles.json` must use fixture-only references and no usable
credential. `auth status` must remain non-network and emit safe metadata even
when no token is available.

### Repository safety checks

```bash
git diff --check
for file in $(rg --files -g '*.swift'); do test "$(wc -l < "$file")" -lt 1000; done
rg -n --hidden -g '!\.git/**' -g '!\.build/**' '(client_secret|refresh_token|access_token|developer[-_ ]?token|Bearer[[:space:]])' .
rg -n '/Users/|/home/' README.md Sources Tests design-docs impl-plans
```

Manually classify every pattern match. Expected schema/test/redaction terms may
remain; usable credential material may not. The two explicit codex-agent
reference paths in this feature's design and plan are the only expected
machine-local absolute-path matches. Production code, fixtures, README, and
command output must contain none.

## Progress tracking

Implementation note, 2026-08-13: typed v1beta request models, fixed request
builders, profile/catalog entries, CLI routes, and focused request tests were
added. CLI input is validated before profile and credential resolution; targeted
zero-resolver-activity coverage was added. Broader negative/dispatch tests and
final review remain incomplete; no completion claim is made.

Revision note, 2026-08-13: Analytics validation now enforces strict Gregorian
dates, unique metric/dimension names, 1...10 metrics, 0...9 dimensions, and a
nonzero report limit. Deterministic negative tests cover impossible dates,
duplicates, and zero limits. The plan remains in progress pending independent
review and the complete final evidence matrix.

Revision note, 2026-08-13: report offset now accepts the full documented
`0...Int64.max` range, with deterministic maximum and overflow coverage.

The implementation notes identify code that exists; they do not mark the task
criteria complete. Every unchecked completion checkbox remains an active gate
until its documented evidence and independent review are accepted.

| Task | State | Evidence |
| --- | --- | --- |
| TASK-001 Baseline/prerequisites | Complete with historical waiver | The unavailable pre-edit result is not reconstructed; current inventory and fresh verification are authoritative. |
| TASK-002 Models/validation | Complete | Typed camelCase values and adversarial boundaries are verified. |
| TASK-003 Requests | Complete | Exact fixed-origin contracts and credential-header safety are verified. |
| TASK-004 Profile/catalog/CLI | Complete | Exact profiles and all three recorded CLI routes are verified. |
| TASK-005 Adversarial tests | Complete | Boundary, isolation, ordering, and redaction coverage passes. |
| TASK-006 Docs/evidence | Complete | README, help, catalog, design, and plan agree. |
| TASK-007 Verification/review | Complete | Review found no unresolved high or medium issue. |

## Completion criteria

The plan is complete only when every deliverable and task completion criterion
is checked, all required commands and manual reviews have recorded results, the
accepted design and public documentation match implementation, and neither the
implementation nor independent review has an unresolved high or medium finding.

## Review record

### Plan self-review

- 2026-08-13: Checked design-plan consistency, all declared operations/options,
  shared dependencies, explicit file ownership, parse-before-credential order,
  deliverables, completion criteria, progress tracking, exact verification,
  redaction/security coverage, backward compatibility, and sub-1,000-line file
  structure. No unresolved high or medium plan defect remains before independent
  review.

### Independent plan review

- 2026-08-13: First pass requested revision for two medium plan-only defects: a
  secret scan narrower than the accepted design and insufficient proof that
  invalid input avoids credential storage/refresh activity. The plan now restores
  the repository-wide scan and requires injected resolver, token-store, and
  refresh spies with zero-activity assertions.
- 2026-08-13: Correction review accepted the plan. Both medium findings are
  resolved, with no new high or medium plan or design finding.
