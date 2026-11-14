# Google Ads v25 reader

**Feature ID**: `google-ads-v25-reader`
**Issue**: `workflow-input:google-ads-v25-reader`
**Workflow mode**: `issue-resolution`
**Status**: Complete; adversarial review and non-network verification passed 2026-08-14
**Closure evidence**: Exact v25 request and recorded CLI tests, adversarial
credential/profile/identifier/page-token cases, bounded GAQL rejection, the
78-test full suite, build, auth/config smokes, line limits, whitespace, and
security scans pass. SwiftLint reports 61 style warnings and zero serious
violations. No high or medium finding remains; historical progress notes below
are retained only as an audit trail.
**Design reference**: `design-docs/specs/google-ads-v25-reader.md`
**Last reviewed**: 2026-08-13

## Outcome

Deliver the two bounded Google Ads API v25 reader operations defined by the
accepted design, using an exact product scope, environment-only developer token,
optional validated login customer ID, bounded GAQL file input, fixed transport
contracts, deterministic tests, and updated public documentation.

## Dependencies and sequencing

- The shared installed-desktop OAuth slice must provide the backwards-compatible
  credential schema and injectable access-token resolver. This feature may be
  implemented in the same integration branch, but Google Ads request execution
  must depend on that resolver rather than duplicate refresh or token-store code.
- Current SwiftPM target boundaries remain: production code stays in
  `GoogleMarketingGatewayCore`; executable entry points continue to delegate to
  the core CLI.
- Config/catalog work precedes request and CLI integration. Local input checks
  precede credential resolution and transport execution wherever doing so does
  not disclose credential availability.
- No task requires live OAuth, Google Ads access, a real developer token, a
  commit, or a push.

## Deliverables

- [x] Backwards-compatible Google Ads profile fields and exact product/scope
  validation in `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
  or a responsibility-split companion file.
- [x] Google Ads catalog descriptors in
  `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`.
- [x] Typed Google Ads v25 request models/builders in a focused file such as
  `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift`.
- [x] Injectable, descriptor-based 1 MiB UTF-8 GAQL loader in a focused file
  such as `Sources/GoogleMarketingGatewayCore/BoundedTextFileLoader.swift`.
- [x] CLI help, flag parsing, route dispatch, credential resolution, and request
  execution updates in `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
  and responsibility-split extensions as needed to remain below 1000 lines.
- [x] Deterministic profile, request, file-loader, catalog, dispatch, redaction,
  and backwards-compatibility tests under
  `Tests/GoogleMarketingGatewayCoreTests/` with non-secret fixtures.
- [x] A non-network auth smoke helper at
  `scripts/smoke-reader-auth.sh` that creates a unique temporary config and
  absent token-store target, validates containment, and cleans up only its own
  files.
- [x] Google Ads v25 setup and command documentation in `README.md`, the
  operation/help surfaces, `design-docs/specs/google-ads-v25-reader.md`, and
  `impl-plans/completed/foundation-publisher-readers.md`.

Implementation progress, 2026-08-13: code exists for the exact `adwords`
profile, developer-token environment reference, v25 request builders,
descriptor-relative bounded GAQL read, validation-before-credentials CLI
dispatch, catalog/help, smoke helper, and deterministic contract tests. Every
task and completion checkbox intentionally remains unchecked until its complete
evidence matrix and independent review pass; this plan is in progress.

## Tasks

### TASK-001: Extend profile and catalog contracts

**Parallelizable**: No
**Depends on**: Shared credential-schema shape is agreed.

Work:

- Add optional product metadata without making new keys mandatory for AdSense,
  AdMob, or legacy environment-token fixtures.
- Require a safe `developerTokenEnvironmentVariable` for `google-ads`, allow an
  optional ASCII-digits-only `loginCustomerId`, and reject either Google
  Ads-only field when present on another product.
- Represent valid scope bundles by product. Require the exact singleton Google
  Ads `adwords` bundle, reject duplicates/cross-product scopes, and preserve all
  previously valid existing-product bundles.
- Add implemented operation descriptors:
  `google-ads.accessible-customers.list` and `google-ads.search`.

Completion criteria:

- [x] Google Ads profiles cannot decode without the developer-token environment
  reference or with an unsafe reference, invalid login customer ID, duplicate
  scope, missing scope, or foreign scope.
- [x] Existing credential fixtures and valid product profiles decode unchanged.
- [x] Catalog descriptors have product `google-ads`, reader capability, exact
  scope, and stable IDs matching the design.
- [x] Profile and catalog tests fail before implementation and pass afterward.

### TASK-002: Implement bounded GAQL loading

**Parallelizable**: Yes, after TASK-001 types are stable
**Depends on**: None beyond Foundation/macOS 14.

Work:

- Define an injectable text-file loading protocol used by CLI code.
- Open read-only with terminal-symlink refusal; inspect the opened descriptor and
  accept only regular files.
