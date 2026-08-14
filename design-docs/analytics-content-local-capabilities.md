# Analytics, Content, and Local Operations

**Status:** Feature-local design update for issue-resolution branch
**Feature ID:** `analytics-content-local`
**Feature title:** Analytics, Content, and Local Operations
**Issue reference:** `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Workflow mode:** `issue-resolution`
**Author verification date:** 2026-08-14
**Implementation plan:** `impl-plans/analytics-content-local-capabilities.md`

## 1. Purpose

This document defines the gateway coverage plan for analytics, content, search,
measurement-clean-room, and local operations APIs that are adjacent to paid
media account management:

- Google Analytics Admin API;
- Google Analytics Data API;
- Google Tag Manager API v2;
- YouTube Data API v3;
- YouTube Analytics API v2;
- Search Console API and URL Inspection API;
- Ads Data Hub API;
- Business Profile APIs;
- Local Services Ads API.

The design advances official API coverage without claiming complete method-level
implementation. It preserves capability-separated reader, writer, and admin
binaries; product-isolated OAuth profiles; fixed official origins; bounded
request-file handling; sanitized errors; and explicit representation of beta,
allowlisted, deprecated, restricted, or non-public surfaces. It does not use
unofficial scraping endpoints.

## 2. Current Repository Findings

The repository already contains a bounded reader foundation for part of this
feature area.

| Surface | Current file paths | Current status |
|---|---|---|
| Analytics Data API v1beta | `Sources/GoogleMarketingGatewayCore/AnalyticsDataRequests.swift`, `Tests/GoogleMarketingGatewayCoreTests/NewReaderRequestTests.swift`, `Tests/GoogleMarketingGatewayCoreTests/NewReaderCLITests.swift` | Implemented reader request builders and CLI routing for metadata get, run report, and compatibility check with fixed `https://analyticsdata.googleapis.com` origin and exact `analytics.readonly` scope. |
| Search Console and URL Inspection | `Sources/GoogleMarketingGatewayCore/SearchConsoleRequests.swift`, `Sources/GoogleMarketingGatewayCore/SearchConsoleModels.swift`, `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestTests.swift`, `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleCLITests.swift`, `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestFileTests.swift` | Implemented reader request builders and CLI routing for sites, search analytics, sitemaps, and URL inspection with fixed `https://www.googleapis.com` origin and exact `webmasters.readonly` scope. |
| Operation catalog | `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` | `MarketingProduct` already includes `analytics-admin`, `analytics-data`, `youtube-analytics`, `youtube-data`, `tag-manager`, and `search-console`; implemented operations exist only for Analytics Data and Search Console in this feature area. |
| Credential profiles | `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift` | Reader profile validation accepts exact reader scopes for `analytics-data` and `search-console`. Other products currently have no accepted reader scope bundle and therefore are not dispatchable. |
| Capability binaries | `Sources/GoogleMarketingGatewayReader/main.swift`, `Sources/GoogleMarketingGatewayWriter/main.swift`, `Sources/GoogleMarketingGatewayAdmin/main.swift` | Reader/writer/admin executable separation exists. Writer and admin routes must remain unavailable until explicit descriptors, profile validation, and plan/apply policies are added. |

## 3. Product Capability Matrix

