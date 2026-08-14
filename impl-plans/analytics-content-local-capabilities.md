# Analytics, Content, and Local Operations Implementation Plan

**Status**: Planned
**Workflow mode**: `issue-resolution`
**Feature ID**: `analytics-content-local`
**Issue reference**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Design reference**: `design-docs/analytics-content-local-capabilities.md`
**Codex agent references**: none

## Purpose

Implement the feature-local foundation for Analytics Admin/Data, Tag Manager,
YouTube Data/Analytics, Search Console, Ads Data Hub, Business Profile, and
Local Services Ads coverage from the accepted design. The slice must improve
official API inventory, OAuth profile isolation, descriptor metadata, bounded
request construction, reader routing, and tests without claiming complete
method-level support or performing live billable Google actions.

## Deliverables

- [ ] Add product identifiers where missing for `ads-data-hub`,
  `business-profile`, and `local-services-ads`; preserve existing
  `analytics-admin`, `analytics-data`, `tag-manager`, `youtube-data`,
  `youtube-analytics`, and `search-console` keys.
- [ ] Extend operation descriptors with API family, version or stability,
  official origin, provider method, capability, OAuth scopes, availability,
  spend or billable API risk, request body policy, pagination/materialization
  policy, and required tests.
- [ ] Expand product-isolated reader OAuth profile validation while keeping
  exact existing reader checks for Analytics Data and Search Console.
- [ ] Add first reader request builders for Analytics Admin and Tag Manager,
  with typed identifiers, fixed official origins, bounded request inputs, and
  sanitized provider errors.
- [ ] Add planned inventory descriptors for YouTube Data/Analytics, Ads Data
  Hub, Business Profile, Local Services Ads, and Search Console expansion
  without making planned operations dispatchable.
- [ ] Add reader CLI/catalog routing only for implemented reader operations;
  writer/admin operations stay disabled until separate plan/apply policies,
  idempotency, confirmation, and budget controls exist.
- [ ] Add deterministic tests for catalog metadata, profile rejection, request
  construction, CLI routing, request-file safety, materialization policy,
  sanitized errors, and reader/writer/admin separation.
- [ ] Update documentation only after implementation verification passes and
  keep unavailable, allowlisted, beta, deprecated, restricted, or non-public
  surfaces labelled honestly.

## Task Breakdown

### TASK-001: Product and Descriptor Metadata

**Parallelizable**: No

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayModels.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`

**Work**:

- Add missing product keys for Ads Data Hub, Business Profile, and Local
  Services Ads.
- Add descriptor metadata needed by this feature without breaking existing
  catalog consumers.
- Mark planned writer/admin and restricted operations as non-dispatchable.

**Completion Criteria**:

- [ ] All feature product keys encode and decode deterministically.
- [ ] Existing Analytics Data and Search Console implemented catalog rows remain
  dispatchable and unchanged in behavior.
- [ ] Planned operations can appear in inventory output but cannot be routed by
  reader, writer, or admin binaries.
- [ ] Tests prove no descriptor uses wildcard origins, caller-selected methods,
  arbitrary paths, arbitrary scopes, or unofficial endpoints.

### TASK-002: OAuth Profile Isolation

**Parallelizable**: Yes, after TASK-001 metadata names are stable

**Files**:

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/OAuthSupport.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`

**Work**:

- Add reader profile validation for the new reader products selected in this
  slice.
- Preserve exact `analytics.readonly` and `webmasters.readonly` behavior for
  implemented Analytics Data and Search Console readers.
- Reject mixed-product, broad write-capable, duplicate, empty, and extra scope
  bundles in reader mode.

**Completion Criteria**:

- [ ] Product-isolated profiles cannot be reused across Analytics Admin,
  Analytics Data, Tag Manager, YouTube, Search Console, Ads Data Hub, Business
  Profile, or Local Services Ads.
- [ ] Writer/admin scopes are rejected by reader profiles.
- [ ] Profile validation happens before token resolution or network transport.
- [ ] Errors are sanitized and never print token, client secret, refresh token,
  cookie, authorization header, or environment variable values.

### TASK-003: Analytics Admin Reader Foundation

**Parallelizable**: Yes, after TASK-001 and TASK-002

**Files**:

- `Sources/GoogleMarketingGatewayCore/AnalyticsAdminRequests.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsAdminRequestTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AnalyticsAdminCLITests.swift`

**Work**:

- Add reader request builders for account summaries, accounts get/list,
  properties get/list, data streams get/list, custom dimensions/metrics list,
  conversion/key events list, product links list, access bindings list, and
  change history search where official and version-pinned.
