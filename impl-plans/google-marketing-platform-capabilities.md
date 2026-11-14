# Google Marketing Platform Capabilities

**Status**: Planned
**Workflow mode**: `issue-resolution`
**Feature ID**: `gmp-products`
**Issue reference**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Design reference**: `design-docs/google-marketing-platform-capabilities.md`
**Codex agent references**: none

## Purpose

Implement the gateway foundation for official Google Marketing Platform coverage
without claiming complete per-method support. The first slice adds descriptor-
bounded reader coverage for Display & Video 360, Campaign Manager 360 v5, and
Search Ads 360 Reporting, while preserving product isolation, fixed official
origins, capability-separated binaries, exact OAuth profile validation,
bounded request files, sanitized errors, and non-billable verification.

## Resolved Provider Pins

| Product | Catalog key | Version pin | Official origin | Discovery fixture URL | OAuth scopes |
|---|---|---:|---|---|---|
| Display & Video 360 API | `dv360` | `v4` | `https://displayvideo.googleapis.com` | `https://displayvideo.googleapis.com/$discovery/rest?version=v4` | `https://www.googleapis.com/auth/display-video`; admin-only user operations use `https://www.googleapis.com/auth/display-video-user-management` |
| Bid Manager API for DV360 reporting metadata | `dv360-bid-manager` | `v2` | `https://doubleclickbidmanager.googleapis.com` | `https://doubleclickbidmanager.googleapis.com/$discovery/rest?version=v2` | `https://www.googleapis.com/auth/doubleclickbidmanager` |
| Campaign Manager 360 API | `cm360-v5` | `v5` | `https://dfareporting.googleapis.com` | `https://dfareporting.googleapis.com/$discovery/rest?version=v5` | Trafficking metadata: `https://www.googleapis.com/auth/dfatrafficking`; reporting metadata: `https://www.googleapis.com/auth/dfareporting`; offline conversion writer/admin work: `https://www.googleapis.com/auth/ddmconversions` |
| Search Ads 360 Reporting API | `sa360` | `v0` | `https://searchads360.googleapis.com` | `https://searchads360.googleapis.com/$discovery/rest?version=v0` | `https://www.googleapis.com/auth/doubleclicksearch` |

Provider scopes are broad. Gateway capability remains enforced by executable,
profile product, descriptor capability, operation allowlist, and tests.

## Deliverables

- [ ] Extend `MarketingProduct` and catalog serialization for `dv360`,
  `dv360-bid-manager`, `cm360-v5`, and `sa360` without breaking existing
  operation catalog JSON.
- [ ] Extend `OperationDescriptor` metadata with fixed origin, API version,
  HTTP method/path template, path bindings, request schema name, response
  envelope, stability, quota dimensions, pagination fields, persistence class,
  and data classification.
- [ ] Add product-isolated credential profile validation for the exact scope
  bundles above, including `partnerId`, optional `advertiserId`, `profileId`,
  `customerId`, and optional `loginCustomerId` bindings.
- [ ] Add descriptor fixtures under
  `Tests/GoogleMarketingGatewayCoreTests/Fixtures/gmp/` generated from the
  official discovery URLs and reduced to the implemented operation metadata.
- [ ] Add typed or bounded request builders for implemented reader descriptors
  only. No CLI or GraphQL route accepts caller-supplied origins, methods, paths,
  headers, OAuth scopes, or arbitrary URLs.
- [ ] Add CLI/catalog routing for implemented reader operations only; writer and
  admin descriptors remain planned or blocked unless a later plan/apply design
  authorizes them.
- [ ] Add tests for fixed origin construction, exact scope/profile rejection,
  path encoding, request-file size/schema limits, sanitized provider errors,
  quota/pagination metadata, materialization behavior, and reader mutation
  blocking.
- [ ] Update `README.md` and the completed plan only after implementation and
  verification pass.

## Initial Operation Metadata

