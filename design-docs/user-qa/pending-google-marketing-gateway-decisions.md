# Pending Google Marketing Gateway Decisions

**Status:** Provisional defaults awaiting later product-owner review
**Created:** 2026-08-13

These decisions unblock design review without user interruption. A later
decision changes the design and implementation plan; it does not silently alter
an already granted credential or enable a mutation.

## 1. Credential isolation

- **Provisional decision:** Use one credential profile per product, principal,
  and capability set; reject cross-product scope bundles by default.
- **Why confirmation is normally needed:** Fewer OAuth grants are more
  convenient, while isolated grants reduce blast radius and consent scope.
- **Why this choice is preferable:** It is the conservative least-privilege
  model and keeps revocation, audit, and account binding understandable.
- **If later rejected:** Add an explicit bundled-profile type, document its
  blast radius, update scope intersection tests, and require migration rather
  than merging token stores automatically.

## 2. Business transport and large results

- **Provisional decision:** Use one-shot GraphQL as the target unified business
  transport and opaque download keys for row-heavy reports; do not ship daemon
  mode first. Before GraphQL is implemented, completed reader slices may expose
  only closed, typed CLI routes backed by the same operation catalog and policy.
  Search Console has exactly the six routes named by its focused design. Decide
  whether to retain or deprecate those compatibility routes when the equivalent
  GraphQL operations exist; this later migration decision does not block the
  current bounded reader slice.
- **Why confirmation is normally needed:** Some callers may prefer REST or a
  persistent service, and inline results are simpler for small scripts.
- **Why this choice is preferable:** It matches `mail-gateway`, minimizes local
  lifecycle and attack surface, and prevents large reports consuming AI context.
- **If later rejected:** Design a separately authenticated transport while
  retaining the same operation registry, policy, result limits, and file model;
  do not allow transitional CLI routes to become arbitrary provider passthrough.

## 3. Executable capability boundaries

- **Provisional decision:** Replace the generic binary with reader, writer, and
  admin executables after one deprecation-shim release.
- **Why confirmation is normally needed:** This changes packaging and downstream
  command names and creates more release artifacts.
- **Why this choice is preferable:** Marketing products have materially
  different read, resource-edit, publish, identity, and destructive risks.
- **If later rejected:** Keep separate schemas and compile-time operation
  allowlists behind explicit modes; do not collapse authorization to one runtime
  flag or one broad schema.

## 4. Initial product boundary

- **Provisional decision:** Include the eight requested product families,
  ID-targeted YouTube Data metadata, and Google Tag Manager. Defer DV360,
  Campaign Manager 360, Search Ads 360, Business Profile, Play, Firebase, and
  BigQuery connectors.
- **Why confirmation is normally needed:** “Complete marketing” can include many
  enterprise and adjacent products with different eligibility and priorities.
- **Why this choice is preferable:** The chosen set covers acquisition,
  monetization, organic search, analytics, commerce, video, and measurement
  configuration while keeping entitlement-heavy products out of v1.
- **If later rejected:** Add one product through a focused design amendment with
  official scope, methods, quotas, account prerequisites, schema, and risk review
  before adding its adapter.

## 5. Google Trends

- **Provisional decision:** Expose no generally available Trends operation. Do
  not scrape or call unofficial endpoints. Treat Google's current offering as a
  limited alpha requiring approved access and a separate opt-in adapter review.
- **Why confirmation is normally needed:** A user with alpha entitlement may
  want Trends prioritized despite its non-general availability.
- **Why this choice is preferable:** It follows the official alpha page and
  avoids fabricating a public REST contract or violating the no-scraping rule.
- **If later rejected:** The user must provide proof of entitlement and the
  official alpha contract; then create a versioned, feature-flagged design. The
  no-scraping and no-unofficial-endpoint rules remain unchanged.

## 6. Mutation confirmation

- **Provisional decision:** Require plan/apply with a short-lived single-use
  token for admin operations and high-risk or ambiguous writes.
- **Why confirmation is normally needed:** Two-step execution adds latency and
  caller complexity.
- **Why this choice is preferable:** Google products vary in rollback and
  idempotency, and some broad scopes cannot enforce gateway role separation.
- **If later rejected:** Permit one-step execution only for an individually
  reviewed, documented-idempotent, reversible allowlist; admin operations remain
  two-step.

## 7. Principal types

- **Provisional decision:** Default to installed-app OAuth for the local CLI.
  Enable service accounts only for products whose official documentation allows
  them and only after explicit product-side access is granted. Exclude
  domain-wide delegation by default.
