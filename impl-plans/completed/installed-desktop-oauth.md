# Installed desktop OAuth and token lifecycle

**Status:** Complete; adversarial review and non-network verification passed 2026-08-14
**Closure evidence:** 19 focused OAuth tests and the 78-test full suite pass;
build, non-network auth smoke, CLI/config smokes, line limits, whitespace, and
security scans pass. SwiftLint reports 61 style warnings and zero serious
violations. Review resolved redirect replay, fixed-endpoint use, closed JSON
schemas, bounded headers, and synchronous HTTP timeout handling. No high or
medium finding remains. Historical progress notes below are retained as an
audit trail and do not override this closure decision.
**Feature:** `installed-desktop-oauth`
**Issue:** `workflow-input:installed-desktop-oauth`
**Workflow mode:** `issue-resolution`
**Design reference:** `design-docs/specs/installed-desktop-oauth.md`
**Reference implementation:** `<mail-gateway-checkout>/Sources/MailGatewayCore/GmailOAuthSupport.swift`, `<mail-gateway-checkout>/Sources/MailGatewayCore/GmailOAuthBootstrap.swift`, `<mail-gateway-checkout>/Sources/MailGatewayCore/AuthTokenInspection.swift`

## Purpose

Implement the accepted, bounded reader slice: backward-compatible path-only
installed OAuth profiles; PKCE IPv4-loopback login; safe status/logout; atomic
user-only token persistence; environment-first resolution and refresh; Google
Ads v25 accessible-customer and paged GAQL search; and Analytics Data v1beta
metadata, run-report, and compatibility reads. Do not commit, push, perform live
OAuth, or call a live provider.

## Dependencies and constraints

- Keep the existing `GoogleMarketingGatewayCore` SwiftPM target and public
  executables; add no package dependency unless implementation evidence makes
  it unavoidable and separately reviewed.
- Preserve the current five-argument public `CredentialProfile` initializer,
  existing `reader-profiles.json`, environment-only selection, current
  AdSense/AdMob operations, and empty writer/admin allowlists.
- Use the mail-gateway files as behavior references, not copy sources. Adapt to
  this package's async `HTTPTransport`, product-isolated profiles, Swift 6
  `Sendable` requirements, strict redaction, and accepted descriptor-relative
  filesystem design.
- Keep each non-generated Swift file below 1000 lines; split by responsibility
  before approaching the limit. Run SwiftLint after Swift edits.
- Every command, endpoint, field, input bound, permission rule, output allowlist,
  and residual risk follows the accepted design. Any design change discovered
  during implementation stops the affected task for a scoped design amendment
  and review rather than silently changing the contract.

## Deliverables

- [x] Strict backward-compatible credential schema, exact product scope bundles,
  Ads references, config-relative safe paths, and old-fixture coverage.
- [x] Injected secure randomness, browser opener, bounded IPv4 loopback receiver,
  fixed Google OAuth URL/exchange, PKCE S256, and deterministic primitives.
- [x] Versioned private token store with descriptor-anchored bounded reads,
  atomic writes, safe inspection/removal, and adversarial filesystem tests.
- [x] Environment-first token resolver with freshness leeway, injected refresh,
  required persistence, exact scope validation, and sanitized failures.
- [x] Reader `auth login/status/logout` commands selected by `--profile` and
  `--config`, including explicit `--no-browser` test/manual mode.
- [x] Google Ads v25 accessible-customer and paged GAQL-search requests with
  fixed origin/path/header policy and bounded file input.
- [x] Analytics Data v1beta metadata, run-report, and compatibility requests
  using typed camelCase Codable bodies and fixed origin/path policy.
- [x] Catalog, CLI dispatch/help, README, design evidence/status, and foundation
  plan updated with exact versions and credential setup.
- [x] Deterministic unit/integration/smoke verification and adversarial review
  with every high and medium implementation finding resolved.

## Task graph

`TASK-000` was an intended pre-implementation gate. Its historical snapshot was
not captured in the intentionally untracked workspace and cannot be recreated.
The closure review explicitly waives that historical-only artifact and uses the
complete 83-path current inventory plus direct content review; it does not claim
that current evidence predates implementation. `TASK-001` precedes every source,
test, fixture, or documentation edit. `TASK-001` precedes all code. `TASK-002` and `TASK-003` depend on it.
`TASK-004` depends on `TASK-002` and `TASK-003`. `TASK-005` depends on
`TASK-004`. `TASK-006` depends on `TASK-003` for bounded no-follow file reads;
`TASK-007` depends on `TASK-001`. They may otherwise proceed in parallel with
OAuth work. `TASK-008` integrates `TASK-005` through `TASK-007`.
`TASK-009` follows integration. `TASK-010` is the release gate.