| Product | Official API surface | Reader baseline | Writer baseline | Admin baseline | Availability decision |
|---|---|---|---|---|---|
| Analytics Admin | Google Analytics Admin API v1beta/v1alpha as applicable at implementation time | Accounts, properties, data streams, measurement protocol secrets metadata, conversion events, key events, custom dimensions/metrics, access bindings, product links, change history, and account summaries where officially readable | Property, data stream, conversion/key event, custom definition, channel group, and product-link configuration changes after allowlisted plan/apply support | Account/property access bindings, account moves, deletes, acknowledgements, Google Ads links with spend implications, and sensitive data-sharing settings | Planned. Must stay separate from Analytics Data because scopes, resource semantics, and write risk differ. |
| Analytics Data | Google Analytics Data API v1beta | Existing metadata, run report, and compatibility reader baseline; next readers should cover realtime, batch, pivot, funnel, audience export, metadata expansion, quotas, and materialized large reports | Not enabled initially; report-job or audience-export operations that create durable provider artifacts need explicit writer-style persistence classification even if analytically read-oriented | Property access and configuration are not Analytics Data operations and must route through Analytics Admin | Implemented partial reader plus planned expansion. |
| Tag Manager | Tag Manager API v2 | Accounts, containers, workspaces, tags, triggers, variables, folders, templates, versions, environments, user permissions, and built-in variables | Workspace create/update/delete, tag/trigger/variable edits, template edits, version creation, and environment changes through plan/apply | Account/container permissions, publish, delete, quick preview side effects, and live-version promotion | Planned. Workspace edits are writer; publish and access changes are admin. |
| YouTube Data | YouTube Data API v3 | Channel, playlist, video, search, captions metadata where permitted, comments metadata where justified, and content-owner scoped reads when authorized | Playlist/video metadata edits, comment moderation, caption changes, and uploads only after separate write policy | Channel ownership, live broadcast control, upload workflows, subscriptions, and destructive moderation remain admin or excluded until justified | Planned reader-first. Avoid upload or moderation claims in the initial slice. |
| YouTube Analytics | YouTube Analytics API v2 | Channel and content-owner reports, groups, group items, bulk reports where official and accessible | Group and group-item changes if needed for reporting organization | Content-owner access and monetary report profiles require sensitive-reader or admin policy depending on scope | Planned. Separate ordinary activity reporting from monetary/partner reporting scopes. |
| Search Console | Search Console API and URL Inspection API | Existing sites, search analytics, sitemaps list/get, and URL inspection readers; next readers should cover crawl/indexing metadata only where official | Sitemap submit/delete and non-destructive site maintenance only through writer plan/apply | Site ownership, association, user/permission, and property-level changes are admin | Implemented partial reader plus planned writer/admin separation. |
| Ads Data Hub | Ads Data Hub API | Customers, customer links, ads data links, query metadata, saved queries, query validation, query execution status, and result materialization | Query creation/update, parameterized execution, and schedule changes where non-billable or explicitly bounded | Customer/link administration, permissions, linked ads data, and any query execution with billable or large-output risk | Planned. Query execution is not a simple read; classify billable API cost, output size, and privacy checks per descriptor. |
| Business Profile | Business Profile APIs | Organizations/accounts, locations, categories, attributes, media metadata, local posts, reviews, Q&A where official and account-entitled | Review replies, local posts, media changes, hours/profile updates, and location metadata edits through plan/apply | Organization/account user management, ownership transfer, verification, location creation/deletion, and sensitive profile state changes | Planned. API families and availability differ by resource; represent restricted or migrated surfaces explicitly. |
| Local Services Ads | Local Services Ads API | Account discovery, business profiles, leads, conversations, reports, budgets/status where official public APIs expose them | Lead status, message/reply, dispute, and profile updates only if official APIs and non-billable controls are confirmed | Account access, serving eligibility, license/background-check sensitive state, and budget changes | Planned with restricted availability labels. Do not infer unsupported resources from Google Ads or Business Profile APIs. |

## 4. Capability Boundaries

Capability follows business effect, not HTTP method.

| Capability | Included operation families | Excluded from that lower capability |
|---|---|---|
| Reader | Metadata, account/property/container/channel/location discovery, reporting, search analytics, URL inspection, read-only links, read-only access listings, query validation, and provider-side report jobs that do not alter serving or configuration. | Writes, publishes, deletes, access changes, ownership transfers, verification, budget changes, live campaign/lead state changes, uploads, or durable configuration changes. |
| Writer | Reversible or plan-safe configuration changes, workspace edits, report/query definitions, sitemap submit/delete, review replies, local posts, media/profile updates, and non-administrative content metadata changes after explicit allowlists. | Access control, ownership, publish, account linking with spend or data-sharing impact, destructive deletes, billable execution without budget policy, and irreversible moderation. |
| Admin | Principal/account/property/container/channel/location ownership, permissions, publish/live-version control, account links, verification, serving eligibility, destructive deletes, privacy-sensitive query/link administration, and budget-affecting operations. | Any operation missing an exact descriptor, profile capability, request schema, idempotency policy, and tests. |

## 5. OAuth and Profile Policy

Profiles remain product-isolated. A token or scope bundle for one product cannot
satisfy another product's operations, even when Google consent screens or broad
scopes overlap.

