# Publisher and Commerce Capabilities

**Status**: In Progress
**Workflow Mode**: `issue-resolution`
**Issue Reference**: `google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`
**Feature ID**: `publisher-commerce`
**Design Reference**: `design-docs/publisher-commerce-capabilities.md`
**Codex Agent References**: none

## Purpose

Implement the publisher and commerce gateway foundation described in
`design-docs/publisher-commerce-capabilities.md` without overstating API
coverage. The slice must add catalog, OAuth, request-construction, CLI, and test
coverage for Merchant API, Google Ad Manager REST beta/SOAP, Authorized Buyers
Marketplace, and Real-time Bidding while preserving existing AdSense and AdMob
reader behavior.

## Deliverables

- [ ] Expand `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` with
  explicit publisher/commerce product identifiers, operation descriptors,
  availability labels, and product-isolated OAuth profiles.
- [ ] Add Merchant API reader request builders using fixed official origins,
  validated resource names, bounded request-file inputs, pagination support, and
  explicit sub-API version metadata.
- [ ] Add Google Ad Manager reader request builders for REST beta operations
  and a narrow SOAP envelope builder for selected official read/report services.
- [ ] Add Authorized Buyers Marketplace and Real-time Bidding reader request
  builders with entitlement-labelled availability and fixed-origin path
  validation.
- [ ] Add CLI routing for newly implemented reader operations while ensuring
  `Sources/GoogleMarketingGatewayWriter/main.swift` and
  `Sources/GoogleMarketingGatewayAdmin/main.swift` continue to reject
  unimplemented publisher/commerce mutations.
- [ ] Add non-network tests covering operation catalog exposure, least-privilege
  OAuth profiles, request construction, request-file bounds, sanitized errors,
  and reader/writer/admin separation.

## Task Breakdown

### TASK-001: Catalog and OAuth metadata

**Parallelizable**: Yes

Update `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` with product
identifiers `ad-manager-rest`, `ad-manager-soap`, `merchant`,
`authorized-buyers-marketplace`, and `real-time-bidding`. Represent each
operation as implemented, planned, beta, SOAP, or
`allowlist-or-entitlement-required` according to the design.

**Completion Criteria**:

- [ ] Catalog includes Merchant, Ad Manager REST beta/SOAP, Authorized Buyers,
  and RTB entries without making unavailable methods callable.
- [ ] OAuth profiles are product-isolated and least-privilege for reader,
  writer, and admin intent.
- [ ] Tests prove reader-visible catalog behavior and writer/admin rejection for
  unimplemented publisher/commerce mutations.

### TASK-002: Merchant reader foundation

**Parallelizable**: Yes, after TASK-001 metadata names are stable

Create typed or safely bounded Merchant API request builders for accounts,
products, product statuses, data sources, promotions, local inventory, regional
inventory, reports, quotas, and supported account settings.

**Completion Criteria**:

- [ ] Request builders use only fixed Google Merchant origins.
- [ ] Merchant account and resource identifiers are validated before URL
  construction.
- [ ] Request-file schemas reject arbitrary URLs, oversized payloads, and unknown
  durable mutation fields in reader mode.
- [ ] Tests cover query encoding, pagination, report POST-as-reader handling, and
  sanitized provider errors.

### TASK-003: Ad Manager REST beta and SOAP readers

**Parallelizable**: Yes, after TASK-001 metadata names are stable

Add Ad Manager REST beta request builders and a SOAP adapter limited to official
read/report services. Pin the initial SOAP version before implementation and
record the decision in this plan or the final implementation notes.

**Completion Criteria**:

- [ ] REST beta and SOAP operations remain separate catalog surfaces.
- [ ] SOAP envelope construction uses service and method allowlists.
- [ ] SOAP reads cover the first bounded inventory, order, line item, creative,
  proposal, company, and report operations selected for this slice.
- [ ] SOAP fault handling is sanitized and raw envelopes are excluded from normal
  CLI output.

### TASK-004: Authorized Buyers and RTB readers

**Parallelizable**: Yes, after TASK-001 metadata names are stable

Add entitlement-aware request builders for Authorized Buyers Marketplace and
Real-time Bidding read operations.

**Completion Criteria**:

- [ ] Authorized Buyers Marketplace readers cover buyers, clients, proposals,
  deals, auction packages, publisher profiles, and finalized deals where
  request construction is locally testable.
- [ ] RTB readers cover bidders, buyers, creatives, pretargeting configs,
  publisher connections, user lists, endpoint status, and policy topics where
  request construction is locally testable.
- [ ] Catalog labels remain `allowlist-or-entitlement-required` until live
  entitlement is proven.
- [ ] Writer/admin operations for proposals, deals, creatives, user lists,
  pretargeting, endpoints, accounts, and publisher connections remain disabled.