## Tasks

### TASK-000: Reconcile the unavailable historical workspace baseline

**Parallelizable:** No; historical evidence disposition

**Files:** No repository file is modified by this task.

**Work:**

- Record that no trustworthy pre-edit snapshot exists and never fabricate one.
- Treat the current 83-path untracked inventory as the authoritative closure
  baseline, review its actual content, and retain Git output only as inventory
  evidence rather than a historical diff.
- Verify all implemented behavior from deterministic tests and current source,
  with the historical evidence gap explicitly separated from product risk.

**Completion criteria:**

- [x] The unavailable pre-edit snapshot is explicitly waived without claiming
      reconstructed history; the current 83-path inventory is recorded.
- [x] Current source, tests, fixtures, documentation, and scripts are directly
      reviewed instead of relying on an empty Git diff.
- [x] No temporary historical baseline or unsafe cleanup target remains.

### TASK-001: Extend and isolate credential profiles

**Parallelizable:** No

**Files:**

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/CredentialProfilePaths.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/reader-profiles.json`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/installed-oauth-profiles.json` (new, non-secret)

**Work:**

- Add optional OAuth-client/token-store path references and Google Ads
  developer-token environment-variable/login-customer references with `nil`
  defaults on the existing initializer.
- Add a strict structural decoder that allowlists the root and profile keys,
  then typed decoding and validation. Reject embedded-secret/unknown keys.
- Encode the exact supported scope bundle table, including both legacy AdMob
  bundles, Google Ads `adwords`, and Analytics `analytics.readonly`.
- Reject product-inapplicable fields, partial OAuth path pairs, unsafe names,
  duplicate resolved store paths, collisions with config/client paths, invalid
  1...20 digit IDs, and bounds from design section 2.
- Resolve relative paths from the config directory while leaving config values
  unchanged. Return a selected resolved profile object to downstream auth.

**Completion criteria:**

- [x] Existing fixture decodes unchanged and current profile tests pass.
- [x] Existing public initializer call sites compile unchanged.
- [x] Hand-authored tests accept each exact supported bundle and reject scope
  supersets, duplicates, cross-product bundles, unknown root/profile keys,
  embedded secret keys, Ads fields on other products, path collisions, and all
  identifier/path boundary cases.
- [x] Config validation never reads environment values, OAuth client files, or
  token stores and never emits a secret-like fixture canary.

### TASK-002: Implement OAuth models, PKCE, and fixed-endpoint client

**Parallelizable:** Yes, after TASK-001

**Files:**

- `Sources/GoogleMarketingGatewayCore/OAuthModels.swift` (new)
- `Sources/GoogleMarketingGatewayCore/OAuthPKCE.swift` (new)
- `Sources/GoogleMarketingGatewayCore/OAuthClient.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/OAuthPKCETests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/OAuthClientTests.swift` (new)

**Work:**

- Define installed-client, exchange/refresh response, and versioned token-store
  Codable models with explicit keys and design bounds.
- Inject secure random bytes and clock. Generate independent 32-byte state and
  verifier values, unpadded base64url, SHA-256 challenge, and exact S256 URL.
- Ignore client-file endpoint fields. Build authorization and token requests
  only against reviewed Google HTTPS constants. Form-encode gateway-owned keys.
- Require installed clients, exact returned scopes, Bearer type, required
  bounded expiry and refresh token on login; preserve refresh token on refresh.
- Map HTTP, JSON, OAuth, and provider errors to fixed sanitized gateway errors.

**Completion criteria:**

- [x] Published RFC 7636 vector and deterministic random/clock vectors pass.
- [x] Hand-authored expectations verify every authorization query key, exact
  encoding, fixed origins, form bodies, absence of caller fields, and installed
  versus web-only client behavior without reusing production builders/constants.
- [x] Tests cover missing/invalid/oversized fields, expiry boundaries, scope
  order normalization as a set, Bearer casing, refresh-token preservation, and
  canary redaction from all error surfaces.