| Product key | Reader profile direction | Writer/admin direction |
|---|---|---|
| `analytics-admin` | Use official Analytics Admin read scopes where possible; do not reuse `analytics-data` profiles silently. | Configuration and access scopes require writer/admin capability and plan/apply. |
| `analytics-data` | Existing exact `https://www.googleapis.com/auth/analytics.readonly` profile remains valid. | Durable report/audience artifacts need descriptor-specific capability classification. |
| `tag-manager` | Use official Tag Manager readonly scope for reader descriptors. | Edit, publish, and permission scopes are writer/admin only. |
| `youtube-data` | Prefer readonly YouTube scopes for metadata. | Upload, force SSL, partner, and moderation scopes are not reader scopes. |
| `youtube-analytics` | Use analytics readonly scopes; separate ordinary channel reporting from monetary/partner reporting. | Group management and content-owner-sensitive operations need explicit policy. |
| `search-console` | Existing exact `https://www.googleapis.com/auth/webmasters.readonly` profile remains valid. | `webmasters` write-capable scope must not be accepted by reader profiles. |
| `ads-data-hub` | Use official Ads Data Hub scopes with customer binding and query-output policy. | Link/customer administration and billable query execution require writer/admin controls. |
| `business-profile` | Use official Business Profile readonly or business information scopes where available. | Review replies, profile edits, ownership, and verification need writer/admin separation. |
| `local-services-ads` | Use official Local Services Ads scopes and account bindings when publicly available. | Lead/account/budget changes require explicit restricted-availability descriptors. |

The current `CredentialProfileConfiguration` only accepts reader profiles for
implemented reader products. The first implementation slice must expand
`MarketingProduct.readerOAuthScopes` and tests before any new product can be
configured.

## 6. Initial Operation Catalog

The next implementation slice should add planned descriptors first, then mark
operations implemented only after request builders, CLI routing, and tests exist.

| Priority | Product | Reader operations to catalog first | Deferred writer/admin operations |
|---:|---|---|---|
| 1 | Analytics Admin | Account summaries, accounts get/list, properties get/list, data streams get/list, custom dimensions/metrics list, conversion/key events list, product links list, access bindings list, change history search. | Create/patch/delete properties, streams, custom definitions, conversion/key events, access bindings, product links, account moves, acknowledgements, deletes. |
| 2 | Tag Manager | Accounts, containers, workspaces, tags, triggers, variables, folders, templates, versions, environments, user permissions. | Workspace edits, tag/trigger/variable/template mutations, version creation, publish, delete, permission changes. |
| 3 | YouTube Data and Analytics | Channels, videos, playlists, search list, analytics reports query, groups list, group items list. | Uploads, caption/comment mutations, playlist/video metadata edits, group mutations, live broadcast control, moderation. |
| 4 | Ads Data Hub | Customers, customer links, ads data links, queries list/get/validate, operations status, result metadata/materialization. | Query create/update/delete/execute, schedules, link/customer administration, permissions. |
| 5 | Business Profile and Local Services Ads | Organizations/accounts, locations, categories, attributes, reviews list, local posts list, LSA account/lead/report reads where official and entitled. | Review replies, local posts/media/profile edits, location creation/deletion, ownership/user/verification, lead/budget/status changes. |
| 6 | Search Console expansion | Keep existing routes; add descriptors for sitemap submit/delete as writer and any additional official read resources only after doc recheck. | Site ownership, association, permission, sitemap submit/delete writer/admin paths. |

Descriptors must include product, API family, version or stability, official
origin, provider method, capability, OAuth scopes, availability, spend or
billable API risk, request body policy, pagination/materialization policy, and
required tests. Planned descriptors may appear in inventory output but must not
be accepted by dispatch until implemented.

## 7. Request Safety

All adapters in this feature area must preserve the repository's bounded
request construction pattern:

- Callers choose operation ids and typed arguments, not arbitrary origins,
  methods, paths, headers, query strings, scopes, or authorization material.
- Request files are schema-specific, local-path-only, size-limited, depth-limited,
  and validated before credential resolution.
- Identifiers are validated by product: Analytics property names, Tag Manager
  account/container/workspace paths, YouTube channel/video ids, Search Console
  site URLs, Ads Data Hub customer/query names, Business Profile account/location
  names, and Local Services Ads account or lead identifiers.
- Large reports, Ads Data Hub query results, YouTube Analytics result sets, and
  Business Profile media payloads materialize to bounded local files with opaque
  download keys rather than unbounded inline output.
- Error output may include sanitized provider request ids, reason codes, and safe
  field paths, but never tokens, cookies, authorization headers, client secrets,
  refresh tokens, developer tokens, raw request bodies containing sensitive
  values, or paid-action receipts with private account data.

