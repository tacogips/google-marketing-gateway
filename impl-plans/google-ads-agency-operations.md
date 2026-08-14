# Google Ads Agency Account Operations Implementation Plan

**Status**: Partially implemented
**Workflow mode**: `issue-resolution`
**Feature ID**: `ads-agency-core`
**Issue**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Design Reference**: `design-docs/google-ads-agency-operations.md`
**Codex Agent References**: none

## Purpose

Implement the feature-local Google Ads agency-account foundation from the
accepted design. The slice must materially improve manager/client account
operations without performing live billable Google actions or weakening the
current capability-separated reader, writer, and admin boundaries.

## Source Decisions

- Google Ads v25 remains the first implemented agency surface.
- `https://www.googleapis.com/auth/adwords` remains the Google Ads OAuth scope;
  gateway mode, profile validation, operation descriptors, and allowlists
  enforce least privilege.
- Reader work is implemented first: accessible customers, generated hierarchy
  reads, customer access reads, and deterministic tests.
- Writer/admin profile and mutation support are planned as safe foundations
  only; mutation allowlists stay empty until a separately reviewed operation is
  enabled.
- Broad Google marketing product inventory is represented honestly as planned,
  blocked, restricted, beta, deprecated, or excluded catalog rows, not as
  dispatchable implementation.

## Deliverables

- [x] Extend `OperationDescriptor` in
  `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` with descriptor
  metadata for official API family, version, stability, origin,
  provider method, request kind, spend risk, request body policy, response
  policy, and test requirements.
- [x] Preserve existing implemented catalog output compatibility or add a
  clearly versioned catalog command when compatibility cannot be preserved.
- [x] Add Google Ads agency reader descriptors for
  `google-ads.customer-client-links.list`,
  `google-ads.customer-clients.list`, and
  `google-ads.customer-users.list`.
- [x] Add generated GAQL request builders in
  `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift` for the
  hierarchy and access reads.
- [x] Add reader CLI routes in
  `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift` for the agency read
  operations with validated `--customer-id`, optional `--page-token`, and
  existing profile/config selection.
- [ ] Add writer/admin profile schema decisions and validation behavior in
  `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift` without
  enabling any mutates.
- [ ] Add a Google Ads mutation plan model with empty writer/admin allowlists by
  default and explicit failure behavior in writer/admin binaries.
- [x] Expand product inventory in the catalog for GMP, Ad Manager, Merchant
  Center, Analytics Admin/Data, Tag Manager, YouTube Data/Analytics, Search
  Console, AdSense, AdMob, Ads Data Hub, Authorized Buyers/RTB, Business
  Profile, Local Services Ads, and Google Trends disposition.
- [x] Add deterministic tests under
  `Tests/GoogleMarketingGatewayCoreTests/` for catalog metadata, request
  builders, CLI routing, profile validation, mode isolation, and redaction.
- [x] Document that no live billable Google action was performed.

## Task Breakdown

### TASK-001: Descriptor Metadata Foundation

**Parallelizable**: No

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`

**Work**:

- Add typed enums or constrained string fields for descriptor metadata.
- Keep `OperationCatalog.operation(id:)` dispatch limited to implemented
  operations only.
- Decide whether the existing `catalog` JSON shape can remain backward
  compatible. If not, add a versioned catalog output and test both behavior and
  help text.

**Completion Criteria**:

- [x] Existing implemented operations still encode and dispatch.
- [x] Planned inventory rows cannot be returned by `operation(id:)`.
- [x] Tests prove no descriptor uses wildcard or caller-selected origins.

### TASK-002: Google Ads Agency Read Descriptors

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`

**Work**:

- Add implemented descriptors for:
  `google-ads.customer-client-links.list`,
  `google-ads.customer-clients.list`, and
  `google-ads.customer-users.list`.
- Mark all three as reader, Google Ads v25, GA, fixed
  `https://googleads.googleapis.com`, request kind `read`, spend risk `none`,
  request body policy `providerGeneratedOnly` or equivalent, and OAuth scope
  `https://www.googleapis.com/auth/adwords`.

**Completion Criteria**:

- [x] Catalog output exposes all three operation ids with exact metadata.
- [x] Reader descriptors have no writer/admin spend-risk metadata.
- [x] Existing Google Ads reader descriptors remain unchanged in capability.

### TASK-003: Generated GAQL Builders

**Parallelizable**: After TASK-002

