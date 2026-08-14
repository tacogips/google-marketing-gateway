# Gateway Safety, CLI Routing, and Verification

**Feature ID:** `gateway-safety-cli`
**Feature title:** Gateway Safety, CLI Routing, and Verification
**Issue reference:** `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Workflow mode:** `issue-resolution`
**Status:** Feature-local design update for implementation planning
**Author verification date:** 2026-08-14
**Implementation plan:** `impl-plans/gateway-safety-cli-foundation.md`

## 1. Purpose

This design defines the shared safety and CLI foundation required before the
gateway can honestly expand from its current implemented reader subset to the
complete official Google advertising and adjacent agency-operation surface.

The feature does not claim every provider method is implemented. It defines the
common rules that every future product slice must satisfy: official fixed
origins, capability-separated binaries, product-isolated OAuth profiles, safe
request-file handling, sanitized errors, explicit operation catalog metadata,
bounded generic REST construction, deterministic tests, and verification
commands. It also gives the implementation branch a cohesive place to add shared
catalog fields and CLI routing gates used by Google Ads, Google Marketing
Platform, Ad Manager, Merchant Center, Analytics, Tag Manager, YouTube, Search
Console, AdSense, AdMob, Ads Data Hub, Authorized Buyers, Business Profile, and
Local Services Ads where official public APIs exist.

## 2. Current Repository Findings

| Area | Current files | Finding |
|---|---|---|
| Swift package products | `Package.swift` | Reader, writer, admin, compatibility, and core targets already exist. |
| Capability mode | `Sources/GoogleMarketingGatewayCore/GatewayModels.swift`, `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift` | `GatewayMode` separates reader, writer, and admin. Writer/admin currently reject operations because mutation allowlists are empty. |
| Operation catalog | `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` | Catalog contains implemented reader descriptors for Google Ads, Analytics Data, Search Console, AdSense, and AdMob plus a non-implemented Google Trends alpha marker. Descriptor metadata is too small for broader coverage. |
| Official-origin request builders | `Sources/GoogleMarketingGatewayCore/GoogleAdsRequests.swift`, `Sources/GoogleMarketingGatewayCore/AnalyticsDataRequests.swift`, `Sources/GoogleMarketingGatewayCore/SearchConsoleRequests.swift`, `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift` | Implemented readers construct fixed official Google API URLs and do not expose caller-selected origins. |
| Credential profiles | `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift` | Reader profile validation is product-isolated and rejects writer/admin profiles today. Expanded writer/admin profile validation is still needed. |
| Request-file safety | `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift`, `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestFileTests.swift` | Search Console request-file handling validates secure local files and should become the shared pattern for bounded JSON/text request bodies. |
| Error sanitization | `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift`, `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleCLITests.swift` | Transport and CLI tests cover sanitized provider failures and prevent token/body leaks. This must become a required cross-product fixture pattern. |
| CLI routing | `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift` | Reader routes are closed and product-specific. Generic REST routing is not present, which is good; future generic routing must remain descriptor-bounded. |

## 3. Design Goals

- Preserve the existing reader, writer, and admin executable separation.
- Keep every provider request pinned to official Google API origins; no
  scraping, browser replay, unofficial endpoints, arbitrary URLs, caller-supplied
  authorization headers, or wildcard origins.
- Support typed request builders first and allow generic REST only when bounded
  by an implemented operation descriptor, fixed origin, fixed method/path
  template, exact capability, product scope policy, and request-file schema.
- Validate user input and request files before resolving credentials.
- Return sanitized errors that may include safe status, reason, request ID, and
  field path, but never token values, developer tokens, cookies, client secrets,
  raw authorization headers, or request bodies containing private data.
- Expand the operation catalog into an honest capability matrix that separates
  `implemented`, `planned`, `beta`, `allowlisted`, `deprecated`, `restricted`,
  and `excluded-no-official-public-api` surfaces.
- Add tests proving planned operations are visible as inventory but are not
  callable until implemented.
- Provide verification commands that do not perform billable Google actions.

## 4. Operation Catalog Contract

`OperationDescriptor` should grow from the current minimal shape into a shared
contract. The implementation branch should add only fields it can test locally.

| Field | Required behavior |
|---|---|
| `id` | Stable gateway id, for example `google-ads.customer-clients.list` or `merchant.products.list`. |
| `product` | Product enum value; add missing products without collapsing provider semantics. |
| `apiFamily` | Official API family such as `google-ads`, `dv360`, `cm360`, `ad-manager-rest`, `ad-manager-soap`, `merchant`, `analytics-admin`, `tag-manager`, `youtube-data`, `ads-data-hub`, `authorized-buyers-marketplace`, `real-time-bidding`, `business-profile`, or `local-services-ads`. |
| `apiVersion` | Explicit version or service family such as `v25`, `v5`, `v1beta`, `v2`, `v3`, `soap`, or `beta`. |
| `stability` | `ga`, `beta`, `alpha`, `allowlisted`, `deprecated`, `sunset`, `restricted`, or `nonPublic`. |
| `origin` | Fixed official origin; no wildcard or input-derived origin. |
| `providerMethod` | Exact official REST method, gRPC-transcoded method, SOAP service/action, or report/query method. |
| `capability` | `reader`, `writer`, or `admin`; based on business effect, not HTTP verb. |
| `oauthScopes` | Exact product-isolated OAuth scopes. |
| `requestKind` | `read`, `report`, `mutate`, `upload`, `job`, `access`, `billing`, `publish`, or `delete`. |
| `spendRisk` | `none`, `billable-api-only`, `indirect-serving`, or `ad-spend`. |
| `availability` | `implemented`, `planned`, `blocked-by-access`, `blocked-by-beta`, `deprecated-no-new-work`, or `excluded-no-official-public-api`. |
| `requestBodyPolicy` | `none`, `typed`, `bounded-json-file`, `bounded-text-file`, `soap-envelope-allowlist`, or `provider-generated-only`. |
| `responsePolicy` | Inline byte limit, materialized file requirement, or streaming/materialization policy. |
| `verification` | Required local tests and any allowed zero-cost live verification command. |

`OperationCatalog.operation(id:)` must continue to resolve only implemented
operations. Catalog export may include planned inventory, but CLI and future
GraphQL dispatch must reject anything whose availability is not `implemented`.

## 5. Capability Routing

| Binary | Allowed dispatch | Required rejection tests |
|---|---|---|
| `google-marketing-gateway-reader` | Logical reads and reports only, including provider `POST` report/query methods that do not mutate serving, access, billing, or durable configuration. | Mutates, uploads, access changes, billing, publish, delete, admin, and planned operations are rejected before credential resolution. |
| `google-marketing-gateway-writer` | Implemented non-administrative writer descriptors with plan/apply semantics and idempotency where provider supports it. May optionally expose implemented read routes. | Admin, access, billing, publish, delete, spend-risk, and unavailable operations are rejected. |
| `google-marketing-gateway-admin` | Implemented admin descriptors with confirmation policy, request receipts, sanitized previews, and explicit profile capability. | Unknown, planned, deprecated-no-new-work, non-public, and unofficial operations are rejected. |

Google Ads remains a special least-privilege case because the official
`https://www.googleapis.com/auth/adwords` scope covers both reads and writes.
Gateway separation must therefore come from binary mode, profile capability,
operation descriptor capability, fixed request builders, allowlists, and tests.