- Enforce 1,048,576 bytes using metadata plus a maximum-plus-one read, decode
  UTF-8, reject empty/whitespace-only content, and preserve accepted text.
- Return categorized sanitized errors without including GAQL contents.

Completion criteria:

- [x] Missing, unreadable, terminal-symlink, non-regular, invalid-UTF-8, empty,
  whitespace-only, and over-limit files are rejected without transport activity.
- [x] Exactly-limit input succeeds; limit-plus-one and simulated concurrent
  growth fail deterministically.
- [x] Tests inject file behavior where platform races cannot be reproduced
  reliably, while at least one integration test exercises a real temporary file.

### TASK-003: Build fixed Google Ads v25 requests

**Parallelizable**: Yes, after TASK-001 types are stable
**Depends on**: TASK-001.

Work:

- Add validated customer-ID and page-token value types or equivalent closed
  initializers. Enforce the design's independent 16,384-byte page-token bound.
- Add a typed camelCase `Codable` search body with optional `pageToken` omitted
  when absent.
- Build only the two accepted requests against
  `https://googleads.googleapis.com`, with exact v25 paths and methods.
- Add bearer and developer-token headers and conditionally add the configured
  login-customer-id. Expose no arbitrary URL/path/method/header initializer.

Completion criteria:

- [x] Recorded requests match exact method, scheme, host, path, absent query,
  headers, content type, and JSON fields from the design.
- [x] Accessible-customers has no body; search has no caller-controlled URL or
  header channel.
- [x] Malformed identifiers and page tokens fail before request construction.
- [x] Tests assert optional header/body omission as well as presence.

### TASK-004: Integrate CLI dispatch and credential resolution

**Parallelizable**: No
**Depends on**: TASK-001, TASK-002, TASK-003, shared access-token resolver.

Work:

- Replace the fixed three-word reader-command assumption with a closed route
  parser that handles both `google-ads accessible-customers list` and the
  two-word `google-ads search` without broadening accepted commands.
- Add exact per-route allowed flags and reject duplicate/unknown flags.
- Validate profile/product/scope and local command inputs, resolve the bearer
  through the shared resolver, then read the developer-token environment value.
- Reject developer-token values that are blank, exceed 4096 UTF-8 bytes, or
  contain any ASCII control before constructing headers or invoking transport.
- Pass typed inputs to the Google Ads builder and execute through the injected
  `GoogleRESTClient` transport.
- Keep auth status on the shared allowlist with no Ads-specific developer-token
  or login-customer fields, and retain the shared error-redaction policy.

Completion criteria:

- [x] Both commands dispatch end to end through a recording transport.
- [x] Missing/blank developer token, profile mismatch, scope mismatch, malformed
  flags, and invalid GAQL each produce no request and no secret output.
- [x] Environment access-token profiles still take precedence; installed OAuth
  profiles use the shared store/refresh path without Google Ads-specific token
  persistence code.
- [x] Sentinel bearer, refresh, developer, client-secret, login-customer, GAQL,
  and provider-body values are absent from stdout/stderr on every tested error.

### TASK-005: Update public documentation and evidence

**Parallelizable**: Yes, after CLI names and models are stable
**Depends on**: TASK-001 through TASK-004 contracts.

Work:

- Update help and catalog output for both commands and their exact scope.
- Add README configuration examples containing references only, setup guidance
  for environment developer tokens, optional hyphen-free login customer ID,
  GAQL file/page behavior, and explicit Google Ads API v25 pinning.
- Mark the Google Ads reader delivered in
  `impl-plans/completed/foundation-publisher-readers.md` only after implementation
  verification passes.
- Update design evidence without changing the accepted behavior contract.

Completion criteria:

- [x] Documentation names API v25, exact paths at the appropriate detail level,
  exact OAuth scope, 1 MiB GAQL limit, credential references, and non-goals.
- [x] Examples contain no real or plausible secrets and no machine-local paths.
- [x] Help, catalog, README, design, and foundation plan agree on names/versions.

### TASK-006: Run adversarial verification and close findings

**Parallelizable**: No
**Depends on**: TASK-001 through TASK-005.

Work:

- Run all commands in the Verification section.
- Review diffs separately for credential leakage, deletion/path scope,
  symlink/special-file hazards, callback/OAuth regressions introduced through
  shared types, malformed identifiers, unbounded input, arbitrary transport,
  legacy fixture compatibility, and tests that mirror implementation logic.
- Fix every high and medium finding, rerun affected narrow checks, then rerun the
  complete verification set.

Completion criteria:

- [x] Lint, test, build, smoke, diff, line-count, secret-pattern, and
  absolute-path checks pass or have an explicit environment-only exception.
- [x] No live OAuth or provider request occurred.
- [x] Independent implementation review has no open high or medium finding.
- [x] Progress and evidence are recorded without committing or pushing.

## Test matrix