**Files**:

- `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/NewReaderRequestTests.swift`

**Work**:

- Add fixed query builders for `customer_client_link`,
  `customer_client`, and customer user access data.
- Reuse existing Google Ads search request construction, fixed origin,
  developer-token header handling, optional `login-customer-id`, customer ID
  validation, page-token validation, and sanitized errors.
- Keep generated queries internal to the route; do not accept arbitrary GAQL
  for these operations.

**Completion Criteria**:

- [x] Tests assert exact method, URL path, headers, and JSON body shape.
- [x] Tests cover invalid customer IDs and invalid page tokens before
  credential resolution.
- [x] Tests prove developer token and access token values are not printed in
  failures.

### TASK-004: Reader CLI Routes

**Parallelizable**: After TASK-003

**Files**:

- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/NewReaderCLITests.swift`

**Work**:

- Add reader commands:
  `google-ads customer-client-links list --customer-id <digits>`,
  `google-ads customer-clients list --customer-id <digits>`, and
  `google-ads customer-users list --customer-id <digits>`.
- Accept optional `--page-token <token>` consistently with
  `google-ads search`.
- Ensure writer/admin binaries continue to report empty mutation allowlists
  rather than dispatching these routes unless catalog and mode policy explicitly
  allow read passthrough.

**Completion Criteria**:

- [x] CLI tests prove each command resolves the correct operation id.
- [x] CLI tests prove route/input validation precedes credential resolution.
- [x] Mode-isolation tests prove reader routes do not become generic
  writer/admin mutate entry points.

### TASK-005: Writer/Admin Profile Foundation

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`

**Work**:

- Choose and implement the first writer/admin profile schema shape as either a
  versioned extension of the existing profile config or a separate profile
  type.
- Reject cross-product scope bundles.
- Reject using Google Ads `adwords` credentials for non-Google-Ads products.
- Keep reader profile validation strict and backward compatible.

**Completion Criteria**:

- [ ] Reader-only configs continue to validate.
- [ ] Writer/admin configs are either explicitly valid by mode or rejected with
  clear sanitized errors.
- [ ] Tests prove no secret values or token environment-variable contents are
  printed.

### TASK-006: Empty Mutation Plan and Allowlists

**Parallelizable**: After TASK-001 and TASK-005

**Files**:

- `Sources/GoogleMarketingGatewayCore/GatewayModels.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`

**Work**:

- Add a bounded mutation plan representation for future Google Ads operations.
- Keep writer/admin allowlists empty by default.
- Return explicit reviewed-allowlist errors for writer/admin operation attempts.
- Do not add campaign creation, budget changes, account access changes, billing
  changes, conversion uploads, or any live mutate execution.

**Completion Criteria**:

- [ ] Writer/admin binaries still cannot perform mutates.
- [ ] Tests prove unimplemented/planned/admin operations cannot be invoked by a
  generic operation id.
- [ ] Error messages include operation policy context but no request body or
  credential material.

### TASK-007: Planned Product Inventory

