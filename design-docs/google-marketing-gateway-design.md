# Google Marketing Gateway Design

**Status:** Approved architecture; bounded reader foundation complete, broader roadmap in progress

**Author verification date:** 2026-08-13
**Target:** Swift 6, macOS 14+, Swift Package Manager

## 1. Purpose

`google-marketing-gateway` is a local, AI-oriented gateway for supported Google
marketing products. It presents a consistent GraphQL business surface while
keeping each provider's resource names, permissions, versions, pagination, and
errors explicit. It follows the useful boundaries in `mail-gateway`: a shared
core, capability-separated executables, one-shot GraphQL, local OAuth
bootstrap, testable provider adapters, and download keys for large payloads.

The repository now contains a shared SwiftPM core, capability-separated reader,
writer, and admin executables, product-isolated reader credential profiles,
installed desktop OAuth, and typed AdSense, AdMob, Google Ads v25, Analytics
Data v1beta, and Search Console reader adapters. The bounded reader foundation
has completed adversarial review and non-network verification.
The legacy `google-marketing-gateway` executable remains as a compatibility
shim. GraphQL, durable state, additional roadmap readers, and reviewed
writer/admin allowlists require separate future implementation plans.

## 2. Goals

- Provide least-privilege read, write, and administrative access to documented
  Google marketing APIs without exposing a generic arbitrary-HTTP proxy.
- Support Google Ads, AdSense, AdMob, Search Console, Google Analytics Data and
  Admin, Merchant API, YouTube Analytics, and the minimum YouTube Data API
  metadata needed to interpret analytics resources.
- Include Google Tag Manager because tag configuration, versioning, and
  publishing are directly adjacent to analytics and marketing measurement.
- Use current official Google documentation as the only source for endpoints,
  scopes, mutations, quotas, pagination, and response contracts.
- Use direct `URLSession` REST adapters behind injected protocols, with Swift 6
  concurrency safety and deterministic tests.
- Keep large reports out of GraphQL responses by materializing bounded files
  and returning opaque download keys.
- Make account/product selection, credential selection, provider API version,
  and every mutation explicit and observable.
- Deliver in slices that produce a useful read-only gateway before enabling
  mutations.

## 3. Non-goals

- Scraping `trends.google.com`, replaying browser traffic, or using unofficial
  Google Trends libraries or endpoints.
- Claiming generally available Google Trends support while its official API is
  limited to approved alpha testers.
- A universal campaign, account, report-row, or resource model that erases
  provider semantics.
- Arbitrary REST URLs, arbitrary GraphQL-to-HTTP passthrough, or caller-supplied
  authorization headers.
- A web UI, hosted multi-tenant service, background daemon, or cross-machine
  token synchronization in the first release.
- Bulk media upload, YouTube video publishing, payment changes, billing setup,
  or automatic budget changes in the first release.
- Display & Video 360, Campaign Manager 360, Search Ads 360, Business Profile,
  Play Console, Firebase, or BigQuery in the initial product catalog. These
  require separate product justification, access prerequisites, and review.
- Committing credential files, refresh tokens, developer tokens, service
  account keys, report data, or other secrets and private marketing data.

## 4. Acceptance criteria

The design is acceptable only when reviewers confirm all of the following:

1. Every enabled product and operation is backed by current official Google
   documentation, and versioned or preview APIs are labeled.
2. Scopes map to exact gateway capabilities with least privilege; read-only
   deployments cannot reach gateway mutations.
3. Operations, mutations, quotas, pagination, materialization, and explicit
   exclusions are documented.
4. Google Trends is excluded from the generally available gateway until Google
   publishes a generally available contract; alpha use needs a separately
   reviewed adapter and verified entitlement.
5. Transport, auth boundaries, Swift concurrency, dependency injection,
   errors, retries, testing, lifecycle, rollback, and observability are defined.
6. The implementation slices are ordered, independently verifiable, and keep
   Swift files below 1000 lines.
7. Broad, deep, adversarial, and internal-consistency reviews leave no open
   high- or middle-severity findings.

## 5. Product and official API inventory

The gateway pins an adapter to a reviewed API version. Versions are not silently
advanced: discovery/reference diffs, fixture regeneration, and contract tests
are required. The table describes operation families, not permission to expose
every documented method in v1.

| Product / service | Reader operations | Documented mutations considered | Pagination / quota behavior | Gateway disposition |
|---|---|---|---|---|
| Google Ads API REST | Accessible customers; GAQL `search`; customer, campaign, ad group, ad, asset, conversion, recommendation and change-event reads supported by the selected API version | Resource-specific mutate services, conversion uploads, recommendation apply/dismiss, batch jobs | Prefer paged `search`; explicit `searchStream` only for bounded file materialization. Daily operations depend on developer-token access level; mutate requests have documented operation limits; valid follow-up pages have special quota treatment | Reader in slice 2; a narrow allowlist of campaign/ad-group/ad status and budget mutations later. Billing, user access, account budgets, and uploads remain admin/excluded until separately reviewed |
| AdSense Management API v2 | Accounts, ad clients, units, channels, sites, alerts, payments, policy issues, saved/ad-hoc reports | Create/patch ad units; create/patch/delete custom channels | `pageToken` lists. Current documented general quotas are 100 requests/minute/user/project, 500/minute/project, and 10,000/day; JSON reports cap at 100,000 rows and disclose truncation | Reader plus bounded report export; inventory mutations in writer after write-contract tests; payment data remains read-only |
| AdMob API v1 | Account, apps, ad units; network and mediation reports | No v1 mutations | Account, inventory, and reporting quota buckets; current documented limits include 900 account reads/minute/project, 120 inventory reads/minute/project, 172,800 inventory reads/day/project, and 900 reporting reads/minute/project. Reports are streamed | Reader only. v1beta mediation mutations are excluded from the stable gateway until beta adoption is separately approved |
| Search Console API | Sites, Search Analytics, sitemaps, URL Inspection | Submit/delete sitemap; add/delete site association | Search Analytics uses `startRow`/`rowLimit`; lists use provider pagination where defined. Respect separate load, Search Analytics, URL Inspection, per-user, per-site, and per-project quotas | Reader for analytics/inspection; sitemap changes in writer; site association changes in admin |
| Google Analytics Data API v1beta | Core, pivot, batch, realtime, funnel, metadata, compatibility, audience-export and access reports when entitled | Audience-export lifecycle methods are treated as report jobs, not configuration writes | Offset/limit pagination; normal reports default to 10,000 rows and support up to 250,000 per request. Token, concurrency, thresholded-request, and server-error quotas are returned when requested | Reader only; reports and audience exports materialize to files. Sensitive thresholding metadata must be preserved |
| Google Analytics Admin API v1beta/v1alpha | Accounts, properties, streams, settings, audiences, dimensions/metrics, links, change history, access bindings when permitted | Create/patch/archive/delete configuration; access binding changes; user deletion; acknowledgements and link changes | `pageToken` lists. Current Admin quotas include 1,200 requests/minute, 600/minute/user, 600 writes/minute, and 180 writes/minute/user | Stable read methods in reader; configuration edits in writer; access binding, account/property deletion, user deletion, and irreversible acknowledgements in admin. Alpha methods are off by default and version-labelled |
| Merchant API | Accounts, products, product status, data sources, promotions, inventories, quotas/limits and supported account settings in reviewed sub-APIs | Product input insert/patch/delete; data source, promotion, inventory and supported account-setting changes | Each sub-API retains its version and page token. Quotas are per method and may adjust automatically; product/sub-account update policies and eventual processing must be surfaced | Reader in slice 3; product and inventory changes in writer; account, user, link and developer-registration changes in admin |
| YouTube Analytics API v2 | Targeted reports and group/group-item reads | Group insert/update/delete; group-item insert/delete | Reports use `startIndex` and `maxResults`; group limits and report compatibility are provider rules | Reader for reports; group management in writer; monetary reports require a distinct credential capability |
| YouTube Data API v3 | Channel, video and playlist metadata required to resolve analytics IDs; no search-by-default | None in initial gateway | Page tokens and method-specific unit costs; all requests consume quota. Avoid broad `search.list` when IDs are already known | Companion reader only; uploads, comments, playlist edits and channel administration excluded |
| Google Tag Manager API v2 | Accounts, containers, workspaces, tags, triggers, variables, versions, environments, permissions | Workspace resource changes, version create, publish, environment changes, container/account/user management | Page tokens where documented; current base quota is 10,000 requests/project/day and 0.25 QPS/project | Reader in a later slice; workspace edits in writer; publish, delete, permissions, environments, and account/container administration in admin |
| Google Trends API alpha | None in generally available builds | None | Official documentation describes a limited alpha application, not a generally available public REST contract | Excluded. Never scrape or call unofficial endpoints. An approved alpha adapter needs separate design review, entitlement verification, official schema, and an opt-in build flag |