- Keep Analytics Admin separate from Analytics Data because scopes and write
  risks differ.
- Treat access bindings as sensitive account metadata and keep any mutation
  disabled.

**Completion Criteria**:

- [ ] Requests use only the pinned official Analytics Admin origin and version.
- [ ] Account, property, stream, link, and access-binding resource names are
  validated before URL construction.
- [ ] Reader CLI routes resolve exact operation IDs and fail before credential
  resolution on invalid input.
- [ ] Tests cover pagination, query encoding, sanitized provider errors, and
  reader rejection of configuration mutations.

### TASK-004: Tag Manager Reader Foundation

**Parallelizable**: Yes, after TASK-001 and TASK-002

**Files**:

- `Sources/GoogleMarketingGatewayCore/TagManagerRequests.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Tests/GoogleMarketingGatewayCoreTests/TagManagerRequestTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/TagManagerCLITests.swift`

**Work**:

- Add reader request builders for accounts, containers, workspaces, tags,
  triggers, variables, folders, templates, versions, environments, user
  permissions, and built-in variables.
- Keep workspace edits as writer operations and publish/access changes as admin
  operations.
- Use typed path components rather than caller-supplied URL fragments.

**Completion Criteria**:

- [ ] Requests use only `https://tagmanager.googleapis.com` and API v2 paths.
- [ ] Account, container, workspace, environment, and version identifiers are
  validated and path-encoded safely.
- [ ] Reader CLI exposes only implemented read operations.
- [ ] Tests prove publish, delete, permission, and workspace mutation routes are
  not accepted by reader mode.

### TASK-005: Planned Inventory for YouTube, Ads Data Hub, Business Profile, Local Services Ads, and Search Console

**Parallelizable**: Yes, after TASK-001

**Files**:

- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`

**Work**:

- Add planned reader descriptors for YouTube Data/Analytics, Ads Data Hub,
  Business Profile, Local Services Ads, and Search Console expansion from the
  accepted design.
- Label restricted, allowlisted, beta, migrated, deprecated, or non-public
  surfaces explicitly.
- Classify Ads Data Hub query execution and large report materialization as
  not ordinary read dispatch unless policy controls are present.

**Completion Criteria**:

- [ ] Planned inventory is visible with featureId `analytics-content-local` and
  explicit availability.
- [ ] No planned descriptor becomes callable without request builders, profile
  validation, CLI routing, and tests.
- [ ] YouTube monetary reports, Ads Data Hub execution, Business Profile edits,
  and Local Services Ads lead/budget changes are classified as sensitive,
  writer, admin, restricted, or deferred as applicable.
- [ ] Existing Search Console reader behavior remains stable.

### TASK-006: CLI Routing, Materialization, and Safety

**Parallelizable**: Yes, after implemented request builders compile

**Files**:

- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift`
- `Sources/GoogleMarketingGatewayReader/main.swift`
- `Sources/GoogleMarketingGatewayWriter/main.swift`
- `Sources/GoogleMarketingGatewayAdmin/main.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/NewReaderCLITests.swift`

**Work**:

- Route implemented reader operations only through the reader binary.
- Keep writer/admin binaries unavailable for this feature until reviewed
  plan/apply and idempotency controls exist.
- Add bounded output/materialization behavior for large report, query result,
  media, or analytics payload classes selected by descriptors.

**Completion Criteria**:

- [ ] Unknown, planned, writer, admin, restricted, and billable-risk operations
  fail before credential resolution.
- [ ] Request files are schema-specific, local-path-only, size-limited,
  depth-limited, and validated before token access.
- [ ] Large outputs are bounded or materialized with opaque local references.
- [ ] Error output contains only safe request IDs, reason codes, and field paths.

### TASK-007: Verification and Documentation Closure

**Parallelizable**: No

**Files**:

- `README.md`
- `design-docs/analytics-content-local-capabilities.md`
- `impl-plans/analytics-content-local-capabilities.md`
- `Sources/`
- `Tests/`

**Work**:

- Run narrow tests for each changed surface before full lint, test, and build.
- Review diffs for false coverage claims, arbitrary endpoint acceptance, secret
  leakage, and accidental writer/admin enablement.
- Document implemented versus planned coverage without live billable Google
  actions.

**Completion Criteria**:

- [ ] `swift test --filter AnalyticsAdmin`
- [ ] `swift test --filter TagManager`
- [ ] `swift test --filter OperationCatalogTests`
- [ ] `swift test --filter CredentialProfileTests`
- [ ] `mise run lint`
- [ ] `mise run test`
- [ ] `mise run build`
- [ ] README and catalog claims match implemented behavior exactly.

## Dependencies