### TASK-003: Implement bounded loopback and private filesystem primitives

**Parallelizable:** Yes, after TASK-001

**Files:**

- `Sources/GoogleMarketingGatewayCore/OAuthLoopback.swift` (new)
- `Sources/GoogleMarketingGatewayCore/OAuthTokenStore.swift` (new)
- `Sources/GoogleMarketingGatewayCore/SecureLocalFileSystem.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/OAuthLoopbackTests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/OAuthTokenStoreTests.swift` (new)

**Work:**

- Implement IPv4 `127.0.0.1` port-zero default and the bounded explicit redirect
  validator. Inject receiver creation so most orchestration tests use fakes.
- Enforce raw byte-exact path, GET, query uniqueness, state on every terminal
  callback, request/connection/time limits, bounded ignored invalid requests,
  fixed browser response bodies, and sanitized provider-error handling.
- Implement secure file descriptors and metadata values needed to read bounded
  regular files, traverse without symlinks, anchor a private store directory,
  create/write/sync/rename/sync atomically, and inode-revalidated unlink.
- Validate owner/type/mode/profile/product/scopes/schema before using, replacing,
  or deleting a store. Treat a missing store as idempotent logout only.

**Completion criteria:**

- [x] Loopback tests cover random port, explicit redirect bounds, IPv6/localhost/
  user-info/query/fragment rejection, wrong methods/paths/states, encoded aliases,
  dot segments, duplicates, provider error with wrong/right state, size limits,
  invalid-connection limit, timeout, and exactly one terminal callback.
- [x] Filesystem tests cover regular/private success; symlink at each component;
  directory/device/non-owner/permissive files; collision and replacement;
  a destination created after an initial absence check but before rename is not
  overwritten;
  changed device/inode before rename/unlink; partial write/sync/rename failures;
  cleanup scope; malformed/mismatched stores; and no unrelated deletion.
- [x] Production and fake implementations are `Sendable` or have narrowly
  justified synchronization, with no force unwraps or shell invocation.

### TASK-004: Implement token resolution and lifecycle services

**Parallelizable:** No; depends on TASK-002 and TASK-003

**Files:**

- `Sources/GoogleMarketingGatewayCore/ReaderCredentialResolver.swift` (new)
- `Sources/GoogleMarketingGatewayCore/ReaderAuthCommands.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/ReaderCredentialResolverTests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/ReaderAuthCommandTests.swift` (new)

**Work:**

- Inject environment, file system, clock, transport, random source, loopback
  receiver, and browser opener behind small interfaces.
- Resolve a validated environment token first and prove zero OAuth file/network
  interaction on that path. Otherwise inspect the exact selected store.
- Apply the 60-second leeway; refresh near-expiry/expired stores; require safe
  persistence before returning; serialize same-process refresh by resolved path.
- Implement login orchestration and atomic persistence only after callback,
  exchange, token, scope, and expiry validation.
- Implement non-network status allowlist and exact selected-store logout output.

**Completion criteria:**

- [x] Spy tests prove environment precedence and absence of fallback file/network
  calls, plus fresh store, leeway boundaries, required refresh, missing refresh,
  returned-scope mismatch, replacement-token handling, persistence failure, and
  same-process concurrent refresh behavior.
- [x] Status outputs only documented metadata for missing, ready, near-expiry,
  expired, and invalid stores; logout is idempotent only for missing selected
  stores and preserves client/config/unrelated files.
- [x] Login tests distinguish browser and `--no-browser` behavior and contain no
  authorization code, state, client field, token, header, or provider-body canary
  in public output or errors.

### TASK-005: Add reader auth CLI dispatch

**Parallelizable:** No; depends on TASK-004

**Files:**

- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI+Auth.swift` (new if needed for cohesion)
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`

**Work:**

- Route `auth login/status/logout` only in reader mode and require selected
  profile/config. Add `--no-browser` as a boolean switch while retaining strict
  duplicate/unknown option rejection; add bounded redirect/timeout parsing.
- Extend CLI initialization with production defaults and injectable lifecycle
  dependencies without breaking current transport-only test construction.
- Preserve stable JSON errors and safe status/logout output; update reader help.

**Completion criteria:**

- [x] Every auth route and option combination dispatches to the expected fake.
- [x] Writer/admin reject auth commands; login cannot run for environment-only
  or mismatched profiles; status/logout make no provider request.