| Operation ID | Method and path | Capability | Scope | Quota dimensions | Pagination | Persistence | Data class |
|---|---|---|---|---|---|---|---|
| `dv360.partners.list` | `GET /v4/partners` | reader | `display-video` | Google project, authenticated DV360 user, partner visibility | `pageSize`, `pageToken`, `nextPageToken` | none | account hierarchy |
| `dv360.partners.get` | `GET /v4/partners/{partnerId}` | reader | `display-video` | project, user, partner | none | none | account hierarchy |
| `dv360.advertisers.list` | `GET /v4/advertisers` | reader | `display-video` | project, user, partner filter | `pageSize`, `pageToken`, `nextPageToken` | none | client account |
| `dv360.advertisers.get` | `GET /v4/advertisers/{advertiserId}` | reader | `display-video` | project, user, advertiser | none | none | client account |
| `dv360.advertisers.campaigns.list` | `GET /v4/advertisers/{advertiserId}/campaigns` | reader | `display-video` | project, user, advertiser | `pageSize`, `pageToken`, `nextPageToken` | none | campaign metadata |
| `dv360.advertisers.insertionOrders.list` | `GET /v4/advertisers/{advertiserId}/insertionOrders` | reader | `display-video` | project, user, advertiser | `pageSize`, `pageToken`, `nextPageToken` | none | delivery metadata |
| `dv360.advertisers.lineItems.list` | `GET /v4/advertisers/{advertiserId}/lineItems` | reader | `display-video` | project, user, advertiser | `pageSize`, `pageToken`, `nextPageToken` | none | delivery metadata |
| `dv360.advertisers.creatives.list` | `GET /v4/advertisers/{advertiserId}/creatives` | reader | `display-video` | project, user, advertiser | `pageSize`, `pageToken`, `nextPageToken` | none | creative metadata |
| `dv360.users.list` | `GET /v4/users` | admin-planned | `display-video-user-management` | project, admin user, partner/advertiser access | `pageSize`, `pageToken`, `nextPageToken` | none | user access |
| `dv360-bid-manager.queries.list` | `GET /v2/queries` | reader | `doubleclickbidmanager` | project, DV360 user | `pageSize`, `pageToken`, `nextPageToken` | none | report metadata |
| `dv360-bid-manager.queries.reports.list` | `GET /v2/queries/{queryId}/reports` | reader | `doubleclickbidmanager` | project, DV360 user, query | `pageSize`, `pageToken`, `nextPageToken` | none | report metadata |
| `cm360-v5.userProfiles.list` | `GET /dfareporting/v5/userprofiles` | reader | `dfatrafficking` for trafficking profile discovery; `dfareporting` for report-only profile discovery | project, user | `maxResults`, `pageToken`, `nextPageToken` | none | account hierarchy |
| `cm360-v5.accounts.list` | `GET /dfareporting/v5/userprofiles/{profileId}/accounts` | reader | `dfatrafficking` | project, profile | `maxResults`, `pageToken`, `nextPageToken` | none | account hierarchy |
| `cm360-v5.advertisers.list` | `GET /dfareporting/v5/userprofiles/{profileId}/advertisers` | reader | `dfatrafficking` | project, profile, account filter | `maxResults`, `pageToken`, `nextPageToken` | none | client account |
| `cm360-v5.campaigns.list` | `GET /dfareporting/v5/userprofiles/{profileId}/campaigns` | reader | `dfatrafficking` | project, profile, advertiser/account filter | `maxResults`, `pageToken`, `nextPageToken` | none | campaign metadata |
| `cm360-v5.sites.list` | `GET /dfareporting/v5/userprofiles/{profileId}/sites` | reader | `dfatrafficking` | project, profile | `maxResults`, `pageToken`, `nextPageToken` | none | trafficking metadata |
| `cm360-v5.placements.list` | `GET /dfareporting/v5/userprofiles/{profileId}/placements` | reader | `dfatrafficking` | project, profile, campaign/site filter | `maxResults`, `pageToken`, `nextPageToken` | none | trafficking metadata |
| `cm360-v5.creatives.list` | `GET /dfareporting/v5/userprofiles/{profileId}/creatives` | reader | `dfatrafficking` | project, profile, advertiser/campaign filter | `maxResults`, `pageToken`, `nextPageToken` | none | creative metadata |
| `cm360-v5.reports.list` | `GET /dfareporting/v5/userprofiles/{profileId}/reports` | reader | `dfareporting` | project, profile | `maxResults`, `pageToken`, `nextPageToken` | none | report metadata |
| `cm360-v5.reports.files.list` | `GET /dfareporting/v5/userprofiles/{profileId}/reports/{reportId}/files` | reader | `dfareporting` | project, profile, report | `maxResults`, `pageToken`, `nextPageToken` | none | report metadata |
| `sa360.customers.listAccessibleCustomers` | `GET /v0/customers:listAccessibleCustomers` | reader | `doubleclicksearch` | project, authenticated user, optional `login-customer-id` | none | none | account hierarchy |
| `sa360.customers.customColumns.list` | `GET /v0/customers/{customerId}/customColumns` | reader | `doubleclicksearch` | project, customer, optional `login-customer-id` | `pageSize`, `pageToken`, `nextPageToken` | none | reporting metadata |
| `sa360.searchAds360.search` | `POST /v0/customers/{customerId}/searchAds360:search` | reader | `doubleclicksearch` | project, customer, optional `login-customer-id` | `pageSize`, `pageToken`, `nextPageToken` | none | bounded report rows |

`sa360.searchAds360.searchStream`, offline conversions, CM360 trafficking
writes, DV360 campaign mutations, and all user/access changes stay deferred.

## Tasks

### TASK-001: Catalog and Descriptor Model

**Parallelizable**: No

**Dependencies**: Existing `OperationCatalog.swift`, `GatewayModels.swift`, and
catalog CLI output compatibility.

**Completion Criteria**:

- [ ] New product keys encode and decode deterministically.
- [ ] Existing catalog consumers still read the current fields.
- [ ] Extended metadata is present for every GMP descriptor.
- [ ] Planned writer/admin descriptors are not dispatchable.

### TASK-002: Credential Profile Isolation

**Parallelizable**: Yes, after TASK-001 descriptor shape is agreed.

