# Google Ads Agency Account Operations

**Feature ID**: `ads-agency-core`
**Issue**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Workflow mode**: `issue-resolution`
**Status**: Draft design for implementation planning
**Author verification date**: 2026-08-14
**Feature summary**: Cover manager/client hierarchy, customer access,
mutate/read/admin-safe routing, OAuth scopes, and operation catalog foundation
for agency-managed accounts.

## 1. Purpose

This feature establishes the agency-account foundation for
`google-marketing-gateway`. The repository already contains capability-separated
reader, writer, and admin executables; product-isolated reader credential
profiles; installed desktop OAuth; fixed-origin request builders; and bounded
reader routes for Google Ads API v25, Analytics Data v1beta, Search Console,
AdSense, and AdMob. The next implementation slice must preserve those safety
properties while making agency-managed Google Ads accounts explicit enough to
support later complete official product coverage.

The design covers Google Ads manager/client hierarchy, accessible customer
discovery, selected read and mutate routing, administrative safeguards, OAuth
scope boundaries, and an operation-catalog model that can honestly represent
Google Marketing Platform, Google Ad Manager, Merchant Center, Analytics Admin,
Tag Manager, YouTube, Search Console, AdSense, AdMob, Ads Data Hub, Authorized
Buyers, Business Profile, and Local Services Ads without claiming unsupported
method-level implementation.

## 2. Scope

In scope for this feature:

- Google Ads API v25 agency account foundation: accessible customers,
  manager/client relationship reads, customer hierarchy traversal, customer
  access reads, and a bounded operation-catalog shape for future mutates.
- Explicit routing by gateway capability: logical reads in
  `google-marketing-gateway-reader`, non-administrative allowlisted writes in
  `google-marketing-gateway-writer`, and account/access/billing/publish/delete
  operations in `google-marketing-gateway-admin`.
- Product-isolated OAuth profiles and developer-token handling. Google Ads
  continues to use the official `https://www.googleapis.com/auth/adwords` scope,
  with gateway policy providing read/write/admin separation because Google Ads
  does not expose separate read-only and mutate scopes.
- Operation catalog descriptors that include product, official API family,
  version or stability, fixed origin, operation id, capability, OAuth scopes,
  request classification, billable/spend risk, availability, and implementation
  status.
- Safe request-file handling for GAQL and future bounded generic REST bodies:
  local validation before credential resolution, fixed official origins, no
  caller-provided headers, no arbitrary URL passthrough, and sanitized errors.
- Honest documentation of unavailable, allowlisted, beta, deprecated,
  sunset, restricted, or non-public surfaces.

Out of scope for this feature:

- Performing live billable Google actions, campaign creation, budget changes,
  or ad serving changes.
- Scraping, browser replay, unofficial endpoints, or user-provided REST origins.
- Claiming every official Google marketing API method is implemented.
- Cross-product unified resource models that hide provider semantics.
- Multi-tenant hosted service behavior or shared token storage.

## 3. Existing Baseline

The current repository baseline relevant to this feature is:

| Area | Current file(s) | Current behavior |
|---|---|---|
| Executables | `Sources/GoogleMarketingGatewayReader/main.swift`, `Sources/GoogleMarketingGatewayWriter/main.swift`, `Sources/GoogleMarketingGatewayAdmin/main.swift` | Separate reader, writer, and admin modes delegate into shared core CLI. |
| Gateway mode | `Sources/GoogleMarketingGatewayCore/GatewayModels.swift` | Capability is represented as `reader`, `writer`, or `admin`. |
| Operation catalog | `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` | Implemented reader descriptors exist for Google Ads, Analytics Data, Search Console, AdSense, and AdMob; Google Trends is marked alpha allowlist required. |
| Credential profiles | `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift` | Reader-only profile validation, exact reader scopes for implemented products, safe environment-variable references, Google Ads developer-token reference, and optional `loginCustomerId`. |
| Google Ads requests | `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift` | Fixed `https://googleads.googleapis.com` v25 accessible-customer and GAQL search request construction with bearer, developer-token, and optional `login-customer-id` headers. |
| CLI routing | `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift` | Closed reader routes dispatch implemented operations through injected transport. |
| Tests | `Tests/GoogleMarketingGatewayCoreTests/` | Deterministic request, CLI, profile, OAuth, catalog, and redaction tests for the implemented reader foundation. |

This design must not weaken those boundaries. Implementation should extend the
same target, catalog, credential, request, CLI, and test patterns rather than
introducing a parallel arbitrary API gateway.

## 4. Agency Account Model

Google Ads agency operation requires four identifiers to remain distinct:

| Identifier | Meaning | Source | Gateway handling |
|---|---|---|---|
| Auth principal | The Google user or service account represented by the OAuth token. | Credential profile and token store. | Never accepted from request input; selected by `--profile`. |
| Developer token | Google Ads API developer token. | Environment variable named by credential profile. | Required for Google Ads; never printed, stored in config, or accepted in GraphQL/CLI input. |
| Login customer ID | Manager account used in the `login-customer-id` header. | Credential profile. | Optional ASCII digits, no hyphens; used only as a header and never inferred from user input. |
| Operating customer ID | Customer whose resources are read or mutated. | CLI/GraphQL variables. | Required per operation where applicable; ASCII digits, no hyphens; validated before credentials. |

The gateway must treat manager traversal as data, not authorization. A caller may
request hierarchy reads for accessible or selected customers, but the gateway
does not assume a discovered account is safe for writes. Mutate and admin
operations require an explicit target customer, operation id, capability mode,
credential profile, and allowlist entry.

The first agency hierarchy slice should add typed read operations for:

- `google-ads.customer-client-links.list`: GAQL-backed read of
  `customer_client_link` relationships for a manager customer.
- `google-ads.customer-clients.list`: GAQL-backed read of `customer_client`
  rows for a manager customer, including manager flag and status fields.
- `google-ads.customer-users.list`: GAQL-backed read of customer user access
  and role metadata where the selected credentials are authorized.

These are logical reads even though they use the existing `googleAds:search`
POST method. They must run in the reader binary and use the exact same fixed
origin, developer-token, optional login-customer header, customer-id validation,
page-token validation, local query construction, and sanitized error behavior
as the existing `google-ads.search` route.

## 5. Capability Routing

Capability is a gateway policy decision and must not be inferred from HTTP verb
alone.

| Capability | Allowed Google Ads operation families | Examples | Exclusions |
|---|---|---|---|
| Reader | Accessible customers, GAQL search, hierarchy reads, change-event reads, customer access reads. | `CustomerService.ListAccessibleCustomers`, `GoogleAdsService.Search`. | Mutates, uploads, batch jobs, billing, access writes. |
| Writer | Narrow, non-administrative, reversible or plan-safe mutates after allowlist review. | Campaign/ad group/ad status, labels, selected asset associations, recommendation dismiss/apply where reviewed. | Budget increases, account creation, access control, billing, conversion uploads until separately reviewed. |
| Admin | Principal, account, billing, manager-link, policy, irreversible, or publish-like operations. | Customer user access mutate, customer client link mutate, account budget/proposal, billing setup, account status operations. | Any operation lacking explicit admin descriptor, tests, and confirmation policy. |

The writer and admin binaries may expose read routes only when the operation
descriptor is available to that binary and profile capability. A writer cannot
invoke an admin operation through a generic mutate endpoint. An admin cannot
call a provider method unless the operation catalog contains the exact method
and policy metadata.

## 6. OAuth and Profile Decisions

Google Ads continues to require:

- OAuth scope: `https://www.googleapis.com/auth/adwords`.
- Developer token: environment variable reference in the credential profile.
- Optional `loginCustomerId`: digits only, max 20 bytes, configured in the
  profile and not supplied per request.
- Operating customer ID: digits only, max 20 bytes, supplied as route input.

Because Google Ads exposes the same OAuth scope for reads and mutates, least
privilege is enforced by:

- separate binaries;
- profile capability;
- operation catalog capability;
- operation allowlists;
- fixed request builders;
- command/GraphQL validation before credential resolution;
- tests proving writer/admin operations are unreachable from reader mode.

Future writer/admin credential profiles must not be accepted by the current
reader-only `CredentialProfileConfiguration` until the implementation slice adds
explicit profile validation for writer and admin modes. That validation must
reject cross-product scope bundles and must not allow an `adwords` token to be
used for non-Google-Ads products.

## 7. Operation Catalog Foundation

`OperationDescriptor` is currently intentionally small. The agency foundation
needs a richer descriptor model before broad product coverage is claimed.

Required descriptor fields:

| Field | Purpose |
|---|---|
| `id` | Stable gateway operation id such as `google-ads.customer-clients.list`. |
| `product` | Existing `MarketingProduct` or an added product enum value. |
| `apiFamily` | Official product API family, for example `google-ads`, `dv360`, `cm360`, `sa360`, `merchant`, `analytics-admin`. |
| `apiVersion` | Provider version such as `v25`, `v5`, `v1beta`, `v2`, or `soap`. |
| `stability` | `ga`, `beta`, `alpha`, `allowlisted`, `deprecated`, `sunset`, `restricted`, or `nonPublic`. |
| `origin` | Fixed official origin. No descriptor may contain a wildcard or caller-selected origin. |
| `providerMethod` | Exact official method or SOAP service/action name. |
| `capability` | `reader`, `writer`, or `admin`. |
| `oauthScopes` | Exact product-isolated scopes. |
| `requestKind` | `read`, `report`, `mutate`, `upload`, `access`, `billing`, `publish`, `delete`, or `job`. |
| `spendRisk` | `none`, `indirect`, `billableApiOnly`, or `adSpend`. |
| `availability` | `implemented`, `planned`, `blockedByAccess`, `blockedByBeta`, `deprecatedNoNewWork`, `excludedNoOfficialPublicApi`. |
| `requestBodyPolicy` | `none`, `typed`, `boundedJSONFile`, `boundedTextFile`, or `providerGeneratedOnly`. |
| `responsePolicy` | Inline JSON size limit or materialized download policy. |
| `tests` | Required deterministic tests before an operation can be marked implemented. |

Catalog output must separate implemented operations from planned inventory.
Planned rows are useful for capability matrices but must not be accepted by
`OperationCatalog.operation(id:)` until implementation exists.

## 8. Product Inventory Matrix

The following matrix is a capability inventory for planning, not a claim of
implementation. Each product must keep its official API version, origin, scopes,
stability, quota behavior, and access prerequisites visible.

| Product | Official API surface | Agency-operation relevance | Gateway disposition |
|---|---|---|---|
| Google Ads API | REST/gRPC Google Ads API v25. | Manager/client hierarchy, GAQL reads, resource mutates, customer access, manager links, account budgets. | Core focus. Existing reads remain implemented; hierarchy and access reads are next; mutates/admin require allowlisted descriptors. |
| Display & Video 360 | DV360 API. | Advertisers, campaigns, insertion orders, line items, creatives, channels, user access. | Planned inventory. Add product enum/catalog only with fixed official origin, scopes, and access prerequisites. |
| Campaign Manager 360 | CM360 API v5. | Trafficking, placements, ads, creatives, reports, attribution. | Planned inventory. Mark v5 and distinguish trafficking writes from report reads. |
| Search Ads 360 | SA360 Reporting API and conversion upload surfaces. | Reporting and offline conversions for agencies. | Planned inventory. Report reads first; offline conversion uploads are writer/admin reviewed because they affect attribution. |
| Google Ad Manager | REST beta plus SOAP API. | Networks, inventory, orders, line items, creatives, reports, users/teams. | Planned inventory. REST beta labelled beta; SOAP support must use typed service descriptors, not arbitrary XML passthrough. |
| Merchant Center | Merchant API. | Accounts, products, promotions, inventory, reports, quotas. | Planned inventory with existing design precedent. Product/inventory writes are writer; account/user/link operations are admin. |
| Analytics Admin | Admin API v1beta/v1alpha. | Account/property configuration, access bindings, product links. | Planned expansion. Reads and change history can be reader; config writes are writer; access/delete/acknowledgement operations are admin. |
| Analytics Data | Data API v1beta. | Reporting across client properties. | Existing reader foundation. Advanced report jobs and materialization need descriptor expansion. |
| Tag Manager | Tag Manager API v2. | Containers, workspaces, tags, triggers, variables, permissions, publish. | Planned inventory. Workspace edits are writer; publish/delete/users/accounts are admin. |
| YouTube Data | YouTube Data API v3. | Channel/video/playlist metadata needed for reporting. | Planned inventory. Metadata reads only by default; upload/comment/channel admin excluded until separately justified. |
| YouTube Analytics | YouTube Analytics API v2. | Channel/content-owner reports and groups. | Planned inventory. Activity and monetary scopes must be separate profiles. |
| Search Console | Search Console and URL Inspection APIs. | Site performance and indexing diagnostics. | Existing reader foundation. Sitemap writes are writer; site association changes are admin. |
| AdSense | AdSense Management API v2. | Publisher account inventory, payments, policy, reports. | Existing reader foundation. Inventory mutations are writer; payment and access-sensitive operations stay read/admin separated. |
| AdMob | AdMob API v1. | Apps, ad units, network and mediation reports. | Existing reader foundation. Stable v1 has no broad mutations; beta mutation surfaces require separate review. |
| Ads Data Hub | Ads Data Hub API. | Customers, links, queries, query execution, saved results. | Planned inventory. Query execution can be billable/large-output and must materialize; customer/link operations are admin. |
| Authorized Buyers Marketplace | Marketplace API. | Deals, clients, proposals, publisher profiles. | Planned inventory. Negotiation and deal writes require writer/admin review. |
| Real-time Bidding | Real-time Bidding API. | Bidders, creatives, pretargeting, users. | Planned inventory. Creative and pretargeting writes affect serving and require admin-safe policy. |
| Business Profile | Business Profile APIs. | Organizations, locations, users, reviews. | Planned inventory. Review replies and location updates are writer; user/location ownership changes are admin. |
| Local Services Ads | Local Services Ads API. | Multi-account reads and lead/account management where available. | Planned inventory. Represent only official public methods; restricted availability must be explicit. |
| Google Trends | Official API alpha only. | Market research, not agency account operations. | Excluded from generally available gateway; no scraping or unofficial endpoints. |