- **Why confirmation is normally needed:** Automated reporting may favor service
  accounts, while third-party or personal account access favors user OAuth.
- **Why this choice is preferable:** It works with a local user-consent flow and
  avoids assuming service-account or Workspace administrator authority.
- **If later rejected:** Add a product-specific principal policy and tests; do
  not make one service-account key an implicit cross-product identity.

## 8. Retention defaults

- **Provisional decision:** Retain ordinary materialized reports for 24 hours;
  monetary, access-control, user-level and audience-export artifacts for one
  hour; failed/partial temporary files for one hour; unclaimed mutation plans
  for ten minutes; and redacted receipts, consumed-token digests, mutation
  ledger entries and conclusively terminal job metadata for 30 days. Minimal
  unresolved mutation/job tombstones survive ordinary pruning until conclusive
  resolution or an operation-specific safe duplicate-risk horizon, indefinitely
  when no finite horizon exists. Configuration may
  shorten these values. Longer retention requires an explicit privacy-sensitive
  per-artifact override and later product-owner review. Encrypt materialized
  bytes at rest using authenticated per-artifact keys protected by the system
  credential store; use owner-only permissions, expiring renewable download
  leases with fencing, atomic no-follow output creation, and cleanup bound to a
  persisted exact file identity.
- **Why confirmation is normally needed:** Retention trades convenience and
  reproducibility against privacy and local disk exposure.
- **Why this choice is preferable:** Marketing and monetary reports may contain
  sensitive business information; indefinite cache retention is unsafe.
- **If later rejected:** Adopt reviewed per-product durations and key-management
  rules through a config/schema migration; do not silently extend existing
  artifacts, weaken safe file handling, or retain token material in receipts.

## 9. Durable one-shot state

- **Provisional decision:** Use an embedded SQLite database in the user-only
  state directory with transactional cross-process claims and crash-safe
  durability for plans, mutation ledgers, jobs, receipts, credential-generation
  barriers, cross-process quota reservations and download leases. Token bytes use
  immutable generation-tagged system-credential-store slots with recoverable
  SQLite pointer transactions. A non-secret monotonic state-epoch anchor remains
  outside SQLite backups so restore cannot reopen replayable state. Lease records
  use expiries, owner nonces, record versions and fencing generations so crashed
  owners can be safely superseded.
- **Why confirmation is normally needed:** A daemon or external database could
  centralize scheduling and operations, while a purely file-based design has
  fewer storage dependencies.
- **Why this choice is preferable:** It preserves the selected one-shot CLI,
  provides atomic interprocess correctness without a background service, and
  keeps private state local.
- **If later rejected:** Retain the same compare-and-set states, ownership,
  cross-store credential commit protocol, non-rollbackable restore epoch,
  durability, migration, recovery and fail-closed guarantees behind a reviewed
  store protocol; do not fall back to process-local actors or unlocked files.

## 10. Initial mutation exposure

- **Provisional decision:** Start writer and admin with empty mutation allowlists.
  Enable an exact mutation only through a focused design amendment and evidence-
  matrix entry covering provider method/version, scopes, preconditions,
  concurrency, idempotency, recovery, batch behavior, rollback, audit and tests.
- **Why confirmation is normally needed:** Product owners must prioritize which
  operational writes justify their blast radius and implementation cost.
- **Why this choice is preferable:** An empty default is least privilege and
  prevents broad provider scopes or a documented endpoint from becoming implicit
  permission before its irregular failure modes are reviewed.
- **If later rejected:** Record the requested operation priorities, but still add
  each field only through the same focused evidence and review path; do not use a
  wildcard product or method-family allowlist.

## 11. Initial reader operation baseline

- **Provisional decision:** Ship only the exact reader fields and provider
  methods listed in section 6.3 of the main design. Keep broad search, alpha-only
  methods, asynchronous audience-export creation, saved-report conveniences and
  every unlisted method absent until a focused evidence amendment is accepted.
- **Why confirmation is normally needed:** Product owners may value a different
  first set of reporting and inventory reads, and every added field increases
  quota, privacy, schema and long-term compatibility cost.
- **Why this choice is preferable:** The baseline supplies useful acquisition,
  publisher, commerce, organic, analytics and measurement reads while choosing
  stable or explicitly version-labelled methods and excluding server-resource
  creation and broad discovery.
- **If later rejected:** Reprioritize through an operation-level amendment that
  names the exact method/version, scope, quota dimensions, pagination, data
  class, handle lifecycle and tests; never enable an entire REST resource family
  or substitute a method silently.