**Parallelizable**: After TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`
- `design-docs/google-ads-agency-operations.md`

**Work**:

- Add planned, blocked, beta, restricted, deprecated, or excluded catalog rows
  for the products listed in the design matrix.
- Include fixed official origins and exact scopes only where known and needed
  for planning.
- Represent Google Trends as official alpha/allowlist only; do not add scraping
  or unofficial endpoints.

**Completion Criteria**:

- [x] Catalog distinguishes implemented rows from planned inventory.
- [x] Dispatch remains blocked for all non-implemented product inventory.
- [x] Tests cover availability labels for restricted, beta, allowlisted,
  deprecated, and excluded surfaces.

### TASK-008: Documentation and Verification Pass

**Parallelizable**: After TASK-002 through TASK-007

**Files**:

- `README.md`
- `design-docs/google-ads-agency-operations.md`
- `impl-plans/google-ads-agency-operations.md`

**Work**:

- Update user-facing documentation only where needed for new commands and
  catalog behavior.
- Record progress in this plan.
- Run lint, tests, and build.
- State explicitly that no live billable Google action was performed.

**Completion Criteria**:

- [x] Verification commands pass or failures are documented with follow-up
  tasks.
- [x] Documentation does not claim every official Google marketing method is
  implemented.
- [x] Progress log reflects completed implementation slices.

## Dependencies

- TASK-001 blocks all catalog-driven work.
- TASK-002 depends on TASK-001.
- TASK-003 depends on TASK-002.
- TASK-004 depends on TASK-003.
- TASK-005 depends on TASK-001.
- TASK-006 depends on TASK-001 and TASK-005.
- TASK-007 depends on TASK-001 and can run alongside TASK-003 through TASK-006.
- TASK-008 depends on all implementation tasks.

## Parallelizable Work

- After TASK-001, TASK-002, TASK-005, and TASK-007 can proceed independently.
- After TASK-002, TASK-003 can proceed while TASK-005 and TASK-007 continue.
- After TASK-003, TASK-004 can proceed while TASK-006 is being prepared.
- Documentation updates in TASK-008 should wait until command names and catalog
  output are stable.

## Verification

Required commands:

```bash
mise run lint
mise run test
mise run build
swift test --filter OperationCatalogTests
swift test --filter NewReaderRequestTests
swift test --filter GatewayCLITests
swift test --filter CredentialProfileTests
git diff --stat
git diff -- design-docs/google-ads-agency-operations.md impl-plans/google-ads-agency-operations.md Sources/GoogleMarketingGatewayCore/OperationCatalog.swift Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift Sources/GoogleMarketingGatewayCore/GatewayCLI.swift Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift Tests/GoogleMarketingGatewayCoreTests
git status --short
```

Non-goals for verification:

- No live billable Google actions.
- No campaign creation.
- No budget changes.
- No account access changes.
- No unofficial scraping endpoint checks.

## Addressed Review Feedback

- The accepted design review found no high or mid issues, so this plan sets no
  revision gate.
- The low finding about high-level mutation enablement is addressed by TASK-005
  and TASK-006, which require a writer/admin profile schema decision and empty
  mutation allowlists before any mutate implementation.
- The low out-of-scope finding about unrelated untracked design docs is
  addressed by limiting this plan to
  `impl-plans/google-ads-agency-operations.md` and the feature id
  `ads-agency-core`.

## Completion Criteria

- [x] `impl-plans/google-ads-agency-operations.md` exists and tracks the
  feature-local implementation work.
- [x] Google Ads hierarchy/access reads have descriptors, generated request
  builders, reader CLI routes, and deterministic tests.
- [x] Reader mode cannot invoke writer/admin descriptors.
- [ ] Writer/admin profile behavior is explicit and tested.
- [ ] Mutation allowlists remain empty unless a later reviewed operation
  explicitly enables one.
- [x] Catalog inventory honestly separates implemented, planned, beta,
  allowlisted, deprecated, restricted, and excluded surfaces.
- [x] `mise run lint`, `mise run test`, and `mise run build` have been run.
- [x] No live billable Google action was performed.

## Risks

| Risk | Mitigation |
|---|---|
| Google Ads has one OAuth scope for read and mutate. | Enforce gateway least privilege through mode, profile, catalog, allowlists, and tests. |
| Catalog expansion overstates implementation. | Keep planned rows non-dispatchable and test `OperationCatalog.operation(id:)`. |
| Generated hierarchy reads accidentally become arbitrary GAQL passthrough. | Use fixed query builders and reject caller-provided GAQL for these routes. |
| Writer/admin profile schema breaks reader configs. | Add backward-compatible reader tests before enabling writer/admin validation. |
| Future mutates can affect spend or serving. | Keep allowlists empty in this slice and require plan/apply plus explicit spend-risk policy before any paid action. |
| Unrelated untracked docs enter this branch. | Limit this branch to `ads-agency-core` and avoid reviewing or modifying unrelated design docs. |

## Progress Log

- 2026-08-14: Plan created from accepted design review for feature id
  `ads-agency-core`.
- 2026-08-14: Implemented Google Ads agency reader descriptors, fixed GAQL
  request builders, reader CLI routes, catalog metadata/inventory separation,
  non-callable planned product inventory, and deterministic tests. Writer/admin
  profile schema and mutation plan model remain deferred; writer/admin binaries
  still reject all operations through the empty reviewed allowlist.
- 2026-08-14: Ran `swift test --filter OperationCatalogTests`,
  `swift test --filter NewReaderRequestTests`,
  `swift test --filter NewReaderCLITests`,
  `swift test --filter GatewayCLITests`,
  `swift test --filter CredentialProfileTests`, `mise run lint`,
  `mise run test`, and `mise run build`. No live Google or billable action was
  performed.
