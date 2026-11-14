# Gateway Safety, CLI Routing, and Verification Implementation Plan

**Status**: Partially implemented
**Workflow mode**: `issue-resolution`
**Feature ID**: `gateway-safety-cli`
**Issue**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Design Reference**: `design-docs/gateway-safety-cli-foundation.md`
**Codex Agent References**: none

## Purpose

Implement the shared gateway safety foundation from the accepted design. This
slice should materially improve extensibility for official Google advertising
and adjacent agency APIs without claiming unimplemented resource coverage,
without exposing arbitrary HTTP, and without enabling billable or durable writer
and admin actions.

## Source Decisions

- Keep `google-marketing-gateway-reader`,
  `google-marketing-gateway-writer`, and
  `google-marketing-gateway-admin` capability-separated.
- Pin all request construction to fixed official Google origins from operation
  descriptors or typed request builders.
- Prefer typed request builders; permit generic REST construction only through
  implemented descriptors with fixed method, origin, path template, declared
  parameters, exact capability, exact scopes, and bounded body policy.
- Keep planned, beta, restricted, deprecated, allowlisted, and non-public
  catalog rows visible as inventory but non-callable.
- Validate path, query, and request-file inputs before resolving credentials.
- Keep writer/admin operation allowlists empty unless the implementation adds
  plan/apply semantics, confirmation policy, idempotency handling, sanitized
  receipts, and non-billable verification.
- Do not perform live billable Google actions.

## Deliverables

- [x] Expand `MarketingProduct` and `OperationDescriptor` in
  `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` with tested
  catalog metadata for API family, version, stability, origin, provider method,
  request kind, spend risk, availability, request body policy, response policy,
  and verification.
- [x] Split implemented operation dispatch from full inventory export so
  `OperationCatalog.operation(id:)` returns only callable `implemented`
  operations.
- [x] Add catalog-only planned inventory rows for the accepted agency-operation
  product surface without making those rows runnable commands.
- [ ] Add a descriptor-bounded REST request construction abstraction for future
  official REST APIs that rejects caller-supplied origins, absolute URLs,
  headers, authorization, scopes, API versions, and HTTP methods.
- [ ] Generalize Search Console request-file validation into reusable bounded
  JSON and text helpers in
  `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift` or a nearby core
  file.
- [ ] Add sanitized provider-error fixtures and tests that include tokens,
  developer tokens, cookies, client secrets, emails, authorization headers, and
  request-body snippets.
- [x] Add CLI routing rejection tests proving reader, writer, and admin binaries
  reject unknown, planned, unavailable, and capability-mismatched operations
  before credential resolution.
- [x] Preserve existing reader behavior for Google Ads, GA4 Data, Search
  Console, AdSense, and AdMob.
- [x] Document zero-cost verification and any intentionally deferred
  writer/admin enablement.

## Task Breakdown

### TASK-001: Descriptor Metadata Foundation

**Parallelizable**: No

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayModels.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`

**Work**:

- Add constrained enums or validated fields for `apiFamily`, `apiVersion`,
  `stability`, `origin`, `providerMethod`, `requestKind`, `spendRisk`,
  `availability`, `requestBodyPolicy`, `responsePolicy`, and `verification`.
- Add missing `MarketingProduct` cases needed for the issue inventory while
  preserving existing product semantics.
- Keep existing implemented reader descriptors dispatchable.
- Add tests that reject wildcard origins, empty origins, caller-derived origins,
  missing availability, and invalid capability metadata.

**Completion Criteria**:

- [x] Existing implemented reader operation ids still resolve.
- [x] Descriptor metadata serializes in catalog output.
- [x] Invalid descriptor fixtures fail deterministically in tests.
- [x] No catalog row can represent an arbitrary or wildcard origin.

### TASK-002: Inventory Versus Dispatch Boundary

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`

**Work**:

- Add a full inventory accessor or export path that may include planned,
  blocked, beta, restricted, deprecated, and excluded rows.
- Keep `OperationCatalog.operation(id:)` or equivalent dispatch lookup filtered
  to `availability == implemented`.
- Add catalog-only rows for Google Ads, DV360, CM360, SA360, Ad Manager REST and
  SOAP, Merchant Center, Analytics Admin/Data, Tag Manager, YouTube
  Data/Analytics, Search Console, AdSense, AdMob, Ads Data Hub, Authorized
  Buyers Marketplace, Real-time Bidding, Business Profile, Local Services Ads,
  and Google Trends disposition.
- Ensure catalog-only rows do not appear in runnable command help as implemented
  routes unless explicitly labeled as inventory.

**Completion Criteria**:

- [x] Planned rows are visible in inventory export.
- [x] Planned rows are not returned by callable operation lookup.
- [x] CLI dispatch rejects planned, blocked, restricted, deprecated, non-public,
  and excluded rows before credential resolution.
- [x] Tests cover at least one non-callable inventory row per major product
  group.

### TASK-003: Descriptor-Bounded REST Construction

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayModels.swift`
- `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift`
- New or existing request-construction file under
  `Sources/GoogleMarketingGatewayCore/`
- `Tests/GoogleMarketingGatewayCoreTests/`

**Work**:

- Introduce a small request builder that accepts an implemented descriptor plus
  declared path/query/body inputs.
- Build URLs only from descriptor origin and fixed path templates.
- Validate product-specific path components before URL encoding.
- Reject absolute URLs, relative path traversal, caller-supplied methods,
  caller-supplied headers, authorization headers, custom scopes, and API
  versions.
- Do not route generic REST through CLI until at least one implemented
  descriptor has complete tests.

**Completion Criteria**:

- [ ] Request construction cannot change origin, method, version, scope, or
  authorization.
- [ ] Path and query inputs are validated before credentials are requested.
- [ ] Tests prove malformed and hostile inputs fail without network access.
- [ ] Existing typed request builders continue to pass tests unchanged.

### TASK-004: Reusable Request-File Safety

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestFileTests.swift`
- New request-file tests under `Tests/GoogleMarketingGatewayCoreTests/`

**Work**:

- Extract Search Console secure local-file checks into reusable bounded JSON and
  text body helpers.
- Reject symlinks, non-regular files, group/world-readable files, oversize
  files, replaced files, malformed JSON, excessive nesting, and schema-invalid
  bodies.
- Keep validation before credential resolution and before transport creation.
- Preserve Search Console request-file behavior.

**Completion Criteria**:

- [ ] Existing Search Console request-file tests pass.
- [ ] Shared helper tests cover unsafe file modes, symlinks, malformed JSON,
  depth limits, size limits, and schema failures.
- [ ] CLI tests prove request-file failures do not load credentials.

### TASK-005: Sanitized Error Fixtures

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleCLITests.swift`
- New sanitizer tests under `Tests/GoogleMarketingGatewayCoreTests/`

**Work**:

- Add provider-error fixtures containing access tokens, refresh tokens,
  developer tokens, cookies, client secrets, emails, authorization headers, raw
  request bodies, and provider body snippets.
- Preserve safe diagnostics such as status, reason, request id, operation id,
  and field path.
- Ensure CLI and transport outputs never include secret values or raw private
  request content.

**Completion Criteria**:

- [ ] Sanitizer tests fail if known secret markers appear in output.
- [ ] Safe status, reason, request id, operation id, and field path remain
  available where present.
- [ ] Existing sanitized error behavior remains compatible.

### TASK-006: Capability Routing Gates

**Parallelizable**: After TASK-002

**Files**:

- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfilesTests.swift`

**Work**:

- Keep reader dispatch limited to logical reads and reports.
- Keep writer/admin mutation allowlists empty unless a separately reviewed
  implementation adds the required safety semantics.
- Add tests proving writer/admin reject unavailable operations and reader
  rejects mutates, uploads, access changes, billing, publish, delete, admin, and
  planned operations before credential resolution.
- Preserve Google Ads least-privilege handling where the broad `adwords` scope
  is constrained by binary mode, profile capability, descriptor capability, and
  operation id.

**Completion Criteria**:

- [x] Reader, writer, and admin binaries enforce capability gates.
- [x] Rejections happen before credentials are resolved.
- [x] Writer/admin remain non-billable and non-mutating in this slice.

### TASK-007: Verification and Documentation

**Parallelizable**: After TASK-001 through TASK-006

**Files**:

- `design-docs/gateway-safety-cli-foundation.md`
- `impl-plans/gateway-safety-cli-foundation.md`
- Any touched tests and source files

**Work**:

- Update docs only if implementation decisions materially differ from the
  accepted design.
- Run formatting, lint, tests, and build.
- Record that no billable Google actions were performed.

**Completion Criteria**:

- [x] `mise run lint` passes.
- [x] `mise run test` passes.
- [x] `mise run build` passes.
- [x] New-plan diff is available with
  `git diff --no-index -- /dev/null impl-plans/gateway-safety-cli-foundation.md`
  while the file is untracked.

## Dependencies

- `TASK-001` must land before catalog inventory, generic request construction,
  request-file policy wiring, and routing gates.
- `TASK-002` depends on descriptor availability metadata from `TASK-001`.
- `TASK-003` depends on descriptor origin, method, path, capability, scope, and
  body-policy metadata from `TASK-001`.