## 9. Request Construction and File Safety

All provider calls added by this feature must follow these rules:

- Operations are selected by stable catalog id, never by caller-provided method,
  URL, origin, path, or header.
- Request files are opened only after route, identifier, and descriptor
  validation. Credentials are resolved only after local validation succeeds.
- GAQL query text remains bounded to the existing 1 MiB policy unless a later
  design narrows the limit for generated hierarchy queries.
- JSON request-file support, if added for future mutates, must be UTF-8,
  bounded, schema-validated against an operation-specific typed or safely
  generic allowlist, and redacted from errors.
- Provider response bodies, bearer tokens, refresh tokens, developer tokens,
  OAuth client secrets, manager IDs from credentials, request body contents, and
  private customer data must not appear in error messages.
- Large reports and query outputs must return bounded inline summaries or
  materialized download keys, not unbounded stdout/GraphQL payloads.

## 10. Implementation Slices

The recommended implementation order is:

1. Extend the operation descriptor model while preserving existing catalog JSON
   compatibility or adding a versioned catalog command if compatibility cannot
   be preserved.
2. Add Google Ads hierarchy/access read descriptors and typed generated-GAQL
   builders backed by the existing `GoogleAdsRequests.search` transport.
3. Add CLI or GraphQL reader routes for hierarchy/access reads with deterministic
   transport tests and no live provider calls.
4. Add writer/admin profile validation model without enabling any mutates.
5. Add a mutation plan representation for Google Ads operations with empty
   allowlists by default.
6. Enable one narrow non-administrative writer operation only after plan/apply,
   redaction, spend-risk, and rollback tests pass.
7. Expand product enum/catalog inventory for GMP, Ad Manager, Merchant,
   Analytics Admin, Tag Manager, YouTube, Ads Data Hub, Authorized Buyers,
   Business Profile, and Local Services Ads as planned descriptors only.

## 11. Acceptance Criteria

The feature is acceptable when:

- The declared Google Ads agency hierarchy reads have operation descriptors,
  fixed request construction, CLI/GraphQL routing, and deterministic tests.
- Reader mode cannot invoke writer/admin descriptors.
- Writer/admin profiles are either unsupported with clear errors or explicitly
  validated by mode; no current reader validation is weakened.
- Google Ads developer token and login customer ID remain profile-controlled and
  sanitized.
- The catalog distinguishes implemented operations from planned, beta,
  allowlisted, deprecated, and excluded surfaces.
- No descriptor permits unofficial scraping endpoints or caller-selected
  origins.
- Verification includes `mise run lint`, `mise run test`, `mise run build`, and
  targeted catalog/profile/request/CLI tests for the added operations.
- Documentation states that no live billable Google action was performed.

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Google Ads uses one OAuth scope for read and write. | Enforce least privilege in binary mode, profile capability, operation descriptors, allowlists, and tests. |
| Manager hierarchy discovery is mistaken for mutate authorization. | Require explicit target customer and operation descriptor for every write/admin action. |
| Catalog inventory overstates implementation. | Separate `implemented` from `planned` and block dispatch unless the descriptor is implemented. |
| Generic REST support becomes arbitrary proxying. | Permit only descriptor-bound origins, methods, paths, headers, and typed or bounded request bodies. |
| Agency operations can incur spend or affect serving. | Mark spend risk in descriptors; require writer/admin review, plan/apply, and explicit budget policy before any paid action. |
| Beta, allowlisted, or restricted APIs change. | Label stability per descriptor and require fixture/schema review before enabling dispatch. |

## 13. Open Questions

- Should writer/admin credential profile configuration be a separate file type
  from reader profiles, or a versioned extension of the existing profile schema?
- Should Google Ads hierarchy reads expose generated fixed reports only, or also
  allow bounded user GAQL constrained by a field/resource allowlist?
- What is the first non-administrative Google Ads mutate that is useful enough
  to justify plan/apply implementation without creating spend risk?
- Should SOAP-based Google Ad Manager support be implemented through generated
  typed service clients, hand-authored operation descriptors, or postponed until
  REST beta covers enough inventory and order workflows?