| Area | Required assertions |
| --- | --- |
| Legacy config | Old environment-token fixtures decode byte-for-contract unchanged; existing AdSense/AdMob scope bundles stay valid. |
| Ads profile | Exact scope; developer-token environment reference required/safe; login ID digits only; cross-product fields/scopes rejected. |
| Secret resolution | Environment value read only at execution; missing/blank, ASCII-control-bearing, and over-4096-byte values rejected; values absent from all output. |
| GAQL loader | File type, no terminal symlink, UTF-8, empty/whitespace, exact limit, over limit, growth, and content preservation. |
| Requests | Exact v25 methods/origin/paths; JSON query/pageToken; 16,384-byte page-token boundary; absent optionals; exact required headers; no URL/header override. |
| CLI/catalog | Both command arities dispatch; every flag contract; both stable operation IDs and exact scope. |
| Error handling | Recording transport sees zero calls for local failures; provider/client sentinels and every credential sentinel are redacted. |
| Shared OAuth boundary | Environment-token precedence and installed-token fallback are integration-tested without live OAuth; status/logout remain safe. |

Tests must assert independent constants and externally observable contracts,
not reuse production URL builders, validators, maximum-size constants, or JSON
encoders in a way that could make the test repeat the same defect.

## Verification

Run from the repository root after implementation:

```bash
mise install
mise exec -- bash -lc 'export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; export SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk; export TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault; export PATH=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH; swiftlint'
swift test
swift build
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/google-ads-environment-profile.json
swift run google-marketing-gateway-reader auth login --help
swift run google-marketing-gateway-reader auth status --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/google-ads-environment-profile.json --profile ads-reader
scripts/smoke-reader-auth.sh
git diff --check
find Sources Tests -name '*.swift' -type f -print0 | xargs -0 wc -l | awk '$1 > 1000 && $2 != "total" {print}'
rg -n '(/Users/[^/]+/|/home/[^/]+/|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AIza[0-9A-Za-z_-]{20,}|ya29\.[0-9A-Za-z_-]+)' Sources Tests README.md design-docs impl-plans
git status --short
```

The checked-in validation/status fixture contains only environment-variable and
path references. The auth smoke helper must create a unique temporary directory
at runtime, create its config there, resolve logout to a uniquely named absent
token-store path contained in that directory, assert absence before and after
logout, and remove only files it created. It must fail closed if containment or
absence checks fail. Treat any non-empty line-count or secret/absolute-path scan
as a review item; reference paths explicitly required by the workflow are the
only expected machine-local-path exceptions. Capture exit codes and relevant
sanitized output. Do not run either Google Ads operation with a real transport.

## Progress log

- 2026-08-13: Implementation started: exact v25 request builders, profile and
  catalog contract, bounded GAQL regular-file read, CLI routing, and focused
  request tests were added. Validation now occurs before credential resolution;
  token-store file handling is descriptor-relative. Added invalid-ID/page-token
  and no-credential-resolution coverage; do not mark this plan complete.

- 2026-08-13: Implementation is present and pending independent review. Shared
  OAuth lifecycle revisions retain the fixed v25 origin, paths, headers, GAQL
  boundary handling, and validation-before-credential dispatch. TASK-000
  baseline reconciliation remains blocked because no pre-edit snapshot exists.

- 2026-08-13: Feature-local design accepted after self-review and adversarial
  review; implementation plan created.
- 2026-08-13: Plan self-review corrected incomplete verification by adding
  non-network config/auth smoke checks, explicit legacy-fixture coverage, and
  file-size/secret/absolute-path review commands.
- 2026-08-13: Independent plan review corrected a medium deletion-scope risk by
  replacing the checked-in logout fixture with a unique runtime-created,
  containment-checked temporary config and absent store; it also corrected a
  medium test-quality risk by requiring assertions independent of production
  constants/builders. Implementation progress is recorded above; completion
  remains pending independent review.

## Review record

### Plan self-review

Decision: accepted after correction. Design-plan mapping, dependencies,
deliverables, completion criteria, progress tracking, and verification are
explicit. The corrected plan covers every design requirement and does not claim
implementation progress.

### Independent implementation-plan review

Decision: accepted after correction. Two medium plan-only findings were found:
the proposed logout smoke could have targeted a real token store, and tests could
have mirrored production builders/constants. The verification fixture is now
replaced by a runtime-created, containment-checked temporary config/store target,
and the test matrix requires independent contract assertions. A later
independent pass confirmed the checked-in logout fixture remained a medium
deletion-scope risk; the accepted plan now requires the smoke helper to assert
target absence before and after logout and clean only its own temporary files.
No high or medium plan-only finding remains.

Design defects and plan-only defects are recorded separately in the design and
plan review records. Both artifacts are accepted; implementation is pending
independent review rather than completion.

## Implementation references

- `<mail-gateway-checkout>/Sources/MailGatewayCore/ConfigLoading.swift`
- `<mail-gateway-checkout>/Tests/MailGatewayCoreTests/ConfigLoadingTests.swift`

Use these references for relative-path resolution, validation timing, and
backwards-compatibility test ideas. Do not copy their secret-JSON environment
channels into this product.