## 6. Request Construction Rules

1. Prefer typed request builders for high-priority operations.
2. Permit generic REST construction only through implemented descriptors with a
   fixed method, fixed origin, fixed path template, declared path/query
   parameters, bounded body policy, and exact OAuth scopes.
3. Validate path components as product-specific identifiers before URL encoding.
4. Reject caller-supplied origins, absolute URLs, custom headers,
   authorization headers, OAuth scopes, API versions, and HTTP methods.
5. Read request files through secure local-file helpers; reject symlinks,
   world/group-readable files, non-regular files, race-prone replacements,
   oversize files, deep JSON, malformed JSON, and schema-invalid bodies.
6. Materialize large report outputs to bounded local files and return opaque
   download keys rather than embedding unbounded payloads in CLI/GraphQL output.
7. Keep raw request bodies and provider error bodies out of normal logs unless a
   future explicit redacted debug artifact policy is reviewed.

## 7. Product Coverage Disposition

This feature owns the shared foundation only. Product-local designs remain the
source for operation prioritization:

| Product area | Design doc | Safety disposition |
|---|---|---|
| Google Ads agency hierarchy and mutates | `design-docs/google-ads-agency-operations.md` | Use shared descriptor fields, Google Ads origin pinning, manager/customer identifier validation, and capability gates. |
| Display & Video 360, Campaign Manager 360, Search Ads 360 | `design-docs/google-marketing-platform-capabilities.md` | Add catalog-only planned inventory first; request builders must be descriptor-bounded and entitlement-aware. |
| Ad Manager, Merchant, AdSense, AdMob, Authorized Buyers, RTB | `design-docs/publisher-commerce-capabilities.md` | Preserve existing AdSense/AdMob readers; add Merchant, Ad Manager REST/SOAP, and exchange surfaces only with explicit availability and fixed origins. |
| Analytics Admin/Data, Tag Manager, YouTube Data/Analytics, Search Console, Ads Data Hub, Business Profile, Local Services Ads | This design plus future product-local docs as needed | Represent official public, beta, allowlisted, deprecated, and restricted surfaces honestly; do not claim implementation until routes and tests exist. |
| Google Trends | `design-docs/google-marketing-gateway-design.md` | Excluded from generally available gateway; official alpha only and no scraping. |

