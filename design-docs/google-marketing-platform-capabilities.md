# Google Marketing Platform Capabilities

**Status:** Feature-local design update for issue-resolution branch
**Feature ID:** `gmp-products`
**Feature title:** Google Marketing Platform Coverage
**Issue reference:** `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Workflow mode:** `issue-resolution`
**Author verification date:** 2026-08-14

## 1. Purpose

This document defines the gateway coverage plan for Google Marketing Platform
products that are outside the repository's current implemented reader subset:

- Display & Video 360 API;
- Campaign Manager 360 API v5;
- Search Ads 360 Reporting API.

The design advances coverage without claiming a full per-method implementation.
It records the official product surfaces, capability boundaries, account
hierarchy implications, OAuth/profile separation, and the safest incremental
operation catalog needed for agency-managed client accounts.

The existing gateway foundation already separates reader, writer, and admin
executables and currently implements bounded reader slices for Google Ads,
Analytics Data, Search Console, AdSense, and AdMob. This GMP design extends the
same architecture and does not introduce arbitrary HTTP proxying, unofficial
scraping endpoints, caller-supplied origins, caller-supplied authorization
headers, or unbounded request bodies.

## 2. Product Status Matrix

| Product | Official API status for gateway | Primary agency account model | Gateway disposition |
|---|---|---|---|
| Display & Video 360 | Official REST API with resource, campaign, creative, inventory, reporting, and user-management methods. Some resources and fields are versioned, partner/advertiser-scoped, or entitlement-dependent. | Partner and advertiser hierarchy with users, assigned targeting options, campaigns, insertion orders, line items, creatives, inventory sources, channels, and reports. | Add a product-isolated `dv360` catalog. Start with reader coverage for hierarchy, campaigns, insertion orders, line items, creatives, targeting, inventory sources, channels, users, and generated report metadata/results. Enable writer/admin only through explicit allowlists. |
| Campaign Manager 360 | Official Campaign Manager 360 API v5 with trafficking, reporting, and attribution resources. Older versions must be treated as deprecated once v5 is selected. | Profile-scoped agency/advertiser/campaign/site/placement/creative hierarchy with reports and conversions/attribution resources. | Add a version-pinned `cm360-v5` catalog. Start with reader coverage for profiles, accounts/advertisers/campaigns/sites/placements/creatives, floodlight configuration where readable, reports, and attribution/conversion read endpoints. Trafficking writes are writer/admin gated. |
| Search Ads 360 | Official Search Ads 360 Reporting API with customer-scoped reporting and offline conversion support. The gateway must distinguish current reporting API support from legacy SA360 API surfaces. | Manager/client customer hierarchy adjacent to Google Ads, with accounts, campaigns, ad groups, ads, keywords, conversions, reports, and custom columns as exposed by the official reporting API. | Add an `sa360` catalog focused on report construction, customer/account discovery, campaign/ad entity reporting, custom columns, and offline conversion uploads. Reads ship first; offline conversions require a writer plan/apply path and receipt. |

## 3. Capability Boundaries

The GMP products use the same executable policy as the rest of the gateway:

| Capability | DV360 | CM360 v5 | SA360 |
|---|---|---|---|
| Reader | List/get hierarchy, inventory, campaigns, line items, creatives, targeting, reports, users, and change/audit metadata where officially exposed. | List/get profiles, accounts, advertisers, campaigns, sites, placements, ads, creatives, floodlight-readable metadata, reports, and attribution/conversion reads. | Customer/account discovery and bounded reporting for campaign, ad group, ad, keyword, conversion, and custom-column dimensions. |
| Writer | Non-administrative campaign delivery edits only when allowlisted: draft/update resources, pause/activate entities, upload safe creative metadata, and create report jobs. | Trafficking edits only when allowlisted: create/update campaigns, placements, ads, creatives, reports, and related non-identity resources. | Offline conversion uploads and non-administrative report/job operations when officially supported and allowlisted. |
| Admin | User access, partner/advertiser administration, destructive deletes, permanent creative removals, sensitive inventory configuration, and publish/activate actions that affect production spend. | User/profile/account administration, destructive deletes, floodlight or attribution configuration, permanent trafficking removals, and production-impacting activation. | Manager/client authorization, account linking, access operations, destructive operations, and any action that changes spend eligibility. |

HTTP verb is not the capability boundary. Report creation or query methods that
use `POST` can be logical reads if they only create provider-side report jobs or
return report data. Mutations that change serving, eligibility, identity,
access, attribution configuration, or spend capability are writer/admin even if
the provider exposes broad OAuth scopes.

## 4. OAuth And Credential Profiles

Each GMP adapter uses product-isolated credential profiles:

| Profile product key | Required binding fields | Scope policy |
|---|---|---|
| `dv360` | `partnerId` and optional explicit `advertiserId`; user profile/account context must come from configuration or provider discovery, not GraphQL input alone. | Use only official DV360 scopes. Separate read, write, and admin profile capability flags even when Google scopes are broad. |
| `cm360-v5` | `profileId`; optional configured account/advertiser/campaign defaults. Profile IDs are never inferred from another product token. | Use only official Campaign Manager 360 scopes. Treat trafficking writes and user/profile administration as separate gateway capabilities. |
| `sa360` | `loginCustomerId` or equivalent manager context when required by the official API; explicit customer/account binding for each query. | Use only official Search Ads 360 scopes. Offline conversion upload requires writer capability and cannot run under a reader binary. |

Cross-product scope bundles are rejected by default. A DV360 credential cannot
silently satisfy CM360 or SA360 operations, and Analytics Admin links to GMP
properties remain read/report metadata until a focused design authorizes linked
product administration.

## 5. Initial Operation Catalog

The first implementation slice should add descriptors and tests before enabling
business fields. Descriptors must include the official origin, version, HTTP
template, path parameter bindings, request-file schema, response type, OAuth
scope, stability classification, quota dimensions, pagination token, and data
classification.

| Product | Reader operations to catalog first | Deferred writer/admin operations |
|---|---|---|
| DV360 | Partner/advertiser list and get; campaigns; insertion orders; line items; ad groups where available; creatives; channels; inventory sources; targeting types and assigned targeting options; users; custom bidding metadata; report job list/get/create/read as logical read where no serving state changes. | Create/patch/delete or activate/pause campaigns, insertion orders, line items, creatives, channels, inventory, targeting assignments, custom bidding scripts, and users. |
| CM360 v5 | Profiles; user profiles; accounts; subaccounts; advertisers; campaigns; sites; placements; ads; creatives; creative assets where metadata-only; floodlight readable resources; report definitions, report runs, files, and attribution/conversion read resources. | Trafficking create/update/delete, creative asset upload, floodlight changes, account/user/profile changes, destructive deletes, and production activation. |
| SA360 | Accessible customers/accounts; campaign, ad group, ad, keyword, bidding, conversion, and custom-column reports; report pagination/materialization; conversion action metadata where read-only. | Offline conversion uploads, conversion adjustment uploads, account linking, customer/user changes, and any mutate-like operation that affects spend, attribution, or account access. |

The GraphQL schema must expose product-specific fields rather than forcing a
universal campaign model. Shared response envelopes may cover pagination,
warnings, quota observations, materialized file keys, request IDs, and sanitized
provider errors, but resource payloads remain product-specific.

## 6. Request Safety

GMP endpoints often accept large filters, report definitions, creative metadata,
and nested trafficking payloads. The gateway must preserve the existing
bounded-request pattern:

- GraphQL and CLI routes accept typed arguments or a `--request-file` whose JSON
  schema is operation-specific and size-limited.
- Callers cannot choose arbitrary origins, methods, URL paths, headers, query
  parameters, or OAuth scopes.
- Identifiers are encoded as path segments only by the adapter descriptor.
- Report outputs default to materialized files with opaque download keys when
  row counts, file bytes, or response complexity exceed inline limits.
- Error output includes provider request IDs, sanitized reason codes, and safe
  field paths, but never access tokens, refresh tokens, developer tokens, raw
  authorization headers, cookie values, or request bodies containing secrets.

## 7. Implementation Plan Linkage

The corresponding implementation plan path is
`impl-plans/google-marketing-platform-capabilities.md`. That plan should be
created by the implementation-plan branch, not by this design-doc branch. It
should prioritize a complete foundation over broad shallow claims:

1. Add product catalog types for `dv360`, `cm360-v5`, and `sa360`.
2. Add credential profile validation and product-isolated OAuth configuration.
3. Add descriptor fixtures for the initial reader operations.
4. Add bounded request-file schemas and sanitized error fixtures.
5. Add CLI/GraphQL routing stubs that expose only implemented descriptors.
6. Add focused tests for origin pinning, scope/capability rejection,
   pagination/materialization, and mutation blocking in the reader binary.
7. Add writer/admin operation descriptors only after reviewed plan/apply
   semantics and non-billable verification paths exist.

## 8. Decisions

| Decision | Rationale |
|---|---|
| Treat DV360, CM360 v5, and SA360 as separate products. | They have different account hierarchies, scopes, resource semantics, quotas, versions, and entitlement requirements. A shared marketing-campaign abstraction would hide important provider behavior. |
| Pin CM360 to v5 for new gateway design. | The issue explicitly requires CM360 v5. Older versions remain outside the new capability claim unless a migration reference is needed. |
| Keep SA360 offline conversions out of reader coverage. | Offline conversion upload is a write with attribution and billing impact. It needs plan/apply, idempotency, validation, and receipts. |
| Classify user access and account administration as admin. | Agency-managed accounts require strict principal, profile, and client boundary controls. |
| Allow report-job creation as logical read only when it does not change serving state. | Several official reporting APIs use `POST` to define or run read reports. Capability must follow business effect rather than HTTP method. |
| Do not claim all GMP resource methods are implemented. | The gateway should expose only registered, tested descriptors and label deferred official surfaces honestly. |

## 9. Open Questions

- Which DV360 API version should be pinned for the first implementation slice
  after release-time doc recheck?
- Which CM360 v5 report families and attribution resources should be first
  class versus safely generic bounded report requests?
- Which SA360 customer hierarchy discovery route is sufficient for agency
  multi-client bindings without duplicating Google Ads manager traversal?
- Should monetary or invoice-adjacent GMP reports require a distinct sensitive
  data profile beyond ordinary reader capability?
- Which live verification accounts can be used for zero-cost read-only smoke
  tests without accessing production client data?

## 10. Risks

- DV360, CM360, and SA360 entitlements may vary by account and cannot be
  inferred from OAuth scopes alone; adapters must preserve provider-denied
  capability responses.
- Report creation APIs can look like reads but still create provider-side
  artifacts; descriptors must classify persistence and cleanup behavior.
- Creative and trafficking writes can affect production delivery or spend even
  when budgets are not directly changed.
- Cross-product account links through Analytics Admin or Google Ads can tempt
  unsafe model merging; the gateway must preserve product boundaries.
- Official API versions, quotas, and deprecation status may change between
  design and release; implementation must recheck docs and regenerate fixtures.
- Generic REST construction is useful for breadth but must remain descriptor
  bounded, origin-pinned, schema-limited, and capability-gated.

## 11. Verification Commands

Documentation-only branch verification:

```bash
test -f design-docs/google-marketing-platform-capabilities.md
git diff -- design-docs/google-marketing-platform-capabilities.md
```

Implementation branches that modify Swift must also run:

```bash
mise run lint
mise run test
mise run build
```
