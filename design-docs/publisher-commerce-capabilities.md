# Publisher and Commerce Surfaces

**Feature ID:** `publisher-commerce`
**Workflow mode:** `issue-resolution`
**Issue reference:** `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Author verification date:** 2026-08-14
**Implementation plan:** `impl-plans/publisher-commerce-capabilities.md`

## 1. Purpose

This document defines the publisher, commerce, exchange, and mobile app
monetization surfaces needed by the gateway:

- Google Ad Manager REST beta and legacy SOAP;
- Merchant API;
- AdSense Management API;
- AdMob API;
- Authorized Buyers Marketplace API;
- Real-time Bidding API.

The goal is honest coverage for official Google APIs only. The gateway must
distinguish generally available REST surfaces, beta REST surfaces, SOAP-only
surfaces, and allowlisted exchange surfaces. It must not use unofficial scraping
endpoints or claim complete method-level support before each operation has an
explicit catalog entry, request builder, least-privilege OAuth profile, CLI
route, and tests.

## 2. Current Repository Findings

The current repository already includes a bounded publisher reader foundation:

| Surface | Current files | Current status |
|---|---|---|
| AdSense Management API v2 | `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift`, `Sources/GoogleMarketingGatewayCore/PublisherReportModels.swift`, `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift` | Implemented reader request builders for accounts, payments, ad clients, ad units, sites, policy issues, and report generation |
| AdMob API v1 | `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift`, `Sources/GoogleMarketingGatewayCore/PublisherReportModels.swift`, `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift` | Implemented reader request builders for accounts, apps, ad units, network reports, and mediation reports |
| Operation catalog | `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` | Catalog includes implemented AdSense and AdMob reader operations only; Merchant, Ad Manager, Authorized Buyers, and RTB are not yet represented |
| Capability separation | `Sources/GoogleMarketingGatewayReader/main.swift`, `Sources/GoogleMarketingGatewayWriter/main.swift`, `Sources/GoogleMarketingGatewayAdmin/main.swift` | Reader/writer/admin binaries exist; writer currently rejects unimplemented mutations |

## 3. Capability Matrix

| Product | Official API surface | Reader baseline | Writer baseline | Admin baseline | Availability decision |
|---|---|---|---|---|---|
| Google Ad Manager | REST beta plus Ad Manager SOAP | REST beta network and resource reads where available; SOAP report, inventory, order, line item, creative, proposal, and company reads only through a bounded SOAP adapter | Line item/order/creative edits require reviewed allowlists and idempotency controls; SOAP writes remain disabled until request signing, envelope validation, and dry-run planning are implemented | Network, user, team, role, company, and trafficking state changes are admin-only and disabled initially | REST beta is version-labelled; SOAP is official but isolated behind explicit `ad-manager-soap` availability |
| Merchant Center | Merchant API | Accounts, products, product status, data sources, promotions, local inventory, regional inventory, reports, quotas, and supported account settings | Product input, inventory, promotion, and supported data-source changes behind writer allowlists | Account, sub-account, user, link, developer-registration, and business-identity changes are admin-only | Generally available official REST, but sub-API versions must stay visible per operation |
| AdSense | AdSense Management API v2 | Existing reader baseline remains: accounts, payments, ad clients, ad units, sites, policy issues, reports | Ad unit and custom channel create/patch/delete require writer tests before enablement | Payment settings and principal/account-sensitive operations remain excluded unless official API support and admin policy are reviewed | Generally available official REST; payments are read-only sensitive output |
| AdMob | AdMob API v1 | Existing reader baseline remains: account, apps, ad units, network reports, mediation reports | No stable v1 writer baseline | No stable v1 admin baseline | Generally available official REST for v1 reads; v1beta mediation management is not enabled by default |
| Authorized Buyers | Authorized Buyers Marketplace API | Buyers, clients, proposals, deals, auction packages, publisher profiles, and finalized deal reads when account is entitled | Proposal/deal negotiation changes are writer-only and require explicit non-billable planning controls | Client/user/account-level access changes are admin-only | Official REST, but commonly entitlement-bound; represent as `allowlist-or-entitlement-required` until credentials prove access |
| Real-time Bidding | Real-time Bidding API | Bidders, buyers, creatives, pretargeting configs, publisher connections, user lists, endpoint status, and policy topics | Creative submit/update and user list writes require writer allowlists and policy-result handling | Pretargeting, endpoint, account, and publisher-connection changes are admin-only | Official REST, but bidder/buyer access is allowlisted/contractual; never infer availability from OAuth alone |

## 4. Gateway Design Decisions

1. Add new product identifiers before adding routes: `ad-manager-rest`, `ad-manager-soap`, `merchant`, `authorized-buyers-marketplace`, and `real-time-bidding`.
2. Keep REST and SOAP Ad Manager as separate catalog availabilities even when they expose related business resources.
3. Treat report generation methods that use `POST` as reader operations only when they create no durable provider resource and only materialize bounded local output.
4. Require every writer/admin operation to have a plan/apply split, fixed official origin, bounded request-file schema, sanitized error mapping, and tests proving that the reader binary cannot dispatch it.
5. Preserve product-isolated OAuth profiles. Merchant API uses the documented Content/Merchant scope family with gateway-side reader/writer/admin policy separation. AdSense and AdMob continue to use their narrower readonly/report scopes where possible.
6. Represent allowlisted or entitlement-bound exchange APIs honestly in the catalog using availability strings such as `allowlist-or-entitlement-required`; do not show them as implemented until local request construction and non-network tests exist.
7. Do not perform billable Google actions during implementation or verification. Live verification, if later approved, must be read-only or zero-cost unless the workflow's explicit spend limits and user approval are satisfied.

## 5. Prioritized Implementation Slices

| Priority | Slice | Deliverable | Verification focus |
|---:|---|---|---|
| 1 | Catalog expansion | Add operation descriptors and OAuth profile metadata for Merchant, Ad Manager REST beta/SOAP, Authorized Buyers, and RTB with availability labels but no false implemented status | Catalog tests reject unavailable operations and expose explicit availability |
| 2 | Merchant reader | Typed or safely bounded REST request builders for accounts, products, product statuses, data sources, promotions, inventory, reports, and quotas | Fixed origins, resource-name validation, pagination, request-file bounds, no arbitrary URLs |
| 3 | Ad Manager reader foundation | REST beta request builders plus a narrowly scoped SOAP envelope builder for official read/report services | REST/SOAP separation, version labels, envelope allowlists, sanitized SOAP faults |
| 4 | Exchange readers | Authorized Buyers Marketplace and RTB read request builders for entitled account resources | Entitlement availability, fixed origins, path validation, no bidder writes |
| 5 | Writer/admin planning | Non-billable plan/apply framework for Merchant product/inventory writes and selected publisher/exchange mutations | Reader rejection, confirmation tokens, idempotency keys, no spend or trafficking side effects in tests |

## 6. Open Questions

- Which Ad Manager SOAP version should be pinned for the first SOAP reader slice, and when should it be retired in favor of REST beta parity?
- Should Merchant account/sub-account management be postponed until after product and inventory readers, or included in the first admin plan because agencies commonly manage multi-client hierarchies?
- Which exchange accounts are available for non-billable live read validation, if any, and can they be verified without contractual or allowlisted side effects?

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Ad Manager REST beta does not cover all required trafficking/reporting resources | Incomplete coverage if SOAP is ignored | Keep SOAP as an official but isolated adapter with explicit version and envelope allowlists |
| Merchant API sub-APIs differ in versioning and quota behavior | Incorrect shared request abstraction | Store product, method, version, quota dimensions, and pagination per operation |
| Authorized Buyers and RTB may require account entitlement beyond OAuth consent | False availability claims | Use availability labels and require live entitlement proof before marking implemented |
| Writer/admin operations can create spend or durable account changes | Billing, compliance, or client-account harm | Plan/apply split, confirmation tokens, hard operation allowlists, and no live billable verification by default |
| SOAP fault details or provider errors may leak identifiers | Sensitive client data exposure | Sanitize errors and keep raw envelopes out of normal CLI output |

## 8. Acceptance Criteria

- `OperationCatalog` explicitly lists implemented, planned, beta, SOAP, and
  allowlisted publisher/commerce operations without treating unavailable methods
  as callable.
- Merchant, Ad Manager, Authorized Buyers, and RTB request builders use only
  fixed official origins and validated path/resource components.
- Existing AdSense and AdMob reader behavior remains unchanged and covered by
  `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift`.
- Writer/admin binaries reject every publisher/commerce mutation until a
  reviewed plan/apply implementation and test coverage exists.
- Documentation and implementation plans stay under `design-docs/` and
  `impl-plans/`.