## 8. Implementation Guidance

The corresponding implementation plan should prioritize shared invariants over
wide shallow route creation:

1. Expand `MarketingProduct` and `OperationDescriptor` with tested catalog
   metadata and availability semantics.
2. Split catalog export from callable operation lookup so planned inventory is
   visible but non-dispatchable.
3. Add a descriptor-bounded request builder abstraction for future REST
   operations without exposing arbitrary HTTP.
4. Generalize secure request-file validation from Search Console into reusable
   bounded JSON/text body helpers.
5. Add sanitized error fixtures that include simulated provider messages with
   tokens, developer tokens, emails, request snippets, and secrets.
6. Keep writer/admin allowlists empty unless the implementation slice includes
   plan/apply semantics, confirmation policy, idempotency, and non-billable
   verification.
7. Update CLI routing only for implemented operations; catalog-only planned rows
   must not appear as runnable commands.

## 9. Decisions

| Decision | Rationale |
|---|---|
| Treat this feature as the shared safety foundation, not a broad product implementation. | The issue requires comprehensive coverage, but honest incremental delivery needs common gates before many product slices can be safely exposed. |
| Keep generic REST descriptor-bounded. | Generic request construction is useful for breadth, but arbitrary HTTP would defeat least privilege and origin pinning. |
| Let capability follow business effect, not HTTP verb. | Google reporting APIs often use `POST` for reads, while some dangerous operations may look structurally similar to ordinary updates. |
| Keep planned catalog rows non-callable. | Capability matrices are valuable, but dispatch must remain limited to implemented and tested operations. |
| Reuse Search Console request-file safety as the shared pattern. | It already covers secure local-file checks, validation before credentials, bounded input, and adversarial tests. |
| Keep live verification zero-cost by default. | The workflow forbids billable actions and requires explicit spend limits for any later paid verification. |

## 10. Open Questions

- Should planned catalog rows live in the same `OperationCatalog.operations`
  array with availability filtering, or in a separate `OperationInventory` type
  to reduce accidental dispatch risk?
- What inline response byte limit and materialized file policy should become the
  cross-product default?
- Which products need separate sensitive-data profile flags beyond
  reader/writer/admin, such as YouTube monetary reports or AdSense payments?
- Should SOAP support for Ad Manager use a distinct descriptor type or the same
  descriptor with `requestBodyPolicy: soap-envelope-allowlist`?

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Catalog expansion accidentally makes planned operations callable. | False implementation claims and unsafe dispatch. | Keep callable lookup filtered to `implemented`; add tests for planned/beta/restricted rejection. |
| Generic REST construction becomes an arbitrary proxy. | Unofficial endpoints, scope abuse, and data leakage. | Require fixed descriptor origin/method/path/schema and reject caller-supplied URLs, headers, scopes, and versions. |
| Sanitized errors remove useful provider diagnostics. | Harder debugging and support. | Preserve safe status, reason, request ID, operation id, and field path while redacting secrets and bodies. |
| Broad OAuth scopes undermine product least privilege. | A token for one product or capability could be misused. | Validate product-isolated profiles, exact scopes, binary mode, catalog capability, and operation id together. |
| Writer/admin verification could create spend or durable client changes. | Billing or production account harm. | Keep tests non-network; require explicit user approval, `me@tacogips.me`, per-action <= USD 5, total < USD 50, and no campaign/spend creation for any later live paid check. |
| Official API versions and access status change. | Stale descriptors or incorrect availability labels. | Recheck official docs on implementation date and keep version/stability visible in descriptors. |

## 12. Verification Commands

Documentation-only verification for this branch:

```bash
test -f design-docs/gateway-safety-cli-foundation.md
git diff -- design-docs/gateway-safety-cli-foundation.md
```

Implementation branches that modify Swift should run:

```bash
mise run lint
mise run test
mise run build
```