## 8. Implementation Plan Linkage

The corresponding implementation plan path is
`impl-plans/analytics-content-local-capabilities.md`. That implementation-plan
branch should prioritize a cohesive foundation:

1. Expand product identifiers only where missing: `ads-data-hub`,
   `business-profile`, and `local-services-ads`; keep existing
   `analytics-admin`, `analytics-data`, `tag-manager`, `youtube-data`,
   `youtube-analytics`, and `search-console`.
2. Extend credential profile scope validation for new reader products while
   preserving exact scope checks for implemented readers.
3. Add operation descriptor metadata for implemented versus planned operations.
4. Add reader request builders for Analytics Admin and Tag Manager first because
   they share account/configuration hierarchy needs with agency operations.
5. Add YouTube Data/Analytics and Ads Data Hub reader descriptors with
   materialization policy before enabling large-output commands.
6. Add Business Profile and Local Services Ads inventory descriptors with
   explicit restricted availability before routes.
7. Keep writer/admin descriptors disabled until plan/apply, idempotency,
   confirmation, and no-billable-verification tests exist.

## 9. Decisions

| Decision | Rationale |
|---|---|
| Keep Analytics Admin separate from Analytics Data. | Admin/configuration APIs have different scopes, resource models, access semantics, and write risks than report reads. |
| Treat Tag Manager publish and permission changes as admin. | Publishing and access changes can immediately affect production measurement, data collection, and agency/client boundaries. |
| Treat Ads Data Hub query execution as a classified operation, not an ordinary read by default. | Execution can create durable jobs, large outputs, privacy-check failures, and possible billable API usage. |
| Keep YouTube Data, YouTube Analytics, Business Profile, and Local Services Ads product-specific. | Their account, content, local, and lead models do not safely collapse into a generic campaign or property abstraction. |
| Preserve existing Analytics Data and Search Console reader behavior unchanged. | These are already tested foundations and should not be destabilized by broader inventory work. |
| Mark restricted, allowlisted, beta, migrated, deprecated, or non-public surfaces honestly. | The issue requires official API coverage without false claims or scraping fallback. |
| Do not perform billable Google actions during design or implementation verification. | Workflow limits allow only later explicitly approved paid actions; this branch is documentation-only. |

## 10. Open Questions

- Which Analytics Admin API version should be pinned for the first reader slice
  after implementation-time official doc recheck?
- Should Analytics Admin access bindings be exposed as reader metadata in the
  first slice, or deferred because they include sensitive principal data?
- Which Tag Manager workspace resources should be first-class typed request
  builders versus safely bounded generic JSON request files?
- Which YouTube Analytics monetary or content-owner reports require a separate
  sensitive-reader profile beyond ordinary reader capability?
- Which Ads Data Hub operations can be verified zero-cost and read-only with
  available credentials?
- Which Business Profile API families are available for the target account and
  which require restricted availability labels?
- What exact public Local Services Ads operations are available for multi-account
  agency reads at implementation time?

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Google product APIs differ in availability, migration state, and entitlement | False implementation claims or broken routes | Store availability per operation and require official doc recheck before implementation. |
| Broad Google scopes can cross product boundaries | Least-privilege erosion | Enforce product-isolated profiles and exact reader scope bundles. |
| Ads Data Hub and report APIs can create large or billable jobs | Cost, privacy, or output-size failures | Classify persistence and billable risk per descriptor; materialize outputs; require explicit approvals for paid execution. |
| Tag Manager and Analytics Admin writes can alter production measurement | Client data loss or tracking outages | Keep edits writer/admin only with plan/apply, diff, idempotency, and confirmation tokens. |
| Business Profile and Local Services Ads operations can affect public listings or lead handling | Public-profile or client-service impact | Gate replies, edits, verification, lead status, and budget/serving changes behind writer/admin policies. |
| Sensitive account, user, review, query, and location data may leak through errors or logs | Privacy and compliance exposure | Redact tokens and sensitive payloads; keep safe field paths and provider request ids only. |

## 12. Verification Commands

Documentation-only branch verification:

```bash
test -f design-docs/analytics-content-local-capabilities.md
git diff -- design-docs/analytics-content-local-capabilities.md
```

Implementation branches that modify Swift must also run:

```bash
mise run lint
mise run test
mise run build
```