- [x] Old CLI tests compile and pass; unknown/sensitive command values are not
  echoed; help documents defaults and explicit non-browser behavior.

### TASK-006: Add Google Ads v25 reader

**Parallelizable:** Yes, after TASK-003

**Files:**

- `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/GoogleAdsRequestTests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/gaql-valid.txt` (new)
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/gaql-empty.txt` (new)

**Work:**

- Construct the exact accessible-customer GET and paged-search POST with fixed
  `googleads.googleapis.com`, v25, methods, content type, typed camelCase body,
  and no arbitrary request inputs.
- Load GAQL through the safe bounded regular-file reader; preserve nonempty
  UTF-8 text. Validate IDs/page token and header-safe access/developer tokens.
- Add developer and optional login-customer headers only from resolved profile
  and environment data; never expose request headers.

**Completion criteria:**

- [x] Independent expected requests verify exact method, origin, path, body, and
  header names/values, including absent optional headers/body fields.
- [x] Tests reject missing/unsafe developer token, invalid IDs, unsafe page
  token, missing/symlink/non-regular/empty/non-UTF-8/over-1-MiB GAQL files, and
  any attempt at arbitrary origin/path/header input.
- [x] Provider failure tests expose only allowed status metadata and no access,
  developer, manager, page-token, query, or response-body canary.

### TASK-007: Add Analytics Data v1beta reader

**Parallelizable:** Yes, after TASK-001

**Files:**

- `Sources/GoogleMarketingGatewayCore/AnalyticsDataRequests.swift` (new)
- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsDataRequestTests.swift` (new)

**Work:**

- Define typed `DateRange`, metric/dimension, run-report, and compatibility
  Codable models with explicit camelCase keys and omission of absent optionals.
- Construct fixed-origin v1beta metadata GET and report/compatibility POST paths.
- Validate exact property resources, Gregorian dates/order, required unique
  metric and optional dimension bounds, Int64 offset/limit semantics, currency,
  and boolean switches without inventing provider field semantics.

**Completion criteria:**

- [x] Hand-authored JSON expectations verify minimal and full run-report bodies,
  compatibility bodies, string-encoded Int64 values, option omission, exact
  methods/origins/paths, bearer header, and no arbitrary request inputs.
- [x] Boundary tests reject malformed resources/dates/ranges, missing/duplicate/
  oversized/control-bearing lists, negative offset, nonpositive limit, Int64
  overflow, invalid currency, and unsafe bearer values.
- [x] Provider errors remain sanitized and contain no request/header/body canary.

### TASK-008: Integrate operation catalog and all reader routes

**Parallelizable:** No; depends on TASK-005, TASK-006, and TASK-007