**Dependencies**: `CredentialProfiles.swift`, `OAuthSupport.swift`, exact scope
table in this plan.

**Completion Criteria**:

- [ ] `dv360`, `dv360-bid-manager`, `cm360-v5`, and `sa360` profiles reject
  empty, duplicate, mixed-product, cross-product, and extra scopes.
- [ ] Product binding fields are validated before token or environment access.
- [ ] SA360 manager calls emit only descriptor-authored `login-customer-id`.
- [ ] Broad provider scopes do not bypass reader/writer/admin executable mode.

### TASK-003: Request Builders and Bounded Inputs

**Parallelizable**: Yes, one product per agent after TASK-001.

**Dependencies**: `HTTPTransport.swift`, `SecureLocalFiles.swift`, existing
Google Ads, Search Console, Analytics Data, AdSense, and AdMob request patterns.

**Completion Criteria**:

- [ ] DV360 requests use only `https://displayvideo.googleapis.com` and version
  `v4`.
- [ ] Bid Manager report metadata requests use only
  `https://doubleclickbidmanager.googleapis.com` and version `v2`.
- [ ] CM360 requests use only `https://dfareporting.googleapis.com` and
  `/dfareporting/v5/...` paths.
- [ ] SA360 requests use only `https://searchads360.googleapis.com` and version
  `v0`.
- [ ] Path identifiers are encoded as single path segments or descriptor-owned
  resource-name templates.
- [ ] POST report/search bodies are typed or schema-bounded and size-limited.

### TASK-004: CLI and Catalog Routing

**Parallelizable**: Yes, after TASK-001 and product request builders compile.

**Dependencies**: `GatewayCLI.swift`, reader executable, operation catalog.

**Completion Criteria**:

- [ ] Reader help exposes only implemented reader operation IDs.
- [ ] Writer/admin binaries cannot be used accidentally through reader routes.
- [ ] Unknown, planned, writer, and admin operations fail before credentials are
  resolved.
- [ ] Catalog output shows version, origin, scope, quota, pagination, and
  availability metadata.

### TASK-005: Fixtures and Tests

**Parallelizable**: Yes, by product and by security invariant.

**Dependencies**: Official discovery fixture URLs, existing test fixtures.

**Completion Criteria**:

- [ ] Discovery-derived fixtures exist under
  `Tests/GoogleMarketingGatewayCoreTests/Fixtures/gmp/`.
- [ ] Unit tests cover every descriptor path, origin, version, scope, quota, and
  pagination entry listed in this plan.
- [ ] Negative tests cover origin/path/header/scope injection attempts.
- [ ] Error fixture tests prove tokens, authorization headers, cookies, and
  request bodies are not printed.
- [ ] Pagination and materialization tests prove bounded inline output behavior.

### TASK-006: Documentation and Closure

**Parallelizable**: Yes, after TASK-004 and TASK-005.

**Dependencies**: Passing verification commands.

**Completion Criteria**:

- [ ] `README.md` documents implemented GMP operation inventory without claiming
  complete official method coverage.
- [ ] This plan is moved to `impl-plans/completed/` only after verification.
- [ ] Residual writer/admin and live-verification work is listed as future work.

## Progress Tracking

- 2026-08-14: Plan created for feature-local Step 4 from accepted design review.
- [ ] TASK-001 pending.
- [ ] TASK-002 pending.
- [ ] TASK-003 pending.
- [ ] TASK-004 pending.
- [ ] TASK-005 pending.
- [ ] TASK-006 pending.

## Parallelizable Work

- DV360 request builder and descriptor fixtures.
- Bid Manager report metadata descriptor fixtures.
- CM360 v5 request builder and descriptor fixtures.
- SA360 request builder and descriptor fixtures.
- Credential-profile negative tests.
- CLI help/catalog snapshot tests.
- Sanitized provider-error tests.

Do not parallelize changes to shared descriptor shape, catalog encoding, or
credential validation until TASK-001 is stable.

## Verification

Plan-only verification:

```bash
test -f impl-plans/google-marketing-platform-capabilities.md
sed -n '1,320p' impl-plans/google-marketing-platform-capabilities.md
git diff --no-index /dev/null impl-plans/google-marketing-platform-capabilities.md
git status --short
```

Implementation verification:

```bash
mise run lint
mise run test
mise run build
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader --help
```

Live verification is out of scope for this implementation plan unless a later
explicit approval names `me@tacogips.me`, zero-cost read-only checks, and a hard
budget for any paid action. Do not create campaigns or spend.

## Risks

- DV360, CM360, Bid Manager, and SA360 entitlements can deny calls even when
  OAuth scopes are correct.
- Provider reporting methods can persist query/report artifacts; this first
  slice reads existing metadata and bounded SA360 search rows only.
- Broad provider scopes can allow writes outside the gateway unless capability
  checks run before credentials and transport.
- Discovery documents, quotas, versions, or deprecations can change; refresh
  fixtures immediately before coding and record fixture retrieval dates.
- Existing `OperationDescriptor` JSON consumers may rely on the current compact
  schema; extended metadata must preserve backward-compatible required fields.