### TASK-005: CLI routing and mutation safeguards

**Parallelizable**: No

Wire implemented reader operations into `Sources/GoogleMarketingGatewayReader/main.swift`
and verify writer/admin binaries preserve the plan/apply boundary for future
publisher/commerce mutations.

**Completion Criteria**:

- [ ] Reader CLI can dispatch only implemented read or non-durable report
  operations.
- [ ] Writer/admin CLIs reject all publisher/commerce mutations lacking a
  reviewed plan/apply implementation.
- [ ] Error messages are sanitized and do not print token values, raw SOAP
  envelopes, client identifiers beyond intentional CLI inputs, or secret config.

### TASK-006: Verification and documentation closure

**Parallelizable**: No

Run local verification and update implementation notes without live billable
Google actions.

**Completion Criteria**:

- [ ] `mise run lint`
- [ ] `mise run test`
- [ ] `mise run build`
- [ ] Narrow Swift tests for changed request/catalog surfaces pass before the
  full test suite.
- [ ] `git diff -- design-docs/publisher-commerce-capabilities.md impl-plans/publisher-commerce-capabilities.md Sources Tests`
  is reviewed for false coverage claims and secret leakage.

## Dependencies

- `design-docs/publisher-commerce-capabilities.md` is the accepted source of
  truth.
- Existing publisher code in
  `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift`,
  `Sources/GoogleMarketingGatewayCore/PublisherReportModels.swift`, and
  `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift` must keep
  AdSense and AdMob reader behavior stable.
- `Sources/GoogleMarketingGatewayReader/main.swift`,
  `Sources/GoogleMarketingGatewayWriter/main.swift`, and
  `Sources/GoogleMarketingGatewayAdmin/main.swift` define capability-separated
  routing boundaries.
- Exact Ad Manager SOAP version must be selected before TASK-003 implementation.
- Live Authorized Buyers and RTB entitlement is not assumed and is not required
  for non-network request-construction tests.

## Parallelizable Tasks

- TASK-001 can start independently.
- TASK-002, TASK-003, and TASK-004 can proceed in parallel after TASK-001
  stabilizes shared product identifiers and catalog conventions.
- TASK-005 depends on implemented request builders from TASK-002 through
  TASK-004.
- TASK-006 depends on all code changes selected for the implementation slice.

## Verification

- `sed -n '1,260p' design-docs/publisher-commerce-capabilities.md`
- `sed -n '1,260p' impl-plans/publisher-commerce-capabilities.md`
- `swift test --filter PublisherRequestTests`
- `mise run lint`
- `mise run test`
- `mise run build`
- `git diff -- design-docs/publisher-commerce-capabilities.md impl-plans/publisher-commerce-capabilities.md Sources Tests`
- `git status --short -- design-docs/publisher-commerce-capabilities.md impl-plans/publisher-commerce-capabilities.md Sources Tests`

## Completion Criteria

- [ ] Catalog coverage materially advances Merchant, Ad Manager, Authorized
  Buyers, and RTB without claiming method-level support that is not implemented.
- [ ] New request builders are typed or safely bounded, use fixed official
  origins, and validate all path/resource components.
- [ ] Reader/writer/admin capability separation remains enforced by tests.
- [ ] Product-isolated OAuth profiles avoid scope sharing across unrelated
  Google products.
- [ ] No unofficial scraping endpoints, billable live actions, campaign
  creation, spend, secret values, arbitrary URLs, or raw provider fault payloads
  are introduced.
- [ ] SwiftLint, tests, and build pass or any inability to run them is explicitly
  recorded.

## Addressed Feedback

- Step 3 accepted the design and found no high or mid findings.
- The plan directly targets `impl-plans/publisher-commerce-capabilities.md` as
  requested by fanout featureId `publisher-commerce`.
- The plan tracks the remaining Ad Manager SOAP version decision as a dependency
  rather than blocking planning.
- The plan preserves allowlist-or-entitlement-required handling for Authorized
  Buyers Marketplace and Real-time Bidding.

## Risks

- Ad Manager SOAP version choice can affect generated envelopes and tests if
  deferred too long.
- Merchant API sub-API version and quota differences can make a single shared
  request abstraction too loose unless operation metadata stays explicit.
- Authorized Buyers and RTB request construction can be tested locally, but live
  entitlement cannot be inferred from OAuth consent.
- Future writer/admin enablement may create durable account changes; this plan
  limits the current implementation to rejected or planned mutations unless a
  separate reviewed plan/apply path is added.

## Progress Log

- 2026-08-14: Plan created from accepted design
  `design-docs/publisher-commerce-capabilities.md` for featureId
  `publisher-commerce`.