- `design-docs/analytics-content-local-capabilities.md` is the accepted source
  of truth.
- Implementation-time official documentation recheck is required before pinning
  Analytics Admin version, Business Profile API families, Local Services Ads
  public operations, and Ads Data Hub executable query policies.
- Existing implemented readers in `AnalyticsDataRequests.swift` and
  `SearchConsoleRequests.swift` must remain stable.
- Existing capability binaries in `Sources/GoogleMarketingGatewayReader`,
  `Sources/GoogleMarketingGatewayWriter`, and
  `Sources/GoogleMarketingGatewayAdmin` define routing boundaries.
- No live billable Google actions are permitted for this plan. Later live
  verification must use `me@tacogips.me`, each paid action must be `<= USD 5`,
  total spend must stay `< USD 50`, and campaign creation or spend requires
  explicit approval.

## Parallelizable Tasks

- TASK-002 can proceed after TASK-001 product names and descriptor fields are
  stable.
- TASK-003 and TASK-004 can proceed in parallel after TASK-001 and TASK-002.
- TASK-005 can proceed in parallel with TASK-003 and TASK-004 because planned
  inventory is non-dispatchable.
- TASK-006 can proceed per implemented request-builder surface after each
  builder compiles.
- TASK-007 waits for all selected implementation tasks and verification results.

## Progress Tracking

- 2026-08-14: Plan created for feature-local Step 4 from accepted design review.
- 2026-08-14: Step 4 self-review requested plan-only revision for explicit
  progress tracking and untracked-file diff verification behavior.
- 2026-08-14: Plan revised to add this progress tracking section and clarify
  that `git diff --no-index` returns status 1 when differences are present.
- [ ] TASK-001 pending.
- [ ] TASK-002 pending.
- [ ] TASK-003 pending.
- [ ] TASK-004 pending.
- [ ] TASK-005 pending.
- [ ] TASK-006 pending.
- [ ] TASK-007 pending.

## Verification

- `sed -n '1,260p' design-docs/analytics-content-local-capabilities.md`
- `sed -n '1,320p' impl-plans/analytics-content-local-capabilities.md`
- `git status --short -- design-docs/analytics-content-local-capabilities.md impl-plans/analytics-content-local-capabilities.md`
- `git diff --no-index /dev/null impl-plans/analytics-content-local-capabilities.md || true`
- `swift test --filter AnalyticsAdmin`
- `swift test --filter TagManager`
- `swift test --filter OperationCatalogTests`
- `swift test --filter CredentialProfileTests`
- `mise run lint`
- `mise run test`
- `mise run build`

## Completion Criteria

- [ ] The implementation materially advances analytics, content, search,
  measurement-clean-room, and local operations coverage without claiming every
  official resource method is implemented.
- [ ] Implemented request builders use fixed official origins and typed or
  schema-bounded request construction only.
- [ ] Product-isolated OAuth profiles preserve least privilege and reject
  cross-product or write-capable reader scope bundles.
- [ ] Reader, writer, and admin capability separation remains enforced by tests.
- [ ] Planned, restricted, allowlisted, beta, deprecated, or non-public surfaces
  are represented honestly and remain non-dispatchable unless fully implemented.
- [ ] No unofficial scraping endpoints, billable live actions, campaign
  creation, spend, secret values, arbitrary URLs, or raw sensitive provider
  payloads are introduced.
- [ ] SwiftLint, tests, and build pass or any inability to run them is recorded.

## Addressed Feedback

- Step 3 accepted the design and found no high or mid findings.
- The low verification note is addressed by including
  `git diff --no-index /dev/null impl-plans/analytics-content-local-capabilities.md || true`
  for newly untracked plan content.
- Step 4 self-review's mid plan-only finding is addressed by adding explicit
  progress tracking with created/reviewed status and task-level pending state.
- Step 4 self-review's low plan-only finding is addressed by documenting the
  expected nonzero `git diff --no-index` behavior through `|| true`.
- The plan targets only `impl-plans/analytics-content-local-capabilities.md` for
  fanout featureId `analytics-content-local`.

## Risks

- Official Google API versions, availability, allowlisting, and entitlement
  details may change and require implementation-time documentation recheck.
- Analytics Admin access bindings, YouTube monetary reports, Ads Data Hub query
  execution, Business Profile operations, and Local Services Ads operations may
  require sensitive-reader or admin policies.
- Ads Data Hub execution and large reporting surfaces can create durable jobs,
  large outputs, privacy-check failures, or billable API usage if classified too
  loosely.
- Business Profile and Local Services Ads changes can affect public listings,
  lead handling, or budgets and must remain gated behind writer/admin controls.