- `TASK-004` can proceed after metadata policy names are settled in `TASK-001`.
- `TASK-005` can proceed after existing transport and CLI error boundaries are
  inspected.
- `TASK-006` depends on callable versus inventory separation from `TASK-002`.
- Product-local implementation plans for Google Ads, GMP, publisher/commerce,
  and future Analytics/Tag Manager/YouTube/Business Profile slices should use
  this foundation instead of weakening it.

## Parallelizable Tasks

- After `TASK-001`, `TASK-003`, `TASK-004`, and `TASK-005` can proceed in
  parallel.
- After `TASK-002`, `TASK-006` can proceed in parallel with remaining sanitizer
  and request-file tests.
- `TASK-007` is final verification and should run after source edits are
  complete.

## Progress Tracking

- [x] `TASK-001`: Descriptor Metadata Foundation
- [x] `TASK-002`: Inventory Versus Dispatch Boundary
- [ ] `TASK-003`: Descriptor-Bounded REST Construction
- [ ] `TASK-004`: Reusable Request-File Safety
- [ ] `TASK-005`: Sanitized Error Fixtures
- [x] `TASK-006`: Capability Routing Gates
- [x] `TASK-007`: Verification and Documentation

## Verification

Plan-file verification:

```bash
test -f impl-plans/gateway-safety-cli-foundation.md
sed -n '1,260p' impl-plans/gateway-safety-cli-foundation.md
git diff --no-index -- /dev/null impl-plans/gateway-safety-cli-foundation.md
```

Implementation verification after Swift edits:

```bash
mise run lint
mise run test
mise run build
```

Non-billable verification rule:

- Do not perform live billable Google actions.
- Prefer local deterministic tests and zero-cost read-only/API enablement checks.
- Any later paid live verification must use `me@tacogips.me`, keep each paid
  action `<= USD 5`, keep total spend `< USD 50`, and never create campaigns or
  spend without explicit verification need and hard budget approval.

## Completion Criteria

- [x] Catalog metadata supports honest API family, version, stability,
  availability, origin, method, capability, scope, body, response, spend-risk,
  and verification reporting.
- [x] Full inventory export is separate from callable operation lookup.
- [x] Planned and unavailable rows are visible but non-dispatchable.
- [ ] Descriptor-bounded REST cannot become an arbitrary HTTP proxy.
- [ ] Reusable request-file helpers reject unsafe files and invalid bodies before
  credentials are resolved.
- [ ] Sanitized errors redact secrets and private body content while preserving
  safe diagnostics.
- [x] Reader/writer/admin binaries reject capability mismatches and unavailable
  operations before credential resolution.
- [x] Existing reader operations continue to pass tests.
- [x] `mise run lint`, `mise run test`, and `mise run build` pass.

## Addressed Review Feedback

- Created the declared implementation plan at
  `impl-plans/gateway-safety-cli-foundation.md`.
- Treated open questions from the design as implementation decisions and risks,
  not blockers.
- Preserved scope to the declared feature and did not modify unrelated
  untracked files under `design-docs/` or `impl-plans/`.
- Included `git diff --no-index -- /dev/null
  impl-plans/gateway-safety-cli-foundation.md` for useful new-file diff
  verification while the plan is untracked.
- Implemented descriptor metadata, implemented-only dispatch lookup,
  catalog-only product inventory, capability route rejection coverage, and
  explicit empty writer/admin allowlist behavior without live Google actions.
- Deferred generic descriptor-bounded REST dispatch, reusable request-file
  extraction, and expanded sanitizer fixtures as remaining foundation work.
- Ran `mise run lint`, `mise run test`, `mise run build`, and focused Swift
  test filters for catalog, request, CLI, and credential-profile coverage.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Planned catalog rows become callable. | False coverage claims and unsafe dispatch. | Keep dispatch lookup filtered to `implemented`; add rejection tests for every unavailable availability class. |
| Descriptor-bounded REST expands into arbitrary HTTP. | Unofficial endpoint use, scope abuse, or data leakage. | Build only from fixed descriptors and reject caller-supplied origins, URLs, headers, methods, scopes, and versions. |
| Request-file validation diverges by product. | Inconsistent safety and credential-loading order. | Centralize bounded JSON/text helpers and reuse Search Console adversarial tests. |
| Sanitization removes useful diagnostics. | Harder debugging. | Preserve status, reason, request id, operation id, and field path while redacting secrets and body snippets. |
| Writer/admin enablement happens prematurely. | Durable account changes or spend risk. | Keep writer/admin allowlists empty unless plan/apply, confirmation, idempotency, receipts, and non-billable verification are implemented and tested. |
| Official API versions or access status change before implementation. | Stale inventory metadata. | Recheck official docs on implementation date and keep version, stability, and availability explicit in descriptors. |