### 5.1 Authoritative references

- [Google Ads REST authorization and required headers](https://developers.google.com/google-ads/api/rest/auth)
- [Google Ads quotas and limits](https://developers.google.com/google-ads/api/docs/best-practices/quotas)
- [Google Ads mutate overview](https://developers.google.com/google-ads/api/docs/mutating/overview)
- [AdSense Management API v2 REST reference](https://developers.google.com/adsense/management/reference/rest)
- [AdSense direct requests and OAuth scopes](https://developers.google.com/adsense/management/direct_requests)
- [AdSense quotas and report limits](https://developers.google.com/adsense/management/appendix/limits)
- [AdMob v1 REST reference](https://developers.google.com/admob/api/reference/rest)
- [AdMob reporting scopes](https://developers.google.com/admob/api/v1/reporting)
- [AdMob quotas](https://developers.google.com/admob/api/quotas)
- [Search Console API reference](https://developers.google.com/webmaster-tools/v1/api_reference_index)
- [Search Console scopes and Search Analytics query](https://developers.google.com/webmaster-tools/v1/searchanalytics/query)
- [Search Console usage limits](https://developers.google.com/webmaster-tools/limits)
- [Google Analytics Data API quotas](https://developers.google.com/analytics/devguides/reporting/data/v1/quotas)
- [Google Analytics Data API report pagination](https://developers.google.com/analytics/devguides/reporting/data/v1/basics)
- [Google Analytics Admin API REST reference](https://developers.google.com/analytics/devguides/config/admin/v1/rest)
- [Google Analytics Admin API scopes and methods](https://developers.google.com/analytics/devguides/config/admin/v1/rpc/google.analytics.admin.v1alpha)
- [Merchant API REST reference](https://developers.google.com/merchant/api/reference/rest)
- [Merchant API authorization](https://developers.google.com/merchant/api/guides/authorization/access-your-account)
- [Merchant API quotas and limits](https://developers.google.com/merchant/api/guides/quotas-limits)
- [YouTube Analytics API reference and scopes](https://developers.google.com/youtube/analytics/reference)
- [YouTube Analytics report pagination](https://developers.google.com/youtube/analytics/reference/reports/query)
- [YouTube Data API overview and quota model](https://developers.google.com/youtube/v3/getting-started)
- [Tag Manager API overview](https://developers.google.com/tag-platform/tag-manager/api/v2)
- [Tag Manager authorization scopes](https://developers.google.com/tag-platform/tag-manager/api/v2/authorization)
- [Tag Manager quotas](https://developers.google.com/tag-platform/tag-manager/api/v2/limits-quotas)
- [Official Google Trends API alpha page](https://developers.google.com/search/apis/trends)
- [Google OAuth scope catalog](https://developers.google.com/identity/protocols/oauth2/scopes)

References were checked on 2026-08-13. Numeric quotas are operational inputs,
not permanent constants: adapters must expose configured/current limits and
preserve provider quota responses rather than assuming the numbers never change.

### 5.2 Focused reader contracts

The evidence matrix is refined by focused, implementation-testable contracts:

- `design-docs/specs/google-ads-v25-reader.md`;
- `design-docs/specs/analytics-data-v1beta-reader.md`;
- `design-docs/specs/design-search-console-reader.md`.

The Search Console contract fixes the two provider origins, six read-only
operations, exact readonly scope, strict bounded request-file schema, encoded
single-segment identifiers, validation-before-credentials ordering, and an
unchanged writer/admin mutation surface. The slice is implemented; session-715
has completed its fresh post-remediation non-network evidence set and now awaits
independent adversarial review before it is complete. Workflow
`codex-design-and-implement-review-loop-session-713` remains the accepted-design
and remediation provenance, not the owner of the pending independent review.
`design-docs/specs/design-search-console-reader.md` records the binding
remediation decisions, and `impl-plans/completed/search-console-reader.md` records
implementation and verification evidence.

## 6. Capability and scope model

### 6.1 Executables

The scaffold's single executable is replaced, after compatibility deprecation,
by four capability products that share `GoogleMarketingGatewayCore`:

| Executable | GraphQL roots | Local policy |
|---|---|---|
| `google-marketing-gateway-reader` | `Query` only | Reject every mutation before resolver dispatch; load read-capable profiles only |
| `google-marketing-gateway-writer` | `Query` plus allowlisted non-administrative `Mutation` fields | Mutation plan/apply, resource allowlists, and write scopes; cannot publish, alter principals, or perform admin-only operations |
| `google-marketing-gateway-deleter` | Allowlisted provider removal operations only | Exact resource-name confirmation; cannot create, update, read, publish, alter principals, or change billing |
| `google-marketing-gateway-admin` | Full explicitly registered schema | Admin scopes and policy; destructive/identity/publish operations require a short-lived plan confirmation token |

HTTP verbs do not determine capability. Report methods that use `POST` remain
logical reads. Conversely, deletes, publishes, user/access changes, Terms/data
acknowledgements, and billing/account-budget changes are administrative even
when their provider scope is shared with ordinary writes.

### 6.2 Least-privilege scope mapping

| Capability | Minimum OAuth scope(s) | Reader | Writer | Admin |
|---|---|---:|---:|---:|
| Google Ads read or mutate | `https://www.googleapis.com/auth/adwords`; gateway operation policy supplies separation because Google exposes one scope | Yes | Allowlist | Restricted allowlist |
| AdSense read/report | `https://www.googleapis.com/auth/adsense.readonly` | Yes | Yes | Yes |
| AdSense inventory write | `https://www.googleapis.com/auth/adsense` | No | Yes | Yes |
| AdMob inventory/report | Prefer `https://www.googleapis.com/auth/admob.readonly`; report-only profiles may use `https://www.googleapis.com/auth/admob.report` | Yes | No | No |
| Search Console read | `https://www.googleapis.com/auth/webmasters.readonly` | Yes | Yes | Yes |
| Search Console sitemap/site write | `https://www.googleapis.com/auth/webmasters` | No | Sitemap only | Site and sitemap |
| Analytics Data and Admin read | `https://www.googleapis.com/auth/analytics.readonly` | Yes | Yes | Yes |
| Analytics configuration edit | `https://www.googleapis.com/auth/analytics.edit` | No | Allowlist | Full reviewed allowlist |
| Analytics access binding read/write | `https://www.googleapis.com/auth/analytics.manage.users.readonly` / `https://www.googleapis.com/auth/analytics.manage.users` | Optional read | No | Yes |
| Merchant read/write | `https://www.googleapis.com/auth/content`; gateway operation policy supplies separation | Yes | Allowlist | Restricted allowlist |
| YouTube Analytics activity reports | `https://www.googleapis.com/auth/yt-analytics.readonly` | Yes | Yes | Yes |
| YouTube Analytics monetary reports | `https://www.googleapis.com/auth/yt-analytics-monetary.readonly` in a distinct profile | Optional | Optional | Optional |
| YouTube Analytics group management | `https://www.googleapis.com/auth/youtube` for channel owners or `youtubepartner` for entitled content owners | No | Yes | Yes |
| YouTube metadata | `https://www.googleapis.com/auth/youtube.readonly` when private metadata is required; API key only for explicitly public data | Optional | Optional | Optional |
| Tag Manager read/edit | `https://www.googleapis.com/auth/tagmanager.readonly`; add only the documented `https://www.googleapis.com/auth/tagmanager.edit.containers` or `https://www.googleapis.com/auth/tagmanager.edit.containerversions` scope needed | Yes | Workspace edit scopes | Yes |
| Tag Manager publish/delete/users/accounts | Corresponding `https://www.googleapis.com/auth/tagmanager.publish`, `https://www.googleapis.com/auth/tagmanager.delete.containers`, `https://www.googleapis.com/auth/tagmanager.manage.users`, or `https://www.googleapis.com/auth/tagmanager.manage.accounts` scope | No | No | Yes |

Credential profiles declare one product, one principal, an allowed capability
set, and exact granted scopes. Cross-product scope bundles are rejected by
default. A read binary refuses a profile containing write/admin capabilities,
even if its token could technically call read endpoints. Google Ads additionally
requires a developer token secret and, for manager traversal, an explicit
`login-customer-id`; neither is accepted from GraphQL input.

### 6.3 Initial operation evidence matrix and schema baseline

This table is the complete initial reader schema baseline, not an illustrative
sample. A field absent from it is excluded until a reviewed evidence-matrix
amendment names its exact method, version, scope, quota dimensions, pagination,
data classification, and tests. Provider `POST` report methods remain logical
reads, but server-resource creation such as Analytics audience-export creation
is not in this initial baseline. Writer and admin mutation baselines are empty.

| GraphQL fields | Pinned provider methods | Scope/capability | Quota and pagination contract | Initial disposition |
|---|---|---|---|---|
| `googleAds.accessibleCustomers`, `googleAds.search` | Google Ads v25 `CustomerService.ListAccessibleCustomers`, `GoogleAdsService.Search` | `adwords`; reader; developer token and optional configured manager header | Developer-token operations plus customer request limits; GAQL `pageToken`; every follow-up request is separately reserved | Enabled; `SearchStream`, mutations, uploads, batch jobs, recommendations and billing are excluded |
| `adsense.accounts`, `adClients`, `adUnits`, `sites`, `policyIssues`, `payments`, `report` | AdSense v2 `accounts.list/get`, `accounts.adclients.list/get`, `accounts.adclients.adunits.list/get`, `accounts.sites.list/get`, `accounts.policyIssues.list/get`, `accounts.payments.list`, `accounts.reports.generate` | `adsense.readonly`; reader; payments are sensitive | Per-user/project request windows; `pageToken`; reports preserve the documented 100,000-row limit/truncation | Enabled; saved-report execution, ad code, alerts, channels and every inventory mutation require later field amendments |
| `admob.account`, `apps`, `adUnits`, `networkReport`, `mediationReport` | AdMob v1 `accounts.list/get`, `accounts.apps.list`, `accounts.adUnits.list`, `accounts.networkReport.generate`, `accounts.mediationReport.generate` | `admob.readonly`, or `admob.report` for report-only profiles | Separate account, inventory and reporting buckets; list `pageToken`; generated report stream | Enabled; all v1beta inventory, campaign-report and mediation-management methods excluded |
| `searchConsole.sites`, `searchAnalytics`, `sitemaps`, `urlInspection` | Search Console `sites.list/get`, `searchanalytics.query`, `sitemaps.list/get`; URL Inspection v1 `index.inspect` | `webmasters.readonly`; reader | Per-user/site/project and method load quotas; Search Analytics `startRow`/`rowLimit`; sitemap list has no invented cursor | Enabled; sitemap submit/delete and site add/delete excluded from reader and from initial mutations |
| `analyticsData.report`, `pivotReport`, `realtimeReport`, `metadata`, `compatibility` | Analytics Data v1beta `properties.runReport`, `runPivotReport`, `runRealtimeReport`, `getMetadata`, `checkCompatibility` | `analytics.readonly`; reader | Property/project token and concurrency buckets; `offset`/`limit`; quota metadata requested and preserved | Enabled; batch, funnel, audience-export and recurring-export methods require separate amendments |
| `analyticsAdmin.accountSummaries`, `account`, `properties`, `dataStreams`, `customDimensions`, `customMetrics`, `changeHistory` | Analytics Admin version-labelled v1beta methods `accountSummaries.list`, `accounts.get`, `properties.get/list`, `properties.dataStreams.get/list`, `properties.customDimensions.get/list`, `properties.customMetrics.get/list`, `accounts.searchChangeHistoryEvents` | `analytics.readonly`; reader | Admin read quota dimensions; `pageToken`; required parent/filter is binding-derived | Enabled as explicitly beta; alpha-only and link/access-binding fields excluded |
| `merchant.accounts`, `products`, `dataSources`, `productStatuses`, `quotaGroups` | Merchant API stable v1 `accounts.list/get/listSubaccounts`, `products.list/get`, `dataSources.list/get`, `aggregateProductStatuses.list`, `quotaGroups.list` in their named sub-APIs | `content`; reader policy | Method/user/account quota dimensions; provider `pageToken`; sub-API version retained in every cursor | Enabled only for stable v1 methods present in the release evidence snapshot; writes, issue-resolution actions and v1beta fallback excluded |
| `youtubeAnalytics.report`, `groups`, `groupItems` | YouTube Analytics v2 `reports.query`, `groups.list`, `groupItems.list` | Activity or separately isolated monetary scope; reader | Method quotas; reports `startIndex`/`maxResults`; groups use provider paging where documented | Enabled; group and item writes excluded |
| `youtubeData.channels`, `videos`, `playlists` | YouTube Data v3 `channels.list`, `videos.list`, `playlists.list` | API key for configured public-only bindings or `youtube.readonly` for private metadata | Method unit cost and `pageToken`; IDs are required and broad search is absent | Enabled; `search.list` and every mutation excluded |
| `tagManager.accounts`, `containers`, `workspaces`, `tags`, `triggers`, `variables`, `versions`, `environments`, `permissions` | Tag Manager v2 `accounts.list/get`, `accounts.containers.list/get`, `accounts.containers.workspaces.list/get`, `accounts.containers.workspaces.tags.list/get`, `triggers.list/get`, `variables.list/get`, `accounts.containers.versions.list/get`, `accounts.containers.environments.list/get`, `accounts.user_permissions.list/get` | `tagmanager.readonly`; reader | Project daily and QPS buckets; provider `pageToken` only where documented | Enabled; all edit, create-version, publish, delete, environment and permission mutations excluded |

The corresponding product REST reference, scope reference and quota reference
in section 5.1 are the authoritative evidence for each row; the version and
method names above are acceptance inputs, not deferred implementation choices.
The schema snapshot is generated directly from these field/method pairs. Each
implemented row also has a checked-in descriptor fixture containing those exact
official URLs, discovery/schema digest, service origin, HTTP template, response
type, scope, stability, quota keys/cost estimator, cursor binding and data class.
Implementation or release review disables a field rather than substituting a
new method or version when its contract no longer matches. The inventory in
section 5 describes later candidates; it does not broaden this baseline.

## 7. User-visible surface

The target unified business transport is one-shot GraphQL, matching
`mail-gateway`:

```text
google-marketing-gateway-reader graphql --query-file query.graphql --variables-file variables.json
google-marketing-gateway-reader download --key <opaque-key> --output <path>
google-marketing-gateway-writer graphql --query-file mutation.graphql --variables-file variables.json
google-marketing-gateway-admin graphql --query-file plan.graphql --variables-file variables.json
```

CLI commands cover `auth login/status/logout`, `config validate`, `doctor`,
`cache prune`, and schema/version inspection. Until the GraphQL surface is
implemented, completed reader slices may additionally expose closed, typed
business CLI routes backed by the same operation catalog, policy, validation,
credential resolver, and provider adapter that GraphQL will use. This is a
bounded transitional adapter, not an alternate arbitrary-request transport:
each route and flag must be named by its focused design and catalog descriptor,
and no route may accept a caller-selected origin, method, path, header, or raw
body. Search Console currently exposes exactly the six reader routes in
`design-docs/specs/design-search-console-reader.md`; writer and admin reject
them, and their mutation allowlists remain unchanged. Once a catalog operation
is available through GraphQL, CLI retention or removal requires an explicit
compatibility decision rather than creating a second behavioral contract.

Standard output is a single JSON result; logs go to standard error and never
contain tokens, headers, query bodies, report rows, or secret paths.

One-shot execution does not imply process-local business state. Plans, mutation
claims, receipts, provider jobs, materialized-result leases, and deduplication
records use a durable local store shared by all three executables. The GraphQL
surface exposes binding-scoped `jobStatus` and `jobResult` queries. Writer/admin
schemas may expose `cancelJob` mutations only for operation descriptors with
documented provider cancellation. Admin-only `mutationStatus` and
`resolveAmbiguousMutation` recovery fields accept typed provider evidence and
record an operator resolution without resending the request. `failed` is allowed
only after operation-specific conclusive negative evidence; an inconclusive
case stays blocked. Admin also exposes `resolveAmbiguousJobSubmission` for
recording typed provider lookup evidence and cleanup status without
resubmission. A separate audited `authorizeNewIntentAfterAmbiguity` break-glass
flow may permit a new, differently identified plan but never changes or reuses
the old token. Job cancellation is explicitly best effort, and a later provider
success remains observable.

GraphQL uses product namespaces (`googleAds`, `adsense`, `admob`,
`searchConsole`, `analyticsData`, `analyticsAdmin`, `merchant`,
`youtubeAnalytics`, `youtubeData`, `tagManager`). Each field maps to an
explicitly registered adapter operation and method-specific gateway types.
There is no generic `request(url:body:)` field and no untyped provider mutation.

Small metadata responses are inline. Row-oriented reports, `searchStream`, and
large paginated exports return `MaterializedResult` metadata with an opaque,
expiring `downloadKey`, checksum, media type, row count, truncation/warning
metadata, and lifecycle state. Local paths are disclosed only by `download`.

## 8. Configuration and data model

The default configuration is
`$XDG_CONFIG_HOME/google-marketing-gateway/config.toml`, overridable by
`--config` or `GOOGLE_MARKETING_GATEWAY_CONFIG`.

Core records are value types conforming to `Sendable`:

- `CredentialProfile`: ID, product, principal type, public client reference,
  immutable principal fingerprint, token-store slot reference, exact requested
  scopes, allowed capabilities, authorization epoch, token generation, active
  slot generation, and revocation/logout transaction state.
- `AccountBinding`: stable local ID, product, credential profile ID, provider
  account/property/customer resource name, optional manager parent, region,
  allowed resource prefixes, immutable revision and lifecycle state. IDs and
  revisions are never reused after disablement or deletion.
- `OperationDescriptor`: stable gateway operation ID, product, adapter version,
  logical capability, HTTP method/path template, required scopes, pagination
  style, idempotency class, freshness strategy, batch/partial-failure semantics,
  semantic-intent normalization, duplicate-risk horizon, allowed reconciliation
  evidence, output policy, and preview/stable state.
- `PageCursor`: authenticated opaque envelope containing operation ID and
  adapter-contract version, profile ID, principal fingerprint, authorization
  epoch, binding ID/revision, capability, normalized-filter digest, provider
  token/offset, state epoch, signing-key ID, and expiry. It never permits
  switching accounts, authorization, versions or filters.
- `MutationPlan`: operation, normalized redacted inputs, target fingerprint,
  expected version/ETag when supported, predicted effects, warnings, expiry,
  and single-use confirmation token.
- `MutationLedgerEntry`: versioned token and semantic-intent HMACs, immutable
  plan/input/binding/principal digests, state and version, claim owner/nonce/
  lease expiry/fencing generation, provider idempotency/request identifier when
  supported, typed reconciliation evidence, duplicate-risk horizon, and
  terminal operator resolution.
- `OperationReceipt`: correlation ID, provider request ID when returned,
  binding, operation, timestamps, outcome, retry count, quota observations,
  and redacted resource identifiers.
- `MaterializedResult`: owner profile/principal/authorization epoch and binding
  revision, capability, operation/adapter-contract version, state epoch,
  media type, byte/row limits, checksum, expiry, warnings, opaque download key,
  key version, renewable lease records, and narrowly scoped temporary-output
  cleanup records.
- `ProviderJob`: opaque job handle, owner binding/profile/principal,
  authorization epoch, binding revision, capability, state epoch, operation and
  adapter-contract version, provider
  resource or operation name, submitted input digest, provider/gateway state and
  monotonic record version, last/next poll times, submission/poll/cancel lease
  owner and fencing generation, expiry, result cursor/materialization reference,
  cancellation state, reconciliation horizon, and safe failure detail.
- `CredentialTransaction`: profile, operation (`login`, `refresh`, or `logout`),
  expected and candidate generations, immutable candidate slot nonce, state
  (`prepared`, `committed`, `cleanupPending`, or `complete`), and recovery audit.
- `QuotaReservation`: operation, documented quota-dimension key, window, cost,
  state (`reserved`, `committed`, `released`, or `expired`), owner/fence,
  provider correction, and concurrency-slot deadline.
- `StateEpochAnchor`: non-secret monotonic epoch stored outside SQLite and its
  backups, plus the active state-key generation and last accepted database ID.

Config contains references or paths, never secret values. Token stores,
developer tokens, client secrets, and service-account keys remain outside the
repository with user-only permissions. Environment or secret-manager overrides
win over TOML references. Service accounts are enabled only where the official
product supports them and the principal has been explicitly granted access;
domain-wide delegation is excluded by default.

## 9. State models and invariants

### 9.1 Authentication

`missing -> authorizing -> ready -> refreshing -> ready`

Any state may move to `invalid`, `revoked`, or `scopeMismatch`. Refresh is
single-flight across processes, not merely per actor. SQLite and the system
credential store are not assumed to share a transaction. Token bytes therefore
live in immutable generation-tagged secret slots; SQLite contains only the
active slot pointer and a recoverable `CredentialTransaction`.

Login and refresh use this protocol:

1. Acquire the exclusive profile lease and compare the authorization epoch and
   token generation. Write a new candidate secret slot containing authenticated
   profile ID, authorization epoch, next token generation and random slot nonce;
   never overwrite the active slot.
2. Read back and validate the candidate, then persist `prepared`. No operation
   can read a prepared candidate.
3. In one SQLite transaction, CAS the expected generation, change the active
   pointer to the candidate, and mark `committed`. Only this commit makes the
   slot readable by newly acquired operation leases.
4. Mark the prior slot for deletion, delete it best effort, and persist
   `complete`. A crash before step 3 leaves an unreachable candidate; a crash
   after step 3 leaves a harmless old slot. Startup reconciliation completes or
   removes only slots whose exact profile, epoch, generation and nonce match the
   transaction record. It never chooses a slot merely because it has the
   greatest generation.

Each operation first acquires a durable read lease bound to the authorization
epoch and active token generation, then loads only the exact committed slot and
rechecks the lease before transport. Refresh cannot commit while those leases
are active. Token generation may change on refresh without invalidating durable
result handles; authorization epoch changes on login as another principal,
scope/capability change, logout, or explicit credential reset and does
invalidate them.

Logout first installs a durable barrier that rejects new leases, then waits a
bounded period for existing leases. After optional provider revocation it commits
a permanent logout tombstone with a new authorization epoch and null active-slot
pointer before deleting any slot. Deletion is `cleanupPending`: after a crash,
startup observes the tombstone, denies token use, and deletes only its recorded
slots. A stale prepared refresh cannot CAS across the epoch. If leases do not
drain, logout returns `CREDENTIAL_BUSY` without committing the tombstone or
deleting token state and keeps the barrier closed until the operator cancels or
retries logout. Provider revocation failure is reported separately and never
causes local credentials to be represented as successfully revoked. There is no
unsafe forced-success or slot-discovery fallback. Reconciliation failure makes
the profile unavailable and `doctor` reports the safe next action;
`scopeMismatch` never triggers silent reauthorization or scope escalation.

### 9.2 Read/report operation

`received -> validated -> authorized -> executing -> paginating/materializing -> completed`

Terminal alternatives are `rejected`, `failed`, `cancelled`, or `expired`.
Quota exhaustion returns a terminal `QUOTA_EXHAUSTED` result containing a safe
`retryAfter`/reset hint; the v1 one-shot gateway does not claim that it queued or
will schedule deferred work. A provider stream that has emitted bytes is never
transparently retried; the partial artifact is quarantined and marked failed.

### 9.3 Mutation

`received -> validated -> planned -> confirmed -> claimed -> executing -> succeeded`

Alternatives are `rejected`, `planExpired`, `preconditionFailed`,
`providerRejected`, `ambiguous`, or `compensationRequired`. Writer operations
may combine plan and apply only when they are documented idempotent, reversible,
and non-destructive. Admin operations always require a fresh plan token.

Before any provider call, apply atomically changes the durable ledger entry from
`planned` to `claimed`, bound to the exact executable, credential, principal,
binding, operation, normalized input, plan token, short claim lease, random
owner nonce, and fencing generation. Provider transport is forbidden in
`claimed`. A live owner must atomically prove its unexpired lease and change
`claimed -> executing` before constructing the authorized request. An expired
`claimed` record may be reclaimed with a higher fencing generation because its
durable state proves transmission was forbidden; the former owner fails its
fence and cannot advance or transmit. A crash after the durable `executing`
transition is never reclaimable for replay. It is reconciled only through a
documented provider request ID, idempotency key, job/status read, or target-state
read. If no conclusive mechanism exists, recovery marks it `ambiguous`, keeps
the token consumed, and requires operator resolution; neither automatic nor
operator recovery can replay the original mutation.

Reconciliation evidence is an operation-specific tagged record such as a
provider request/job lookup, unique created-resource lookup, provider audit
event, or normalized post-state observation, including source, observation
window, timestamps, actor, correlation IDs, and redacted evidence digest.
`succeeded` requires conclusive positive evidence. `failed` requires conclusive
proof that the provider did not and can no longer apply the request throughout
the descriptor's reviewed duplicate-risk window; absence in an eventually
consistent list is never sufficient. Inconclusive entries remain `ambiguous`,
block the same semantic-intent digest, and retain a minimal non-secret tombstone
until conclusively resolved or the provider contract supplies a finite safe
horizon. If no finite horizon exists, the tombstone does not expire. Break-glass
authorization records a reason, operator, evidence, new intent nonce and audit
link; it creates a new plan and cannot relabel or reuse the ambiguous request.

### 9.4 Async provider jobs

`created -> submitting -> submitted -> pending -> running -> succeeded | failed | cancelled | expired`

Alternatives are `ambiguousSubmission` and `cancellationRequested`; neither is
terminal and ordinary retention never closes or removes it.

The gateway persists and atomically claims `created` with a short lease and
fence; provider transport is forbidden in `created`, so an expired pre-submit
claim can be reclaimed and the stale owner fenced. It then durably records
`submitting` before transmission and the provider job name before returning the
handle. A crash in `submitting` never causes resubmission:
documented provider lookup/reconciliation may recover the job name; otherwise
the handle becomes `ambiguousSubmission` for operator resolution and possible
provider-side cleanup. Each handle is bound to
the originating profile, principal and account binding; cross-profile access is
denied. Later one-shot calls use `jobStatus`, bounded `jobResult` pagination, and
`cancelJob`. Each status poll or cancellation attempt transactionally acquires a
short lease and fencing generation; another caller receives the stored state
and retry time rather than contacting the provider. Responses update the record
only if their fence and expected record version still match. Terminal provider
states are monotonic, a confirmed success or failure overrides a prior local
`cancellationRequested`, and a stale response cannot regress state. Polling
respects stored `nextAllowedPollTime`, provider `Retry-After`, per-operation poll
limits and handle expiry. Local cancellation records `cancellationRequested`;
it becomes `cancelled` only when the provider confirms cancellation. Otherwise
the job may still become `succeeded` or `failed`. Process restart resumes by
reading the durable handle, not by resubmitting. Expiry stops ordinary polling
and download access, but an unresolved submission or cancellation retains a
minimal tombstone and remains available to explicit admin reconciliation.
Cleanup removes only conclusively terminal jobs after retention and never
implies provider resource deletion. Unsupported provider cancellation returns
`CANCELLATION_UNSUPPORTED` without changing provider state.

### 9.5 Invariants

- The executable capability, operation registry, credential capability, OAuth
  grants, provider-side role, and account binding must all authorize an action.
- Account and resource identifiers come from a configured binding or validated
  child resource; callers cannot cross bindings by editing provider paths.
- No adapter follows redirects to an unapproved host or sends authorization
  headers outside its fixed official origin.
- Pagination cursors and all durable handles cannot be replayed with different
  filters, profiles, principals, authorization epochs, binding revisions,
  capabilities, state epochs or adapter contracts.
- Output byte/row/time limits are checked before and during retrieval.
- No automatic retry occurs for an ambiguous mutation. Provider-supported
  request IDs, version numbers, ETags, or local request deduplication are used
  where the documented contract permits.
- Single-use plan enforcement, mutation deduplication, job ownership and file
  leases are interprocess invariants, not actor-local state. The durable store
  uses transactional compare-and-set claims, cross-process locking, crash-safe
  commits and schema migrations; an unavailable or corrupt store fails closed
  before a mutation or job submission.
- A target reread is advisory and never closes the time-of-check/time-of-use
  window. High-risk updates and deletes require a provider-enforced conditional
  mutation, a provider transaction that includes the condition, or documented
  operation semantics that cannot overwrite concurrent changes. Otherwise the
  operation is excluded. Lower-risk operations may use an immediate normalized
  reread only after focused review establishes idempotency, bounded impact and a
  safe conflict outcome; any mismatch or inconclusive read fails closed.
- Monetary, access-control, and user-level report data are never merged with a
  less-privileged profile or cached beyond its configured retention.

### 9.6 Durable-handle authorization and configuration lifecycle

Profile and binding edits create new immutable revisions; disabling or deleting
a record writes a tombstone and never reuses its ID. Ordinary cursor, download
and job access requires an exact match of profile ID, principal fingerprint,
authorization epoch, binding ID/revision, capability and adapter-contract
version. A token refresh alone preserves the authorization epoch. A principal,
scope, capability, resource-prefix, manager-parent or provider-resource change
does not. Mismatch returns `HANDLE_STALE` before provider or file access.

A disabled binding may expose only redacted local status. It cannot paginate,
download or contact Google. Admin recovery may inspect safe tombstone metadata
and attach typed evidence, but cannot reassign a handle or recover data through
another credential. Old adapter contracts remain installed until all conclusive
handles expire; if security or provider removal requires immediate disablement,
handles return `ADAPTER_VERSION_UNAVAILABLE` and unresolved jobs move to explicit
admin reconciliation without interpreting old provider tokens. Key loss or an
unknown format similarly fails closed. This lifecycle is tested for edit,
disable, delete, recreate-with-same-provider-resource, logout, scope change,
adapter upgrade/downgrade and state restore.

### 9.7 Digest construction and key lifecycle

Plan-token, semantic-intent, input, binding, principal, cursor and download-key
digests use versioned deterministic canonical serialization. Object keys sort by
UTF-8 byte order; numbers, timestamps, Unicode, absent values, nulls, sets and
ordered lists have descriptor-defined canonical forms; unknown or duplicate
fields are rejected rather than normalized heuristically. The descriptor's
normalization version and operation/adapter contract are included in the bytes.

Stored indexes use domain-separated HMAC-SHA-256, never an unkeyed hash of
low-entropy identifiers or intent. Purpose keys are derived from a system-
credential-store master using HKDF and include state epoch, key generation and
purpose in the domain. Equality is constant-time. Active records retain sealed
canonical bytes so an HMAC match is confirmed byte-for-byte; after reduction to
a minimal tombstone, a match conservatively blocks the intent. Any impossible
same-HMAC/different-bytes observation returns `DIGEST_COLLISION`, performs no
transport, preserves both audit records and requires key rotation.

Rotation makes a new generation active but retains every verification key still
referenced by a plan, handle, ledger entry or correctness tombstone. New intents
are checked against all retained semantic-intent generations before insertion;
keys are pruned only after the final reference and safe horizon disappear. If a
required verification key is unavailable, affected handle access fails and new
mutation planning for that descriptor fails `STATE_KEY_UNAVAILABLE`; reads that
do not consume durable keyed state may continue. Generating a replacement key
never makes old state valid: the operator must advance the state epoch and
invalidate dependent cursors/plans/leases while preserving unresolved mutation
and job records for reconciliation.

## 10. Transport and concurrency architecture

`GoogleMarketingGatewayCore` owns configuration, GraphQL, authorization policy,
operation registry, errors, receipts, and materialization. Each product adapter
owns its official REST DTOs and mappings. Target boundaries remain within the
package unless build time or responsibility size proves a split necessary.

Injected protocols include `HTTPTransport`, `TokenProvider`, `Clock`,
`Sleeper`, `RandomSource`, `FileStore`, `ReceiptStore`, and one adapter protocol
per product. Production transport uses `URLSession`; tests use scripted actors.
Request and response DTOs are `Sendable` value types. Mutable token, quota,
and in-process request state is isolated in actors, but actors are only local
caches. Durable deduplication, quota reservations, plan,
job, receipt, and lease records live in a transactional interprocess store; an
actor serializes each process's access but is not treated as a cross-process
lock. The initial implementation uses an embedded SQLite state database in the
user-only state directory, WAL journaling, full synchronous durability, busy
timeouts, and transactionally enforced unique token/job keys. Mutation claims
use `BEGIN IMMEDIATE` plus compare-and-set state transitions; processes that
cannot acquire the bounded lock return `STATE_STORE_BUSY` without transport.
Schema migration backs up and integrity-checks the database before replacement;
failed integrity checks make mutations, submissions and pruning fail closed.
Credential generations, active-operation leases, refresh ownership and logout
barriers also live in this store, while secret bytes remain in the system
credential store. Every lease-based transition uses a random owner nonce,
expiry, record version and monotonically increasing fence; an expired owner
cannot commit a response after another process acquires the next fence.
No shared mutable globals, unchecked `Sendable`, detached tasks, or callback
state crosses concurrency boundaries.

Each `OperationDescriptor` declares every documented quota dimension and cost
estimator: project/developer token, OAuth client, principal/user, binding or
provider account/site/property, method/quota category, QPS window, daily window,
and provider concurrency bucket as applicable. Absence of an applicable
dimension is explicit; it is never inferred as unlimited. Before transport, a
process transactionally reserves the conservative request cost in every key.
`reserved` forbids transport. The owner must commit the reservation immediately
before sending; once `committed`, it counts until its quota window resets even if
the process crashes or the network outcome is unknown. An uncommitted expired
reservation may be released with a fence. Concurrency slots use the same fence
but expire only after the bounded request deadline; pagination and retry reserve
each provider request independently.

Provider quota metadata, `Retry-After`, and definitive rejected-before-execution
responses transactionally correct future availability without retroactively
claiming uncertain committed cost was unused. A server block sets a shared
not-before time for the exact dimension. Local wall-clock rollback freezes new
reservations until the last durable time is reached or an audited clock recovery
advances the window; monotonic time governs in-process deadlines. If the quota
store is busy or invalid, an operation requiring a shared reservation fails
`STATE_STORE_BUSY` or `STATE_STORE_INVALID` before transport. Runtime config may
lower, never raise beyond the reviewed provider budget without an explicit
override. This coordination reduces avoidable throttling but does not promise
unused capacity or supersede Google enforcement.

The transport fixes scheme/host per adapter, builds paths from encoded resource
components, sets bounded timeouts, validates content type and size, and redacts
headers. It decodes the Google JSON error envelope plus product-specific error
details. Streaming adapters expose back-pressured `AsyncSequence` data and write
incrementally to a temporary file before atomic promotion.

Retries use bounded exponential backoff with full jitter and `Retry-After` when
present. They apply to idempotent reads and explicitly safe provider operations
for 429 and selected transient 5xx responses. Auth refresh may replay a request
once after a 401 only when the operation's idempotency class permits it.

## 11. Validation, errors, and pagination

Validation is layered: GraphQL shape, normalized semantic constraints,
operation policy, binding/resource containment, scope/capability, provider
preconditions, and output limits. Dates, time zones, currencies, GA metric and
dimension compatibility, GAQL text, report row limits, Merchant product keys,
and YouTube report combinations retain provider rules; the gateway does not
silently repair a semantically different request.

The public error envelope contains a stable gateway code, safe message,
product, operation, retryability, correlation ID, optional provider request ID,
field violations, quota metadata, and partial/ambiguous state. Required codes
include `INVALID_ARGUMENT`, `UNAUTHENTICATED`, `SCOPE_MISMATCH`,
`PERMISSION_DENIED`, `CAPABILITY_DISABLED`, `RESOURCE_OUT_OF_SCOPE`,
`PRECONDITION_FAILED`, `CONFLICT`, `QUOTA_EXHAUSTED`, `RATE_LIMITED`,
`PROVIDER_UNAVAILABLE`, `RESPONSE_TOO_LARGE`, `PARTIAL_RESULT`,
`AMBIGUOUS_MUTATION`, `AMBIGUOUS_JOB_SUBMISSION`, `CANCELLATION_UNSUPPORTED`,
`CREDENTIAL_BUSY`, `STATE_STORE_BUSY`, `STATE_STORE_INVALID`, `HANDLE_STALE`,
`ADAPTER_VERSION_UNAVAILABLE`, `STATE_KEY_UNAVAILABLE`, `DIGEST_COLLISION`, and
`INTERNAL`. Raw bodies and
secrets are excluded.

Provider page tokens remain opaque. Connection cursors bind them to normalized
input and expire. Offset APIs expose a gateway cursor rather than encouraging
unbounded offsets. Every list/report accepts a gateway maximum; auto-pagination
is opt-in, bounded by pages, rows, bytes, time, and quota budget.

## 12. Permissions and mutation safety

Reader schemas physically omit `Mutation`. Writer and admin schemas are built
from separate compile-time operation allowlists. Runtime checks still enforce
the complete permission intersection. This provides defense in depth when a
provider has one broad OAuth scope, notably Google Ads and Merchant API.
The initial writer and admin mutation allowlists are empty. A mutation field may
be added only by a focused design amendment and evidence-matrix entry that names
the exact provider method/version, input fields, scope, capability tier,
freshness and concurrency mechanism, idempotency/reconciliation behavior,
batch semantics, rollback class, audit fields, and contract tests. Documentation
that a provider method exists is not permission to expose it.

Mutation inputs support provider preconditions where documented. Destructive,
publishing, identity, access, account, property, site-association, and
irreversible acknowledgement operations use plan/apply. Plans expire quickly,
are bound to the same executable, credential, account, normalized input, and
provider-enforced precondition where required, and are consumed once. A changed
target causes `PRECONDITION_FAILED`; the gateway never silently replans.

Rollback is provider-specific and never promised generically. A plan records
one of `reversible`, `compensatable`, `softDeleteOnly`, or `irreversible` and the
documented recovery path. The gateway stores receipts but not secret or full
resource snapshots.

Every allowlisted batch descriptor declares provider atomicity, partial-failure
support, item dependency rules, maximum item count, ordering semantics, and
retry policy. The conservative default disables provider partial-failure mode:
all items must validate and the provider must offer atomic execution. Where a
focused operation review enables partial failure, each input requires a unique
caller item ID and retains its original index; empty items, duplicate IDs,
conflicting changes to one target, invalid temporary references, dependency
cycles, and unsupported out-of-order dependencies are rejected before
transport. Receipts record each item as succeeded, failed, skipped, or ambiguous
and preserve provider result order mapping. A retry is a new plan containing
only previously failed items; succeeded or ambiguous items cannot be copied into
an automatic retry. Failed multi-step workflows stop at the first unexecuted
step and report every completed or unknown step; v1 does not claim distributed
transactions.

## 13. Lifecycle, compatibility, and migration

- The placeholder executable remains only as a deprecation shim for one release
  and directs users to capability-specific binaries; it performs no business
  operation.
- Config schema and download-key formats are versioned. Migration is explicit,
  makes a backup, validates before replacement, and is reversible until the old
  version is removed under the retention policy. A global migration lease blocks
  all writers, job transitions, auth changes and pruning; readers either use the
  proven compatible schema or fail busy. The owner-only backup contains no token
  or artifact bytes, is integrity-checked before use, and is removed no later
  than 24 hours after the new schema passes startup health checks.
- A non-secret `StateEpochAnchor` lives in a user-only system-credential-store
  entry that is never included in SQLite backups. Every database, cursor, plan,
  claim, lease, job and keyed state record carries that epoch. Normal startup
  requires the database epoch and database ID to equal the anchor. An absent,
  older, newer or duplicated anchor/database pairing fails closed; the gateway
  does not select the newest-looking file automatically.
- Restore is an explicit offline admin action. Before opening restored state, it
  CAS-advances the external anchor to a new epoch and records a recovery nonce;
  failure to advance aborts restore. The restored database is copied under the
  new epoch only after integrity validation. Old plans, cursors, download keys,
  quota leases and pre-transmission claims are invalidated. Executing/ambiguous
  mutations, submitted/ambiguous jobs, logout tombstones and semantic tombstones
  are imported as blocked reconciliation records with new local fences and can
  never be replayed. Credential active-slot pointers are not accepted from the
  backup; every restored profile becomes `reauthorizationRequired`, and old
  secret slots remain unreadable under the new epoch until exact-slot cleanup.
  No restored operation can authenticate with a pre-restore token. A crash
  during restore leaves the advanced
  anchor in `restorePending`, so ordinary startup remains closed until the exact
  recovery nonce is completed or an audited empty-state recovery is selected.
  The prior epoch is permanently rejected even when the live database was lost
  or corrupt. If the anchor itself is lost, recovery creates a fresh epoch and
  invalidates all replayable state rather than trusting a backup generation.
  If neither live state nor a verified backup preserves unresolved semantic/job
  tombstones, all mutation and provider-job submission stays globally disabled.
  An audited disaster-recovery action may re-enable only an operation whose
  documented duplicate-risk horizon has conclusively elapsed; operations with
  no finite horizon remain blocked. Read-only calls may continue after fresh
  authentication.
- Provider API upgrades are isolated per adapter. Preview/alpha methods never
  share a stable schema field without a stability marker and feature flag.
- Expired downloads and receipts are pruned by explicit policy. Partial files
  are quarantined then removed; successful promotion is atomic.
- Default retention is 24 hours for ordinary materialized reports, one hour for
  monetary, access-control, user-level and audience-export artifacts, one hour
  for failed/partial temporary files, ten minutes for unclaimed plans, and 30
  days for redacted receipts, consumed-token digests, mutation ledger entries
  and conclusively terminal job metadata. Unresolved mutation/job tombstones are
  minimal, contain only digests and safe audit metadata, and survive ordinary
  pruning until conclusive resolution or an operation-specific finite duplicate-
  risk horizon; they are indefinite when no safe horizon is documented.
  Configuration may shorten ordinary artifact values but never a correctness
  tombstone below its reviewed safe horizon. Increasing
  them requires an explicit per-artifact override that `config validate` labels
  as privacy-sensitive and records for later product-owner review.
- Materialized report bytes are encrypted with authenticated per-artifact keys
  wrapped by a local master key held in the system credential store. Cache and
  state directories are user-only and files are owner-readable/writable only;
  redacted receipts never contain report rows, user identifiers or mutation
  bodies. A missing encryption key makes the artifact unavailable and eligible
  for safe cleanup, never plaintext recovery.
- Download atomically acquires a renewable durable lease with an owner nonce,
  fence, short expiry and bounded renewal before expiry validation, and releases
  it after checksum verification. Pruning skips live leases; it may reclaim an
  expired lease only by incrementing the fence, after which the stale downloader
  cannot promote output or update state. Output creation refuses an existing
  destination, symlinks and
  non-regular targets, creates a user-only temporary file in the destination
  directory without following links, fsyncs it, and uses an atomic no-replace
  promotion so a concurrent creator cannot be overwritten. Before writing, the
  gateway persists a cleanup record containing only the canonical parent,
  randomized basename, file identity, owner nonce and creation time. Cleanup
  removes an expired temporary file only when that exact record, parent, regular-
  file identity, owner-only mode, link count and age still match; otherwise it
  quarantines the record and reports operator action. A crash leaves this
  narrowly identifiable user-only temporary file for bounded cleanup;
  plaintext is never staged in the shared cache.
- OAuth logout uses the durable credential barrier in section 9.1. It deletes
  the selected token only after active-operation leases drain and generation
  advancement commits, and never removes an unrelated credential profile.
- Cache and receipt format changes use additive migration first. A downgrade
  must refuse unknown newer formats instead of corrupting them.

## 14. Observability and privacy

Every operation has a locally generated correlation ID and captures provider
request IDs such as Google Ads `request-id` when available. Structured logs
include product, operation ID, adapter version, binding alias, duration, status,
retries, pages, row/byte counts, quota observations, and materialization state.
They exclude OAuth/client/developer tokens, authorization headers, request and
response bodies, GAQL text by default, customer-provided values, email/phone
identifiers, local secret paths, and monetary/report rows.

State recovery logs additionally record non-secret state epoch, database ID,
credential transaction state, slot-generation/nonce digest, quota dimension,
reservation state, handle contract/revision, key generation and recovery action.
They never record token bytes, raw canonical intent, HMAC keys or unredacted
principal/resource values. Audit events are emitted for restore epoch changes,
credential reconciliation, stale-handle denial, quota clock recovery, key
rotation/loss, digest collision and every fail-closed administrative override.

`doctor` checks config structure, file permissions, API enablement symptoms,
credential state, granted-vs-required scopes, fixed origins, writable cache,
clock skew, and binding access using minimal documented read calls. It does not
perform mutations. Metrics are local by default; telemetry export is opt-in and
must use the same redaction model.

## 15. Edge cases

- A token is valid but lacks a newly required scope: return `SCOPE_MISMATCH` and
  an explicit reauthorization action; never broaden automatically.
- The same Google identity has many manager/customer/property accounts: require
  a configured binding and never select the first account implicitly.
- Google Ads manager traversal lacks or mismatches `login-customer-id`: reject
  before business execution when detectable; preserve provider request ID.
- A report is truncated, sampled, thresholded, contains incompatible fields, or
  has partial current-day data: preserve provider metadata and warnings.
- Quota changes after release: use provider responses/configurable limiters;
  numeric design values are not hard-coded as eternal constants.
- Concurrent processes approach a shared quota: reserve every documented
  dimension transactionally; a committed request remains charged after crash,
  while an expired pre-transmission reservation is safely released.
- A page token expires or input changes: fail the cursor; never restart silently
  because doing so can duplicate rows.
- A write times out after request transmission: mark `AMBIGUOUS_MUTATION`, check
  documented idempotency/status mechanisms, and require operator resolution.
- A process crashes while holding a pre-transmission mutation claim: reclaim
  only after lease expiry with a higher fence; the stale owner cannot transmit.
- A semantically equivalent plan follows an ambiguous mutation: reject it while
  the correctness tombstone remains, unless audited break-glass creates a new
  intent without reusing or resolving the old one.
- Refresh, business use, and logout race across processes: immutable secret slots
  plus recoverable credential transactions prevent stale replacement and make
  logout wait or fail busy. Startup resolves every incomplete transaction before
  issuing a token.
- A binding, principal, scope or adapter changes while a cursor, download or job
  exists: exact revisions reject ordinary access; no handle is silently rebound.
- SQLite is lost and an old backup is restored: the external state epoch advances
  first, invalidates replayable records, and imports unresolved work only as
  blocked reconciliation state.
- A semantic HMAC key is rotated or lost: all retained generations participate
  in duplicate checks; loss fails affected mutation planning closed rather than
  treating old tombstones as absent.
- Poll and cancellation responses arrive out of order: fenced record versions
  reject stale responses and provider-confirmed terminal state stays monotonic.
- A downloader dies while pruning waits: the expired lease is fenced before
  reclamation, and cleanup touches only the persisted exact temporary-file identity.
- Merchant writes are accepted but processing is delayed: return accepted state
  and a resource/job handle; do not claim the processed product is ready.
- A GraphQL request aliases the same expensive field repeatedly: complexity,
  depth, row, byte, and per-operation count budgets reject it before transport.
- A download key belongs to another profile, is expired, or its checksum fails:
  deny access and quarantine the artifact.
- A service account is syntactically valid but has no product-side role: report
  `PERMISSION_DENIED`, not an authentication retry loop.
- An official API is deprecated or an alpha contract changes: disable that
  adapter version with a clear compatibility error; never fall back to scraping.

## 16. Design-level verification strategy

1. Treat section 6.3 as the checked schema baseline. Snapshot every named field
   and descriptor fixture and prove that its exact method/version, official
   reference, scope, stability, quota dimensions/cost, pagination, data class,
   idempotency and error mapping agree. Prove every unlisted field and every
   mutation is absent.
2. Generate or hand-model minimal DTO fixtures only from pinned official REST
   discovery/reference contracts; retain unknown enum values without crashing.
3. Unit-test URL/path encoding, fixed-host enforcement, headers, scope policy,
   cursor binding, plan expiry, redaction, retry classification, pagination, and
   byte/row limits with injected clocks and transports.
4. Contract-test each adapter against recorded sanitized fixtures for success,
   pagination, empty results, 4xx error details, 401 refresh, 403 permission,
   429 quota, 5xx retry, malformed JSON, oversized response, and partial stream.
5. Crash-test the durable state store at every mutation transition, race two
   apply processes for one token, and prove only one provider request is sent.
   Kill an owner in mutation `claimed` and job `created`, reclaim with a higher
   fence, and prove the stale owner cannot transmit. Test store
   corruption/unavailability, external-anchor loss, restore crash at each epoch
   transition, rejection of an old database after live-state loss, typed
   ambiguous evidence, semantic-intent blocking, indefinite/finite tombstones,
   break-glass authorization, token expiry, provider precondition failure, and
   rejection of high-risk operations with only a target reread.
6. Contract-test every enabled batch mode for empty/duplicate/conflicting and
   dependency-ordered inputs, provider atomic failure, partial item outcomes,
   stable result mapping, and retry exclusion of succeeded/ambiguous items.
7. Restart-test job submission/status/result/cancellation, race poll and cancel
   callers, reject stale fenced responses, enforce monotonic terminal states,
   and cover cancellation races where the provider succeeds. Race refresh,
   operations and logout across processes and verify every credential prepare,
   pointer-commit, tombstone and slot-cleanup crash boundary. Prove an orphan
   candidate is never selected and committed logout cannot resurrect a token.
   Test renewable download/prune leases, stale-owner fencing, expired keys,
   encryption-key loss, symlink/existing-output refusal, exact file-identity
   crash cleanup, correctness tombstones and configured retention. Test profile/
   binding edit-disable-delete-recreate and adapter upgrade against every handle.
8. Race quota reservations across processes for every documented dimension.
   Test uncommitted expiry, crash after commit, concurrency-slot timeout,
   multi-page cost, retry cost, `Retry-After`, provider corrections, state-store
   busy, and wall-clock rollback without exceeding the configured budget.
9. Test canonical intent vectors across processes and releases, including key
   order, Unicode, numeric forms, null/absent values, duplicate fields and
   descriptor-version changes. Rotate keys with live finite and indefinite
   tombstones, simulate a missing retained key, and inject a synthetic digest
   collision; each unsafe case must fail before transport.
10. Schema-snapshot all three binaries and prove reader has no mutation fields,
   writer lacks admin fields, and every field maps to one registered operation.
11. Run concurrency stress tests under Thread Sanitizer where feasible and Swift
   6 strict concurrency compilation without unchecked escapes.
12. Run opt-in live smoke tests only against dedicated test accounts/properties,
   defaulting to reads. Mutation smoke tests require disposable resources and
   verify cleanup/receipts; they are never part of ordinary CI.
13. Run secret/path scanning before commit, SwiftLint after Swift edits, focused
   tests per adapter, then full `mise run lint`, `mise run test`, and build.
14. Recheck official docs at implementation start and release time. A doc diff
   blocks release when scopes, versions, fields, quotas, or mutation semantics
   changed without review.

## 17. Prioritized delivery slices

1. **Foundation:** rename core, add reader executable, config/auth state,
   operation registry, injected URLSession transport, errors, GraphQL one-shot,
   durable interprocess store, immutable credential-slot transactions, external
   state epoch, keyed canonical digests, shared quota reservations, versioned
   handles, receipts, encrypted materialization, leases, and policy/crash tests
   with no live product mutations.
2. **Primary acquisition reporting:** Google Ads read and Analytics Data read,
   including bounded pagination/export and quota observations.
3. **Commerce and publisher reporting:** Merchant read, AdSense read/report,
   AdMob read/report, and cross-product binding metadata without data merging.
4. **Organic/video reporting:** Search Console read/inspection, YouTube
   Analytics reports, and ID-targeted YouTube Data metadata.
5. **Configuration readers:** Analytics Admin and Tag Manager read surfaces.
6. **Writer:** focused amendments may enable narrow Google Ads status/budget,
   Merchant product and inventory, AdSense inventory, Search Console sitemap,
   YouTube group, Analytics stable config, and Tag Manager workspace mutations
   with plan/receipt tests.
7. **Admin:** separately reviewed amendments may enable fields for access,
   destructive actions, publishing, and account/site/property administration.
   High-risk Google Ads
   billing/access and GA user-deletion operations stay excluded until a focused
   design amendment accepts them.

Each slice updates the evidence matrix and may ship independently. Writer/admin
shipping with an empty mutation schema is valid until the required amendments
are accepted. No slice is allowed to broaden scopes merely to simplify
implementation.

## 18. Cross-feature and compatibility impacts

- Binary naming changes `Package.swift`, Homebrew formula/cask contents, README,
  command tests, and downstream automation; the shim and release notes must make
  the migration explicit.
- Shared credential, quota, cursor, materialization, receipt, and error models
  affect every product adapter and must stabilize before parallel product work.
- Durable claims/jobs and encrypted retention affect every executable, state
  migration, cache/download command, backup policy, and operator recovery flow.
- Immutable credential slots and the external state epoch affect authentication,
  system credential-store layout, restore, downgrade, `doctor` and disaster
  recovery; neither may be replaced with cross-store atomicity assumptions.
- Shared quota reservations affect every adapter, page/retry loop and concurrent
  executable. Durable-handle revisions affect configuration editing, logout,
  adapter upgrades, materialization and job recovery.
- The keyed canonical-digest contract affects plan confirmation, ambiguity
  blocking, state-key rotation, backups, privacy and correctness tombstones.
- Analytics Admin links intersect Google Ads, AdSense, DV360, and Search Ads 360;
  this gateway may report links but must not imply it manages an excluded linked
  product.
- Merchant products feed Google Ads shopping campaigns, but a successful
  Merchant write does not imply Ads eligibility or campaign activation.
- AdMob and Firebase-derived analytics can appear in GA access reports; the
  gateway preserves source metadata and does not deduplicate product reports.
- YouTube monetary scopes increase data sensitivity and cannot be folded into
  the ordinary activity-report credential silently.
- Tag Manager publishing affects production measurement and therefore remains
  admin even though workspace edits are writer operations.

### 18.1 Architectural comparison with `mail-gateway`

| Concern | Reused reference pattern | Marketing-specific change |
|---|---|---|
| Core/package shape | Shared Swift core plus thin capability executables | Three risk tiers replace mail's reader/draft/sender semantics |
| Business transport | One-shot GraphQL is the target unified surface | Completed slices may use closed typed CLI routes as transitional adapters over the same catalog and policy; Search Console has exactly six reader routes, with no arbitrary provider passthrough |
| Large/private payloads | Opaque download keys and explicit file download | Reports, streams and exports replace message bodies and attachments; row, byte, quota and warning metadata are mandatory |
| Credentials | Independent profiles, local token stores and explicit account selection | Profiles are additionally isolated by product and capability because Google marketing scopes and account hierarchies vary widely |
| Provider boundary | Injected provider adapters behind canonical gateway policy | Provider resource types remain product-specific instead of being forced into one universal marketing model |
| Write safety | Reader rejects mutations before resolver dispatch | Writer/admin schemas are separately allowlisted, with plan/apply for publishing, identity, destructive and ambiguous operations |
| Extensibility | New providers fit behind the shared core | New Google products require an evidence matrix entry, official scope/contract review, and explicit entitlement/stability classification |

The gateway intentionally does not copy mail-specific assumptions such as a
single Gmail provider, draft-before-send semantics, or attachment roots. It
copies the security and testability boundaries while adapting the capability
model to heterogeneous marketing APIs.

## 19. Provisional decisions

The complete rationale and later review actions are recorded in
`design-docs/user-qa/pending-google-marketing-gateway-decisions.md`.

1. Use product-specific credential profiles rather than one all-Google token.
2. Ship one-shot GraphQL and file materialization before any daemon mode.
3. Use reader/writer/admin executables and gateway policy where Google scopes
   cannot express the separation.
4. Include Tag Manager and ID-targeted YouTube Data metadata; defer other
   enterprise marketing APIs.
5. Exclude generally available Google Trends support; do not scrape; require a
   separate opt-in design if alpha access is obtained.
6. Require plan/apply for all admin operations and ambiguous high-risk writes.
7. Use installed-app OAuth as the default local flow, allowing service accounts
   only per product and explicit provider-side grants.
8. Apply explicit short retention windows, encrypted materialization, safe
   no-follow downloads and durable download/prune leases as described in section
   13; longer retention requires an explicit reviewed override.
9. Use an embedded, user-local durable state database for cross-process plans,
   claims, jobs, receipts and leases; do not introduce a daemon merely to hold
   correctness state in memory.
10. Start with empty writer/admin mutation allowlists; enable each exact mutation
    only through a focused reviewed amendment and evidence-matrix entry.
11. Start with exactly the reader operation matrix in section 6.3; add or
    reprioritize fields only through an operation-level reviewed amendment.

## 20. Residual risks and open review items

- Google APIs, versions, preview status, quotas, and scopes change. Official
  references must be reverified at implementation and release boundaries.
- Google Ads and Merchant scopes are broader than the gateway roles; executable
  schema separation and operation policy reduce but cannot eliminate damage if
  credentials are used outside the gateway.
- Some products require developer tokens, account approval, OAuth verification,
  organization roles, or alpha/enterprise entitlement that automated tests
  cannot create.
- Provider idempotency and concurrency controls vary. Operations lacking a safe
  retry/precondition mechanism remain excluded even when a target reread appears
  stable.
- Initial mutation allowlists are explicitly empty. Product-owner priorities and
  focused operation amendments determine which mutations are later enabled.
- Retention windows are provisional but explicit. Product-owner review may
  shorten them or approve per-product increases; migration never extends
  already-created artifacts silently.
- Three deep-review rounds identified five high and thirteen middle findings.
  This revision additionally specifies recoverable cross-store credential
  commits, a non-rollbackable restore epoch, an exact initial operation matrix,
  interprocess quota reservations, authorization/version-bound handles and
  rotation-safe keyed canonical digests. Deep re-review plus broad, adversarial,
  and consistency reviews remain mandatory before design acceptance.