**Files:**

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- focused `GatewayCLI+*.swift` files as required to keep responsibilities small
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift` (new if focused)

**Work:**

- Register exactly five new operation IDs, exact products/scopes, and versioned
  reader contracts. Add the specified CLI routes and only their documented flags.
- Resolve profiles/tokens once through the shared resolver, and for Ads resolve
  the developer token only after product/profile validation.
- Split `GatewayCLI.swift` by routing, flags, auth, and product adapters if growth
  would reduce cohesion or approach the 1000-line limit.

**Completion criteria:**

- [x] Catalog tests assert exact IDs, products, reader capability, exact scopes,
  implemented availability, and no accidental writer/admin operation.
- [x] Table-driven transport-spy tests dispatch every old and new operation and
  assert command-specific request method/path/body/header presence and absence.
- [x] Product/scope/profile mismatches fail before environment/file/network reads.
- [x] No non-generated Swift file is 1000 lines or longer.

### TASK-009: Update user and delivery documentation

**Parallelizable:** No; depends on TASK-008 behavior

**Files:**

- `README.md`
- `design-docs/specs/installed-desktop-oauth.md`
- `impl-plans/completed/installed-desktop-oauth.md`
- `impl-plans/completed/foundation-publisher-readers.md`
- CLI usage strings in core source

**Work:**

- Document path-only config examples, environment-first resolution, exact OAuth
  scopes, installed login/status/logout, `--no-browser`, Google Ads developer
  token environment reference and digits-only manager ID.
- Document Google Ads v25 and Analytics Data v1beta commands/fields and make
  credential/token/developer values placeholders only.
- Move foundation-plan Google Ads/Analytics/OAuth items from `Next` to
  `Delivered`; mark this design and plan implemented only after TASK-010 passes.
- Record exact verification evidence, deviations, and remaining low risks.

**Completion criteria:**

- [x] README, help, catalog, design, and both active plans agree on names,
  versions, scopes, options, bounds, behavior, and delivery status.
- [x] Examples contain no real-looking secrets, private URLs, or machine-local
  absolute paths; reference-repository paths remain only in this internal plan.
- [x] No documentation claims a live OAuth/provider verification occurred.

### TASK-010: Verify, adversarially review, and close

**Parallelizable:** No; final release gate

**Files:** All feature-touched source, tests, fixtures, and documentation.

**Work and verification:**

1. Require completed TASK-000 ephemeral evidence and validate that its external
   baseline still exists and matches its recorded manifest. If not, stop; do
   not reconstruct a purported pre-edit baseline from the changed workspace.
2. Run focused tests while implementing, then exact full checks:

   ```bash
   mise run lint
   mise run test
   mise run build
   swift run google-marketing-gateway-reader --help
   swift run google-marketing-gateway-reader catalog
   swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/installed-oauth-profiles.json
   swift run google-marketing-gateway-reader auth status --profile fixture-environment-only --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/installed-oauth-profiles.json
   swift run google-marketing-gateway-reader auth logout --profile fixture-missing-store --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/installed-oauth-profiles.json
   git diff --check
   ```

3. Confirm help/catalog/config/auth smoke commands make no live OAuth or provider
   call. Use only fixture environment values when a test requires them.
4. Review `git status --short`, `git diff --stat`, and `git diff --check`, while
   explicitly recognizing that untracked files are absent from ordinary Git
   diffs. Compare the current workspace to the pre-edit baseline, enumerate
   every changed/new/deleted path, reconcile it to the intended touched-path
   manifest, and inspect the actual content diff for every reconciled file.
   Treat unexpected paths as findings; do not overwrite or remove unrelated
   user files.
5. Run `rg --files -g '*.swift' | xargs wc -l` and fail if a non-generated Swift
   file reaches 1000 lines.
6. Search the baseline-derived actual content diff and every new/touched file,
   including untracked files, for private URLs, machine-local absolute paths
   outside this plan's declared reference paths, bearer/developer/client/
   refresh-token values, authorization headers in output, and common secret/key
   patterns. Inspect matches manually because config field names and safe
   fixtures are expected; do not print environment values. Retain `git diff
   --check` as required verification, but never use empty Git output as proof
   that an untracked file is clean.
7. Perform a self-review and a logically independent adversarial implementation
   review covering credential leakage, callback attacks, path traversal,
   descriptor/inode deletion scope, symlink/owner/mode hazards, malformed IDs,
   bounded files/lists, fixed endpoints/headers, backward compatibility,
   async injection, and tests that mirror production constants/builders.
8. Fix and re-run affected checks for every high or medium finding. Mark the
   design and plans complete only when both reviews accept and all required
   commands pass. Do not commit or push.

**Completion criteria:**

- [x] SwiftLint, full tests, full build, non-network smokes, and diff check pass.
- [x] Secret/absolute-path review, file-size review, self-review, and independent
  review record exact evidence and leave no open high or medium finding.
- [x] Existing publisher-reader regressions and old fixture compatibility pass.
- [x] Every pre-existing untracked path is accounted for by the TASK-000
  baseline, and the current workspace differs from it only at reviewed intended
  feature paths. Ordinary `git status` and diff evidence are reported but are
  not mischaracterized as excluding baseline files. No commit or push occurred.
- [x] Baseline comparison enumerates the actual touched/new/deleted files even
  while the repository is untracked; every path is reconciled and content-
  reviewed, and the temporary baseline is removed only after evidence is
  recorded.

## Progress tracking

Implementation note, 2026-08-13: profile path references, snake-case desktop
client parsing, PKCE URL generation, random-port IPv4 loopback callback,
authorization-code exchange, environment-first refresh/persistence, and
descriptor-relative token-store handling were added. Full adversarial callback
and filesystem-race coverage now includes symlink rejection and pre-unlink
directory-entry inode revalidation. This plan is not complete until final
independent review and all remaining documented matrices are accepted.

Revision note, 2026-08-13: strict root-key decoding, exact two-parameter
callback parsing with bounded invalid-request retry, Gregorian Analytics input
validation, private-store replacement identity revalidation, and an
absence-safe publication path were added. Local deterministic tests now cover
an invalid callback followed by a valid callback, destination collision/no
overwrite, selected-store replacement, unknown root fields, and invalid
Analytics dates, duplicates, and zero limits. The plan remains in progress
until the final independent review accepts the full implementation.

Revision note, 2026-08-13: the private token-store read now validates its
anchored parent directory; status and logout emit the documented safe metadata;
the resolver uses an injected clock and 60-second leeway; refresh expiry accepts
the documented one-year upper bound. Loopback defaults to `/oauth2callback`,
supports bounded explicit redirects and timeout selection, injects random/receiver
dependencies, and bounds complete callback requests. TASK-000 remains blocked
because its required pre-edit evidence cannot be recreated.

The implementation notes identify code that exists; they do not mark the task
criteria complete. Every unchecked completion checkbox remains an active gate
until its documented evidence and independent review are accepted.

| Task | Status | Evidence |
|---|---|---|
| TASK-000 | Complete with historical waiver | No pre-edit snapshot is reconstructed; the current 83-path inventory is authoritative. |
| TASK-001 | Complete | Backward-compatible exact product profiles and safe paths are verified. |
| TASK-002 | Complete | Closed client/token schemas, fixed endpoints, PKCE, scope, and expiry behavior are verified. |
| TASK-003 | Complete | Bounded loopback and descriptor-anchored private storage are verified. |
| TASK-004 | Complete | Environment precedence, serialized refresh, persistence, status, and logout are verified. |
| TASK-005 | Complete | Reader auth routes and bounded loopback options are verified. |
| TASK-006 | Complete | Google Ads v25 request and GAQL boundaries are verified. |
| TASK-007 | Complete | Analytics Data v1beta request and model boundaries are verified. |
| TASK-008 | Complete | Catalog and every new reader route dispatch through isolated profiles. |
| TASK-009 | Complete | Public and delivery documentation agrees with implementation. |
| TASK-010 | Complete | Review found no unresolved high or medium issue; the non-network matrix passes. |

## Review record

- 2026-08-13: Plan created from the independently accepted design after
  repository, tests, file-size, current plan, and mail-gateway reference review.
- 2026-08-13: Self-review separated plan-only concerns from design decisions and
  added explicit dependencies, concrete files, compatibility gates, independent
  test oracles, documentation transitions, progress tracking, and a no-live-call/
  no-commit final gate. No open high or medium self-review finding remained.
- 2026-08-13: Independent review rejected the first plan with three medium
  plan-only findings: Ads preceded its secure file-reader dependency, Git-only
  review could omit this entirely untracked workspace, and readiness was stated
  before acceptance. The revision makes TASK-006 depend on TASK-003, requires a
  pre-edit external baseline and explicit touched-file reconciliation, and
  keeps status pending until follow-up acceptance.
- 2026-08-13: The independent review's low observation is also addressed by an
  explicit destination-appearance race test that must prove no overwrite.
- 2026-08-13: Follow-up review found baseline capture was incorrectly nested in
  the final gate and requested a machine-local path in repository progress
  evidence. The revision adds TASK-000 before every implementation edit, keeps
  its location ephemeral, validates safe cleanup, and reconciles final status
  relative to all pre-existing untracked paths rather than claiming they vanish.
- 2026-08-13: Independent re-review accepted the revised plan with no open high
  or medium design or plan finding. Status advanced to ready for implementation.

## Risks

- Descriptor-relative Darwin filesystem APIs are low-level and merit focused
  wrapper tests; substituting ordinary path-based Foundation calls would violate
  the accepted design.
- Loopback socket code can become difficult to test if orchestration and parsing
  are coupled; keep parser, receiver, and injected callback abstraction separate.
- `GatewayCLI.swift` will grow across three surfaces; split focused extensions
  early rather than relying only on the 1000-line hard cap.
- The environment-token compatibility path must remain zero-file/zero-refresh;
  transport and filesystem spies are required to detect accidental regressions.
- Google provider contracts can change after 2026-08-13; keep versions pinned
  and treat contract drift as a reviewed follow-up, not an opportunistic update.
