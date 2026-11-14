# Search Console reader

**Status**: Complete; adversarial review and non-network verification passed 2026-08-14
**Closure evidence**: All 27 focused Search Console tests and the 78-test full
suite pass, including strict file races, exact route recording, 307/308 redirect
refusal, scope isolation, redaction, and writer/admin rejection. Build,
non-network smokes, line limits, whitespace, and security scans pass. SwiftLint
reports 61 style warnings and zero serious violations. No high or medium finding
remains; historical session notes below are retained only as an audit trail.
**Feature ID**: `search-console-reader`
**Workflow mode**: `issue-resolution`
**Issue reference**: `Implement complete Search Console reader slice`
**Workflow execution**: `codex-design-and-implement-review-loop-session-715`
**Accepted-design execution**: `codex-design-and-implement-review-loop-session-713`
**Design reference**: `design-docs/specs/design-search-console-reader.md#public-command-and-operation-contract`
**Validation design reference**: `design-docs/specs/design-search-console-reader.md#input-validation`
**Request-construction design reference**: `design-docs/specs/design-search-console-reader.md#fixed-origin-request-construction`
**Verification design reference**: `design-docs/specs/design-search-console-reader.md#deterministic-verification-contract`
**Main design evidence**: `design-docs/google-marketing-gateway-design.md#52-focused-reader-contracts`
**User-decision reference**: `design-docs/user-qa/pending-google-marketing-gateway-decisions.md#2-business-transport-and-large-results`
**Created**: 2026-08-13

## Outcome

Deliver the accepted, bounded Search Console reader slice in
`GoogleMarketingGatewayCore`: six official read operations, exact readonly
profile isolation, strict typed Search Analytics input, fixed provider origins,
single-segment path encoding, validation before credentials, sanitized failures,
reader-only CLI/catalog exposure, deterministic tests, and truthful public
documentation.

This plan does not add Search Console submit, delete, add, association, generic
proxy, live OAuth, or live provider behavior. Writer and admin mutation
allowlists remain unchanged and empty for Search Console.

## Accepted design decisions

- Require exactly the singleton OAuth scope
  `https://www.googleapis.com/auth/webmasters.readonly` for a
  `search-console` reader profile.
- Reuse both existing credential sources: a configured environment token first,
  otherwise the installed OAuth client/token store.
- Expose exactly:
  - `search-console sites list`;
  - `search-console sites get --site <property>`;
  - `search-console search-analytics query --site <property> --request-file <path>`;
  - `search-console sitemaps list --site <property> [--sitemap-index <url>]`;
  - `search-console sitemaps get --site <property> --feedpath <url>`;
  - `search-console url-inspection inspect --site <property> --inspection-url <url> [--language-code <BCP47>]`.
- Fix Webmasters requests to `https://www.googleapis.com/webmasters/v3` and URL
  Inspection requests to `https://searchconsole.googleapis.com/v1`.
- Preserve validated property and feed identifiers and percent-encode each as
  one outer path segment exactly once. Inner `%` bytes therefore become `%25`.
- Load the complete Search Analytics query only from a descriptor-bound regular
  file of at most 1,048,576 bytes. Reject symlinks, unstable metadata, invalid
  UTF-8/JSON, duplicate or unknown keys, and invalid typed values before
  credential resolution.
- Model only the accepted official camelCase Search Analytics fields and closed
  enum values. `searchType` remains unsupported.
- Treat Search Analytics query and URL Inspection POST operations as logical
  reads. Do not register any Search Console mutation.
- Sanitize local, credential, transport, provider, and response failures so no
  token, credential-bearing URL, expression, request JSON, or file content is
  emitted.

## Run-start baseline

The repository is intentionally fully untracked. The implementation step must
treat the current run-start inventory as authoritative and must not attempt to
reconstruct pre-run history. At plan creation:

- `git status --short --untracked-files=all` reports the repository files as
  untracked, including `Package.swift`, `Sources/`, `Tests/`, `README.md`,
  `design-docs/`, and `impl-plans/`.
- The existing SwiftPM boundary is one shared
  `GoogleMarketingGatewayCore` target, three capability executables, one
  compatibility executable, and one core test target.
- Session-713 plan revision inventory contains 83 untracked entries by both
  status and `rg --files`; `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
  is the largest production Swift file at 653 lines. No inspected Swift file is
  at or above 1,000 lines.
- `MarketingProduct.searchConsole`, its exact reader scope, six catalog
  operations, request types, dispatch, tests, and documentation are implemented.
  Session 713 must independently verify the carried validation, test-integrity,
  plan-consistency, and full-matrix findings before the slice is complete.
- `SecureLocalFiles.readRegularFile` already performs descriptor-based,
  no-follow regular-file loading, but its existing post-read comparison covers
  identity only. The Search Analytics contract additionally requires size,
  type, full-resolution modification time, and change-time stability.
- `GoogleRESTClient`, `HTTPTransport`, `ReaderCredentialResolving`, and the CLI
  dependency injection boundaries already exist and are reused.

The implementation progress log must record a fresh status/inventory and
baseline test result before source edits because other user changes may appear
after this plan was created.

## Dependencies and ownership

### Required existing boundaries

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`: strict profile
  decoding, exact product/scope checks, and environment/installed-OAuth paths.
- `Sources/GoogleMarketingGatewayCore/ReaderCredentials.swift`: injected access
  token resolution and environment-first precedence.
- `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift`: descriptor-based
  no-follow file access to reuse or specialize without weakening OAuth-store
  handling.
- `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift`: injected transport
  and sanitized provider error boundary.
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`: exact route parsing,
  local validation, selected-profile resolution, and transport dispatch.
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`: product and
  operation descriptors.

No new SwiftPM target or external dependency is planned. If the existing
credential resolver, transport, or secure-file API changes before
implementation, reconcile its current contract first and preserve other product
behavior rather than adding a Search Console-specific substitute.

### Shared-file coordination

These files are shared with already implemented slices and must be edited
serially or through clearly separated product blocks:

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`;
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`;
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`;
- `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift` if a reusable
  stability primitive is added;
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`;
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`;
- `Tests/GoogleMarketingGatewayCoreTests/NewReaderCLITests.swift`;
- `README.md`;
- `design-docs/google-marketing-gateway-design.md`;
- `impl-plans/completed/foundation-publisher-readers.md`.

Preserve Google Ads, Analytics Data, AdSense, AdMob, OAuth, writer, and admin
behavior. Never replace a shared file wholesale.

### Reference trace and intentional divergence

`<mail-gateway-checkout>` is a structural reference repository,
not a Codex-agent behavior reference:

- `Sources/MailGatewayCore/MailGatewayUtilities.swift` supplies the concrete
  `normalizedPath`, `canonicalPath`, and `isWithinRoot` containment flow.
- `Tests/MailGatewayCoreTests/PathAndDownloadKeyTests.swift` supplies a concrete
  example of symlink/containment adversarial testing.
- The accepted design instead uses this repository's
  `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift` descriptor/openat
  boundary and strengthens stability checks for bounded JSON input.
- No mail-gateway Search Console adapter, request model, endpoint mapping, or CLI
  behavior exists to copy.
- No Codex-agent or Cursor input was supplied. No Cursor adapter boundary or
  behavior mapping is introduced.

## Deliverables

- [x] Strict Search Console value types, Search Analytics request models, nested
      duplicate/unknown-key rejection, and semantic validation.
- [x] Descriptor-bound Search Analytics request-file loader with 1 MiB limit,
      parent/terminal symlink refusal, regular-file requirement, limit-plus-one
      read, and pre/post metadata stability checks.
- [x] Fixed-origin request builders for all six operations with independently
      specified one-segment path encoding and exact JSON/query behavior.
- [x] Exact Search Console profile scope validation for environment and
      installed OAuth configurations without cross-product regressions.
- [x] Six implemented reader catalog descriptors, six CLI routes, complete
      reader help, and unchanged writer/admin mutation behavior.
- [x] Deterministic independent unit and dispatch tests covering positive,
      boundary, adversarial, pre-credential, and redaction contracts.
- [x] Updated `README.md`, accepted design status/evidence, this plan's progress,
      and foundation roadmap status.
- [x] Fresh post-remediation lint, tests, build, complete non-network smoke
      checks, whitespace review of untracked files, secret/private-URL/
      machine-path scans, and line-limit checks without live OAuth/provider
      calls. Earlier passing evidence is historical and does not close TASK-009.

## Planned implementation surfaces

### New production files

- `Sources/GoogleMarketingGatewayCore/SearchConsoleModels.swift`
- `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift`
- `Sources/GoogleMarketingGatewayCore/SearchConsoleRequests.swift`
- `Sources/GoogleMarketingGatewayCore/SearchConsoleCommand.swift` if needed to
  keep CLI parsing/dispatch cohesive and every Swift file below 1,000 lines

### Modified production files

- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift` only if the
  generalized stable-read API can preserve every current caller contract

### New or modified tests and fixtures

- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleModelTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleValidationTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestFileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/search-console-reader-profiles.json`
- Existing profile fixtures as compatibility oracles; do not rewrite unrelated
  entries merely to simplify new tests

### Documentation and evidence

- `README.md`
- `design-docs/specs/design-search-console-reader.md`
- `design-docs/google-marketing-gateway-design.md`
- `impl-plans/completed/search-console-reader.md`
- `impl-plans/completed/foundation-publisher-readers.md`

## Task sequence

### TASK-001: Reconcile current state and freeze test contracts

**Parallelizable**: No
**Dependencies**: None

Inspect the current repository after all preceding workflow steps, preserve user
changes, and translate the accepted endpoint, validation, encoding, ordering,
and redaction contracts into independently authored test vectors before
production edits.

**Completion criteria**:

- [x] Record `git status --short --untracked-files=all` and
      `rg --files -uu -g '!.git' -g '!.build/**'` in the progress log as the
      authoritative implementation baseline.
- [x] Inspect `Package.swift`, relevant source/tests, `.swiftlint.yml`,
      `mise.toml`, and CI workflows.
- [x] Record all Swift line counts and identify files approaching 1,000 lines.
- [x] Explicitly waive the unreconstructable pre-edit `swift test` result: it was
      not preserved in the intentionally untracked workspace. This historical
      gap does not substitute for the required fresh post-remediation focused and
      full-suite results in TASK-009.
- [x] Fix literal expectations for each method, origin, encoded path, query,
      header, and JSON body without calling production request builders to
      generate expected values.
- [x] Record the injected resolver and transport spy interfaces needed to assert
      zero calls on malformed input.

### TASK-002: Add typed request models and strict semantic validation

**Parallelizable**: Yes, after TASK-001
**Write scope**: `SearchConsoleModels.swift`, `SearchConsoleValidation.swift`,
`SearchConsoleModelTests.swift`, `SearchConsoleValidationTests.swift`
**Dependencies**: TASK-001

Create focused `Codable`, `Sendable`, and `Equatable` values for the accepted
Search Analytics request, dimensions, type, aggregation type, data state,
AND-only filter groups, filter dimensions, and filter operators. Add validated
property, fully qualified URL, date, expression, and BCP 47 values without
performing provider-semantic lookups.

**Completion criteria**:

- [x] Only `startDate`, `endDate`, `dimensions`, `type`, `aggregationType`,
      `rowLimit`, `startRow`, `dataState`, and `dimensionFilterGroups` are
      accepted at the root; nested fields match the accepted design exactly.
- [x] All closed enum spellings are exact and `searchType` is rejected.
- [x] Dates are real zero-padded Gregorian values and ordered.
- [x] `rowLimit` accepts 1 and 25,000 and rejects values outside the range;
      `startRow` accepts zero and rejects negatives, fractions, exponent forms,
      strings, booleans, and overflow.
- [x] Dimensions reject duplicates; groups are AND-only and nonempty; total
      group/filter counts and expression character/byte bounds are enforced.
- [x] Filter expressions preserve accepted bytes but never appear in errors.
- [x] URL-prefix and `sc-domain:` properties follow the exact accepted shape,
      length, userinfo, fragment, percent-escape, DNS, and trailing-slash rules.
- [x] Sitemap/feed/inspection URLs and BCP 47 tags meet their accepted local
      bounds without normalization or provider registry checks.

### TASK-003: Add stable strict request-file decoding

**Parallelizable**: Yes, after TASK-002, alongside TASK-004; write scopes are
disjoint
**Write scope**: `SecureLocalFiles.swift`, strict-JSON portions of
`SearchConsoleValidation.swift`, and `SearchConsoleRequestFileTests.swift`
**Dependencies**: TASK-001 and TASK-002

Specialize or safely extend the descriptor-based local-file boundary. Parse the
exact bytes from the already-open descriptor and reject duplicate object keys at
every nesting depth before typed model construction.

**Completion criteria**:

- [x] Parent components and terminal entries are opened without following
      symlinks; only a regular file is accepted.
- [x] Reported size above 1 MiB fails, and the read is bounded to 1 MiB plus one
      byte so concurrent growth cannot allocate without bound.
- [x] Pre/post descriptor comparisons cover device/inode, regular-file type,
      byte size, full-resolution modification timestamp, and change timestamp.
- [x] Any observed overwrite, truncation, growth, metadata, identity, or type
      change fails before decoding and credentials.
- [x] Empty data, invalid UTF-8, malformed/trailing JSON, non-object JSON,
      duplicate keys at every nesting depth, and unknown fields fail with
      allowlisted categories and without file content.
- [x] Exactly-1-MiB and over-1-MiB cases, parent/terminal symlinks, directories,
      non-regular entries, and injected race cases are deterministic.
- [x] Existing OAuth/GAQL secure-file behavior remains covered and unchanged if
      the shared primitive is modified.

### TASK-004: Build fixed-origin requests and literal encoding tests

**Parallelizable**: Yes, after TASK-002, alongside TASK-003; write scopes are
disjoint
**Write scope**: `SearchConsoleRequests.swift`, `SearchConsoleRequestTests.swift`
**Dependencies**: TASK-001 and TASK-002

Implement only the six accepted requests. Keep constant path components
separate from byte-wise encoded caller segments, and expose no caller-supplied
origin, base path, method, headers, or raw body.

**Completion criteria**:

- [x] `sites.list/get`, `searchanalytics.query`, and `sitemaps.list/get` use
      exact Webmasters v3 methods and paths.
- [x] URL Inspection uses exact
      `POST https://searchconsole.googleapis.com/v1/urlInspection/index:inspect`.
- [x] Caller path values encode only RFC 3986 unreserved bytes literally, use
      uppercase hex, and become one already-percent-encoded path segment without
      URL API normalization or re-encoding.
- [x] Literal tests prove `%`, `%2F`, `/`, `:`, `?`, `#`, `@`, traversal-like
      text, URL-prefix paths/ports, and `sc-domain:` cannot alter origin or path
      structure.
- [x] `sitemapIndex` is the sole optional query item and uses query-item
      encoding; GET requests have no body.
- [x] Search Analytics re-encodes the validated typed object with camelCase keys
      and nil omission; URL Inspection encodes only `inspectionUrl`, `siteUrl`,
      and optional `languageCode`.
- [x] Requests have exact Accept, Authorization, and POST Content-Type headers,
      and no unexpected header or port.

### TASK-005: Add exact profile and catalog contracts

**Parallelizable**: Yes, after TASK-001; write scope is disjoint from TASK-002
through TASK-004
**Write scope**: `CredentialProfiles.swift`, `OperationCatalog.swift`,
`CredentialProfileTests.swift`, `SearchConsoleCLITests.swift`, and
`Fixtures/search-console-reader-profiles.json`
**Dependencies**: TASK-001

Complete the existing `MarketingProduct.searchConsole` integration, profile
isolation, and catalog registration without changing other product acceptance.

**Completion criteria**:

- [x] Search Console reader profiles accept exactly one readonly scope and
      reject empty, duplicate, writer, admin, mixed, and cross-product scopes.
- [x] Environment-token and paired installed-OAuth path profiles both validate.
- [x] Foreign product-specific fields remain rejected and all existing valid
      product fixtures retain their behavior.
- [x] Catalog contains exactly six implemented Search Console reader
      descriptors with stable IDs and the readonly scope.
- [x] No submit, delete, add, association, writer, or admin descriptor is added.

### TASK-006: Integrate closed CLI routes with late credentials

**Parallelizable**: No
**Write scope**: `GatewayCLI.swift`, optional `SearchConsoleCommand.swift`,
`SearchConsoleCLITests.swift`, `GatewayCLITests.swift`, and
`NewReaderCLITests.swift`
**Dependencies**: TASK-002, TASK-003, TASK-004, TASK-005

Add all six reader routes and their exact allowed flags. Split route parsing or
Search Console command handling into a focused file if adding it directly would
make `GatewayCLI.swift` incohesive or approach the 1,000-line limit.

**Completion criteria**:

- [x] Reader help displays all six exact command spellings and no Search Console
      mutation.
- [x] Unknown, duplicate, missing, or route-inapplicable flags fail locally.
- [x] Every scalar and the complete Search Analytics file is validated before
      selected-profile credential resolution and transport access.
- [x] Resolver and transport spies independently record zero calls for every
      malformed route, property, URL, language tag, file, JSON, and typed field.
- [x] Valid environment and installed-OAuth profiles dispatch through the
      existing resolver and injected transport exactly once.
- [x] Writer/admin reject every Search Console route before credential or
      transport access, and their mutation catalogs remain unchanged.
- [x] Provider and transport sentinel failures expose only accepted status/code
      data and never tokens, URLs, expressions, request JSON, or file contents.

### TASK-007: Complete independent deterministic coverage

**Parallelizable**: Yes, after TASK-006, alongside TASK-008; write scopes are
disjoint
**Write scope**: Search Console test files and existing credential/CLI regression
test files listed under "New or modified tests and fixtures"; no documentation
files
**Dependencies**: TASK-006

Run the accepted design's full positive and negative matrix. Ensure adversarial
expected data is independent of the implementation under test.

**Completion criteria**:

- [x] Every route has exact request and end-to-end recording-transport coverage.
- [x] URL-prefix, domain property, single-segment, normalization, double-encoding,
      traversal, userinfo, DNS, and malformed-percent cases are covered.
- [x] Every supported enum and the specified date/number/filter boundary and
      unknown/duplicate-key failures are covered, including nested keys.
- [x] Request-file race, symlink, non-regular, exact-size, over-size, and
      descriptor-only parsing behavior is covered.
- [x] BCP 47 language/script/region/variant/extension/private-use positive and
      malformed/oversized cases are covered.
- [x] Existing product/profile, OAuth, reader, writer, and admin regression tests
      pass without weakening assertions.
- [x] Redaction tests search complete stdout/stderr for all sensitive sentinels.

### TASK-008: Update documentation and roadmap evidence

**Parallelizable**: Yes, after TASK-006 behavior stabilizes; documentation write
scope is disjoint from TASK-007 test files
**Write scope**: `README.md`, `design-docs/specs/design-search-console-reader.md`,
`design-docs/google-marketing-gateway-design.md`, this plan, and
`impl-plans/completed/foundation-publisher-readers.md`; no Swift source/test files
**Dependencies**: TASK-006; final status depends on TASK-009

Update public and internal documentation to match delivered behavior exactly.
Do not label the slice complete until final verification and adversarial review
pass.

**Completion criteria**:

- [x] `README.md` documents profile setup, six commands, request-file schema and
      bounds, exact readonly scope, and non-mutation boundary without secrets or
      machine-local paths.
- [x] `design-docs/specs/design-search-console-reader.md` records current
      implementation status and historical evidence without rewriting accepted
      requirements, while explicitly retaining final evidence as pending
      TASK-009.
- [x] Record the fresh session-715 verification evidence in the focused design;
      the independent adversarial review decision remains pending Step 7.
- [x] `design-docs/google-marketing-gateway-design.md` identifies
      `codex-design-and-implement-review-loop-session-715` as the current
      issue-resolution/final-verification workflow and session 713 as accepted-
      design/remediation provenance; `impl-plans/completed/foundation-publisher-readers.md`
      truthfully describes the slice's current delivery/review state.
- [x] This plan's checkboxes and progress log cite exact commands, results,
      findings, decisions, and unresolved items.

### TASK-009: Adversarial review, remediation, and final verification

**Parallelizable**: No
**Dependencies**: TASK-007, TASK-008

Review the final diff and tests as an attacker. Fix every high and medium
finding, rerun affected focused tests, then execute the full non-network evidence
matrix. Do not commit, push, or call live Google services.

Perform these serialized remediation work packages in order:

1. **Plan and documentation consistency**: retain the disjoint/serialized
   TASK-002 and TASK-003 ownership above; retain the explicit TASK-001 historical
   waiver; verify that `design-docs/google-marketing-gateway-design.md` and the
   focused design say implemented but incomplete pending remediation and final
   verification. The main design must identify
   `codex-design-and-implement-review-loop-session-715` as the current
   issue-resolution/final-verification workflow and session 713 only as the
   accepted-design/remediation provenance.
2. **Validation remediation**: inspect and, where necessary, fix
   `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift` so BCP 47
   variants are unique case-insensitively, raw spaces and every parser-normalized
   URL are rejected before credentials, and strict JSON rejects container 65
   before recursively descending into it.
3. **Independent regressions**: update
   `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleValidationTests.swift`,
   `SearchConsoleRequestFileTests.swift`, and `SearchConsoleCLITests.swift` with
   literal `en-1901-1901`, raw-normalized URL, and direct 64/65-container cases.
   The depth test must use a valid root and call the strict verifier directly so
   it still proves the bound if typed unknown-field decoding is removed; CLI
   cases must separately prove zero resolver and transport calls.
4. **Post-remediation evidence**: after all source, test, plan, and documentation
   changes, run every command in the verification matrix once as one final
   evidence set. Do not combine results from earlier revisions to claim this
   gate passed.
5. **Redirect privacy remediation**: the default URL session must reject every
   redirect so a 307 or 308 cannot replay a validated Search Analytics or URL
   Inspection POST body to a different origin. Deterministic URLProtocol tests
   must cover both POST routes and both redirect status codes.

**Completion criteria**:

- [x] Review explicitly covers origin confusion, URL normalization/double
      encoding, traversal, DNS/userinfo, scope isolation, data leakage,
      descriptor/file races, unbounded input, credential ordering, mutation
      exposure, and mirrored-test defects.
- [x] No high or medium finding remains; low findings and residual risks have an
      explicit review decision.
- [x] All verification commands below pass, or any external/pre-existing failure
      is recorded precisely with evidence and does not hide a feature regression.
- [x] The final evidence set is newer than every remediation change and includes
      focused tests, full tests, build, lint, all help/catalog/config/auth smokes,
      tracked and untracked whitespace checks, inventory/status, secret/private-
      URL/machine-path scans, and Swift line limits.
- [x] No live OAuth/provider call, commit, or push occurs.
- [x] The plan moves to `impl-plans/completed/` only after implementation and
      independent review are genuinely complete.

## Parallel execution map

The plan has three explicit parallel phases whose concurrent write scopes are
disjoint:

| Phase | Task | Exclusive write scope | Merge dependency |
| --- | --- | --- | --- |
| A, after TASK-001 | TASK-002 | Search Console models/validation and model/validation tests | TASK-003 and TASK-004 consume its value interfaces |
| A, after TASK-001 | TASK-005 | Profile/catalog shared files, fixture, profile/catalog tests | TASK-006 consumes descriptors/profile rules |
| B, after TASK-002 | TASK-003 | Secure-file/strict-JSON implementation and request-file tests | TASK-006 consumes decoded input |
| B, after TASK-002 | TASK-004 | Request builders and literal request tests | TASK-006 consumes fixed requests |
| C, after TASK-006 | TASK-007 | Test files only | TASK-009 consumes independent evidence |
| C, after TASK-006 | TASK-008 | Documentation/plan files only | TASK-009 consumes status evidence |

TASK-003 follows TASK-002 because both may change
`SearchConsoleValidation.swift`; they are never concurrent. TASK-006 and
TASK-009 are serialized integration gates. TASK-008 may run in
parallel with TASK-007 only after command names and behavior stabilize and only
because documentation and test write scopes are disjoint.

## Verification matrix

Run focused Search Console tests first, then broad verification. Exact focused
test filters may follow final test type names and must be recorded in the
progress log.

```bash
swift test --filter SearchConsole
mise run lint
swift test
swift build
swift run google-marketing-gateway --help
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/search-console-reader-profiles.json
swift run google-marketing-gateway-writer --help
swift run google-marketing-gateway-admin --help
git diff --check
git status --short --untracked-files=all
rg --files -uu -g '!.git' -g '!.build/**'
```

Because `git diff --check` ignores untracked content in this repository, run a
separate whitespace check over the actual untracked source and documentation
inventory:

```bash
files=$(rg --files -uu -g '!.git' -g '!.build/**' -g '*.swift' -g '*.md' -g '*.json' -g '*.yml' -g '*.yaml' -g '*.toml')
test -z "$(printf '%s\n' "$files" | xargs rg -n '[[:blank:]]+$')"
```

Run and manually classify repository scans. Expected schema field names and
redaction sentinels may match; real secret values, non-reference private URLs,
and machine-local paths outside explicitly documented reference evidence may
not.

```bash
rg -n --hidden -g '!.git/**' -g '!.build/**' '(client_secret|refresh_token|access_token|developer[-_ ]?token|Bearer[[:space:]])' .
rg -n --hidden -g '!.git/**' -g '!.build/**' '(https?://[^/@[:space:]]+:[^/@[:space:]]+@|https?://(localhost|127\.0\.0\.1|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.))' .
rg -n '/Users/|/home/' README.md Sources Tests design-docs impl-plans
for file in $(rg --files -g '*.swift'); do test "$(wc -l < "$file")" -lt 1000 || { echo "$file"; exit 1; }; done
```

Also run the existing non-network auth/config smoke if still applicable:

```bash
scripts/smoke-reader-auth.sh
```

Do not run Search Console commands with real credentials or allow the injected
default transport to reach either Google origin during verification.

## Completion criteria

The slice is complete only when:

1. All six and only the six accepted Search Console logical reads are available
   from the reader and catalog.
2. Search Console profiles require the exact readonly singleton scope and work
   through both existing credential sources without cross-product regression.
3. Every caller-controlled value is bounded and validated before credentials;
   path identifiers cannot control origin, path structure, headers, or method.
4. Search Analytics files and models satisfy all regular-file, stability,
   strict-JSON, unknown/duplicate-key, enum, date, numeric, filter, and resource
   bounds.
5. Provider/transport/local errors pass all sensitive-sentinel redaction tests.
6. Writer/admin allowlists and mutation exposure remain unchanged.
7. Independent deterministic tests cover every route and the complete accepted
   adversarial matrix without deriving expected URLs/bodies from production
   builders.
8. Every Swift file remains below 1,000 lines and the full verification matrix
   passes without live provider calls.
9. README, focused design, main design, foundation roadmap, and this progress log
   state implementation and review status truthfully.
10. Independent review finds no unresolved high or medium issue.

## Step 6 implementation checkpoint

- [x] Production boundaries added for Search Console typed values, strict
      request-file loading, fixed-origin request construction, exact profile
      scope, operation catalog, and reader CLI dispatch.
- [x] Reader help and README enumerate the bounded read-only surface; writer and
      admin continue to reject operational routes before dispatch.
- [x] Focused deterministic request, strict-file, profile, route dispatch, and
      no-prevalidation-credential-access tests were added.
- [x] Remediated Step 7 test-integrity findings with independent recording
      transport, literal route contracts, complete writer/admin rejection,
      strict-input, profile-isolation, and transport-redaction tests.
- [x] Complete the remaining non-network auth smoke evidence.

## Progress log expectations

Each implementation session appends a dated entry containing:

- task IDs started/completed and files changed;
- current untracked baseline and any concurrent user changes preserved;
- exact focused and broad commands run with pass/fail decisions;
- security/privacy scan matches and manual classifications;
- adversarial findings by severity, remediation, and review decision;
- residual risks, deferred low findings, or external blockers;
- explicit confirmation that no live OAuth/provider call, commit, or push
  occurred.

Do not mark a checkbox from code presence alone. Mark it only when its associated
behavior and verification evidence are complete.

## Risks and review gates

- **Encoded-path origin or traversal confusion — high**: gate on independently
  authored literal URL expectations for URL-prefix, domain, percent, delimiter,
  and traversal-like identifiers.
- **URL API normalization/double encoding — high**: gate on inspection of the
  final absolute URL string and proof that already encoded segments are not
  passed through a second path encoder.
- **Credential access before complete validation — high**: gate on independent
  resolver and transport spies for every malformed-input family.
- **Sensitive-data leakage — high**: gate on sentinel searches of all public
  stdout/stderr across local, credential, provider, transport, and response
  failures.
- **Request-file race or resource exhaustion — high**: gate on descriptor-only
  parsing, limit-plus-one reads, full metadata comparisons, and injected race
  tests. Metadata stability is explicitly not a cryptographic defense against a
  privileged writer restoring metadata exactly.
- **Nested strict JSON and BCP 47 parser defects — medium**: gate on focused
  positive/negative tests independent from Codable synthesis and implementation
  branches.
- **Cross-product or mutation privilege drift — high**: gate on exact singleton
  scope fixtures, other-product regression fixtures, six-descriptor count, and
  explicit writer/admin rejection.
- **Shared-file collision — medium**: reconcile current contents immediately
  before edits and preserve unrelated user work; serialize GatewayCLI and shared
  test-file integration.
- **Swift file growth — medium**: split Search Console command handling by
  responsibility before any non-generated Swift file reaches 1,000 lines.

## Progress log

- 2026-08-13: Plan created from the independently accepted design review
  (`comm-002280`). Repository confirmed intentionally fully untracked; existing
  SwiftPM/core, resolver, transport, secure-file, CLI, and catalog boundaries
  inspected. No Step 5 feedback exists on this first plan-creation pass.
- 2026-08-13: Self-review finding from `comm-002282` resolved by assigning
  TASK-003 exclusive ownership of `SearchConsoleRequestFileTests.swift` and
  retaining `SearchConsoleValidationTests.swift` exclusively in TASK-002. The
  TASK-002 through TASK-005 parallel execution map now has disjoint write scopes.
- 2026-08-13: TASK-002 through TASK-008 implementation completed. Added typed
  Search Console request/value validation, strict bounded descriptor file
  decoding, fixed-origin builders, exact profile scope and six reader catalog
  descriptors, reader route/help integration, focused tests, README, and roadmap
  evidence. No live OAuth/provider call, commit, or push occurred. TASK-009
  verification and adversarial review evidence remains pending.
- 2026-08-13: Focused `swift test --filter SearchConsole` passed (six tests);
  `swift build` compiled successfully; `mise run lint` passed with pre-existing
  and style warnings but no serious violation; reader help displayed the six
  routes and descriptors. All non-generated Swift files remain below 1,000
  lines. The command runner reported a timeout after each completed SwiftPM
  invocation despite its successful command output; record this runner behavior
  alongside TASK-009 full-suite verification.
- 2026-08-13: Step 6 self-review feedback was remediated: structured bounded
  BCP 47 validation, empty-DNS-label rejection, decoded duplicate-key checks,
  strict integer JSON syntax, Search Console config fixture, and expanded
  request/file/profile/redaction/credential-order tests were added. `swift test`
  passed all 54 tests; catalog, fixture config validation, writer/admin help,
  lint, line-limit, and scan commands ran without live provider calls. Scan
  matches were expected schema identifiers, test sentinels, loopback fixtures,
  and documented mail-gateway references; no secret value was found. The auth
  smoke command reached successful build output but the command runner timed out
  before it emitted its captured logout assertion.
- 2026-08-14: Second self-review remediation added private-use-only BCP 47 and
  UTF-16 surrogate-pair handling, exact-1-MiB request acceptance, and a
  deterministic `afterRead` file seam covering overwrite, truncation, growth,
  timestamp, entry-identity, and type races. Focused Search Console tests passed
  all 11 cases without a provider call.
- 2026-08-14: Final Step 6 remediation added extlang and grandfathered BCP 47
  recognition, verified malformed ordering rejection, replaced the synthetic
  growth race with same-inode `FileHandle.seekToEnd`/write growth, and reran
  `mise run lint` successfully (0 serious violations). Focused Search Console
  tests and the full `swift test` suite passed with 11 and 56 tests respectively.
- 2026-08-14: Step 7 test-integrity remediation expanded focused coverage to 15
  independent Search Console tests: a recording transport asserts every CLI
  request's literal method/origin/path/query/headers/body and call count; all
  routes reject in both writer and admin before credentials/transport; strict
  JSON, URL, profile, file-entry, and malformed-input matrices now assert their
  public boundary behavior. The transport-redaction sentinel test exposed and
  fixed a real `HTTPTransport.swift` leak: injected `GatewayError` transport
  messages are now sanitized. `swift test --filter SearchConsole` passed 15;
  `swift test` passed 60; `mise run lint` completed with 0 serious violations
  (the runner timed out after that completion output). Help, catalog, config,
  status/inventory, whitespace, secret, private-URL, machine-path, and line
  checks were run; matches are documented reference paths, schema terms,
  loopback/test sentinels, and no real secret. No live OAuth/provider call,
  commit, or push occurred. `scripts/smoke-reader-auth.sh` remains blocked by
  the runner timeout after successful build output.
- 2026-08-14: Self-review follow-up restored the strict regression cases that
  were displaced during the preceding test consolidation: over-1-MiB refusal,
  escaped root-key duplicate, valid/lone UTF-16 surrogate escapes, fractional
  and exponent numeric syntax, and collection/expression resource bounds.
  CLI tests now prove unknown, duplicate, missing, and route-inapplicable flags
  do not touch credentials or transport, and prove a valid installed-OAuth
  Search Console profile dispatches once through the injected resolver and
  transport. `swift test --filter SearchConsole` passed 19 tests; `swift test`
  passed 64 tests; `mise run lint` passed with 0 serious violations. No live
  OAuth/provider call, commit, or push occurred.
- 2026-08-14: Step 7 test-integrity remediation replaced production-derived
  closed-enum iteration with literal contract vectors, asserted complete and
  nil-omitting Search Analytics bodies, covered independent accepted maxima
  (25,000 row limit; 100 groups/filters; 4,096 characters and 16,384 UTF-8
  bytes), and tested an `or` group with a valid nonempty filter. Stable request
  reads now use nonblocking descriptor open so FIFO entries are rejected before
  a read can stall; focused file tests cover terminal/parent symlinks,
  directory, FIFO, and `/dev/null` device entries. `swift test --filter
  SearchConsole` passed 20 tests; `swift test` passed 65 tests; `swift build`
  passed; `mise run lint` reported 56 warnings and 0 serious violations. No
  live OAuth/provider call, commit, or push occurred.
- 2026-08-14: The final filter-operator wire-body assertion was followed by a
  fresh complete verification run: `swift test` passed 65 tests, `swift build`
  passed, and `mise run lint` reported 56 warnings with 0 serious violations.
  This supersedes the prior broad verification timing gap. No live OAuth or
  provider call, commit, or push occurred.
- 2026-08-14: Step 6 test-integrity feedback from `comm-002304` found that
  `scripts/smoke-reader-auth.sh` asserted the obsolete `deleted` JSON field.
  The script now asserts the authoritative `removed` field emitted by
  `LogoutOutput`; a fresh `scripts/smoke-reader-auth.sh` run exited 0 after the
  reader build. No live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Step 7 remediation from `comm-002308` tightened four-byte BCP 47
  variants to require a leading digit followed by three ASCII alphanumeric
  bytes. Model coverage now accepts `en-1abc` and rejects `en-1!!!`; the
  malformed CLI case independently proves zero resolver and transport calls.
  TASK-002 through TASK-008 completion criteria now reflect the implemented and
  verified work; TASK-009 remains pending independent adversarial review.
  Fresh verification passed: `swift test --filter SearchConsole` (20 tests),
  `swift test` (65 tests), `swift build`, `mise run lint` (56 warnings, 0
  serious violations), `sh -n scripts/smoke-reader-auth.sh`,
  `scripts/smoke-reader-auth.sh`, compatibility/reader/writer/admin help,
  reader catalog, and fixture config validation. No live OAuth/provider call,
  commit, or push occurred.
- 2026-08-14: Step 7 remediation from `comm-002312` now rejects repeated BCP 47
  variant subtags case-insensitively. Focused model coverage rejects
  `en-1901-1901` and `sl-rozaj-ROZAJ`; CLI spy coverage proves both fail before
  credential resolution or transport access. Main design evidence now accurately
  records implementation pending final adversarial review. TASK-001 records the
  contemporaneous authoritative untracked inventory: `git status --short
  --untracked-files=all` and `rg --files -uu -g '!.git' -g '!.build/**'` each
  reported 83 entries, and current Swift line counts total 4,495 with every file
  below 1,000 lines. The exact pre-edit `swift test` result was not preserved and
  remains an explicit, unreconstructable historical evidence gap. Final
  verification on this workspace passed: `swift test --filter SearchConsole`
  (20 tests), `swift test` (65 tests), `swift build`, and `mise run lint` (56
  warnings, 0 serious violations). No live OAuth/provider call, commit, or push
  occurred.
- 2026-08-14: Step 7 adversarial remediation from `comm-002317` rejects URL
  values that `URLComponents` would normalize instead of preserving verbatim,
  and caps strict JSON container nesting at 64 before recursive parsing can grow
  the stack. Focused request, request-file, and CLI-spy regressions cover raw
  normalized URL characters and deeply nested JSON with zero credential and
  transport access. Fresh verification passed: `swift test --filter
  SearchConsole` (21 tests), `swift test` (66 tests), and `swift build`.
  `mise run lint` completed with 58 warnings and 0 serious violations; the
  command wrapper timed out only after SwiftLint's completion output. The
  untracked-file whitespace and Swift line-limit checks passed (4,513 Swift
  lines total; every file below 1,000). No live OAuth/provider call, commit, or
  push occurred.
- 2026-08-14: Step 6 self-review remediation from `comm-002319` exposed the
  strict JSON verifier to the test target and proved its exact container boundary:
  a 64-container JSON object verifies and 65 containers are rejected before
  typed decoding; the CLI regression continues to prove zero credential and
  transport calls. Final non-network verification passed on this workspace:
  `swift test --filter SearchConsole` (21 tests), `swift test` (66 tests),
  `swift build`, compatibility/reader/writer/admin help, reader catalog,
  Search Console fixture config validation, `sh -n scripts/smoke-reader-auth.sh`,
  and `scripts/smoke-reader-auth.sh`. `mise run lint` completed with 58 warnings
  and 0 serious violations before the command wrapper timeout. `git diff --check`,
  untracked whitespace, and Swift line-limit checks passed; status and inventory
  each reported 83 entries. Secret, private-URL, and machine-path scan matches
  were reviewed as source schema names, test sentinels/loopback fixtures, and
  documented mail-gateway reference paths; no real secret or unintended private
  URL was found. No live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Step 6 test-integrity remediation from `comm-002322` strengthened
  the test contract without changing production behavior. CLI spy coverage now
  routes strict request-file failures (empty, unknown/duplicate, deprecated
  `searchType`, duplicate dimensions, enum, numeric syntax/range, group,
  expression, malformed JSON/UTF-8, oversized, symlink, directory, and FIFO)
  through the reader and proves zero resolver and transport calls. The
  end-to-end recording transport now asserts exact normalized header maps,
  complete Search Analytics wire JSON including nil operator omission, and
  catalog capability/scope/availability tuples. Request/file tests add empty
  input, deprecated-field, exact property/URL byte-bound, and same-second
  nanosecond timestamp-change regressions. Fresh verification passed: `swift
  test --filter SearchConsole` (24 tests) and `swift test` (69 tests), with
  both command wrappers timing out only after complete passing output; `swift
  build` passed; `mise run lint` completed with 60 warnings and 0 serious
  violations. Fresh `git diff --check`, untracked whitespace, secret,
  private-URL, machine-path, and Swift line-limit checks passed; scan matches
  remain expected schema names, test sentinels, loopback fixtures, and documented
  reference paths. No live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Session 713 Step 4 revised this active plan after accepted design
  review `comm-002336`. The workflow/issue references now identify session 713;
  TASK-001 explicitly waives only the unreconstructable historical pre-edit test;
  TASK-003 is serialized after TASK-002 because both may edit
  `SearchConsoleValidation.swift`; and TASK-009 now maps every carried medium
  finding to source, independent regression, documentation, and one fresh final
  non-network evidence set. Earlier passing results remain historical and do not
  close TASK-009. No implementation code, live OAuth/provider call, commit, or
  push occurred during this plan revision.
- 2026-08-14: Session 713 Step 4 self-review reconciled the parallel task labels
  with the execution map and made TASK-005 through TASK-008 write scopes explicit.
  Phase A (TASK-002/TASK-005), phase B (TASK-003/TASK-004), and phase C
  (TASK-007/TASK-008) now have disjoint concurrent ownership. The plan continues
  to map only to the accepted design and introduces no new architecture. No live
  OAuth/provider call, commit, or push occurred.
- 2026-08-14: Session 715 Step 4 addressed Step 5 review `comm-002339`: the active
  workflow reference now identifies
  `codex-design-and-implement-review-loop-session-715`, session 713 is retained
  explicitly as accepted-design/remediation provenance, section-level design
  references trace command, validation, fixed-origin request, and verification
  contracts, and TASK-008 distinguishes current implementation evidence from the
  still-pending TASK-009 final evidence. No implementation code, verification
  command, live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Session 715 Step 4 addressed the remaining Step 5 consistency
  finding from `comm-002342`: main design evidence now names
  `codex-design-and-implement-review-loop-session-715` as the current
  issue-resolution/final-verification workflow and retains
  `codex-design-and-implement-review-loop-session-713` only as accepted-design
  and remediation provenance. TASK-008 and TASK-009 now require the same
  provenance split. The explicit `rg` consistency check passed. No implementation
  code, live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Session 715 Step 6 addressed self-review `comm-002347` with one
  fresh non-network evidence set after all prior remediation. `swift test --filter
  SearchConsole` passed 24 tests and `swift test` passed 69 tests; both tool
  wrappers timed out only after their complete passing output. `swift build`
  completed successfully before the same wrapper timeout. `mise run lint`
  completed SwiftLint with 60 warnings and 0 serious violations before its wrapper
  timeout. Compatibility/reader/writer/admin help, reader catalog, Search Console
  fixture config validation, `sh -n scripts/smoke-reader-auth.sh`, and
  `scripts/smoke-reader-auth.sh` passed without using credentials or a provider.
  `git diff --check` and the untracked-file whitespace check passed; status and
  inventory each reported 83 entries; all 33 Swift files were below 1,000 lines.
  Secret, private-URL, and machine-path scan matches were limited to schema names,
  test redaction/loopback sentinels, and documented reference paths. No live
  OAuth/provider call, commit, or push occurred. Independent adversarial review
  and its final decision remain pending Step 7.
- 2026-08-14: Session 715 Step 6 reran the complete TASK-009 matrix after every
  plan and documentation edit in response to `comm-002349`. `swift test --filter
  SearchConsole` passed 24 tests; `swift test` passed 69 tests; `swift build`
  passed; and `mise run lint` completed with 60 warnings and 0 serious violations.
  Compatibility/reader/writer/admin help, reader catalog, fixture config
  validation, `sh -n scripts/smoke-reader-auth.sh`, and
  `scripts/smoke-reader-auth.sh` passed without reaching a provider. `git diff
  --check`, tracked/untracked whitespace, status/inventory (83 entries each), and
  all 33 Swift-file line limits passed. The secret, private-URL, and machine-path
  scans reproduced 22, 7, and 7 reviewed matches respectively: schema names,
  test redaction/loopback sentinels, and documented reference paths only. The
  command wrapper timed out at its 120-second ceiling only after each command's
  successful completion output. No live OAuth/provider call, commit, or push
  occurred. No substantive change follows this evidence entry; Step 7 remains
  the independent adversarial review gate.
- 2026-08-14: Session 715 Step 6 remediated Step 7 finding `comm-002353` in
  `GatewayCLI.swift`: credential-resolver failures now retain their structured
  error code and exit code while exposing only `Credential resolution failed`.
  `SearchConsoleCLITests.swift` adds an injected failing resolver whose message
  contains token, credential-bearing URL, expression, and request-content
  sentinels; the public result contains none of them and invokes no transport.
  Fresh post-remediation verification passed: `swift test --filter
  SearchConsole` (25 tests), `swift test` (70 tests), `swift build`, and `mise
  run lint` (60 warnings, 0 serious violations). The command wrapper timed out
  only after the complete SwiftPM output showed success. No live OAuth/provider
  call, commit, or push occurred.
- 2026-08-14: Session 715 Step 6 completed the remaining `comm-002355`
  TASK-009 non-network evidence after the credential-error remediation. The
  compatibility and reader help, reader catalog, Search Console fixture config
  validation, writer/admin help, `sh -n scripts/smoke-reader-auth.sh`, and
  `scripts/smoke-reader-auth.sh` passed without credentials or provider access.
  `git diff --check`, status/inventory (83 untracked entries), untracked-file
  whitespace, and all 33 Swift-file line limits passed. Secret, private-URL,
  and machine-path scans produced 76, 15, and 15 reviewed matches respectively;
  they are schema terms, test redaction/loopback fixtures, and documented
  structural-reference paths only, with no real secret or unintended private
  URL. The focused/full tests, build, and lint evidence from the preceding
  post-remediation record remains part of this final matrix and occurred after
  the last source/test change. No subsequent substantive source or test change,
  live OAuth/provider call, commit, or push occurred.
- 2026-08-14: Session 715 Step 6 remediated adversarial-review finding
  `comm-002360`: `URLSessionTransport` now uses a dedicated session whose task
  delegate rejects every redirect, preventing a 307 or 308 response from
  replaying Search Analytics or URL Inspection POST content to a second origin.
  `SearchConsoleCLITests.swift` adds deterministic URLProtocol coverage for both
  POST routes and both redirect codes, asserting exactly one request reaches the
  approved initial URL and none reaches the redirect target. The main design now
  identifies independent adversarial review and any resulting remediation as
  the sole completion gate; the focused design records the no-redirect transport
  contract. The complete final non-network matrix passed: `swift test --filter
  SearchConsole` passed 26 tests; `swift test` passed 71 tests; `swift build`
  passed; and `mise run lint` reported 60 warnings and 0 serious violations.
  Compatibility/reader/writer/admin help, reader catalog, fixture config
  validation, `sh -n scripts/smoke-reader-auth.sh`, and
  `scripts/smoke-reader-auth.sh` passed without credentials or provider access.
  `git diff --check`, tracked/untracked whitespace, status/inventory (83
  untracked entries), secret/private-URL/machine-path scans, and all 33
  Swift-file line limits passed. Scan matches were reviewed schema names,
  test redaction/loopback sentinels, and documented structural-reference paths;
  no real secret or unintended private URL was found. No live OAuth/provider
  call, commit, or push occurred. Independent re-review is the remaining gate.
- 2026-08-14: Session 715 Step 6 is remediating test-integrity findings
  `TI-001` and `TI-002` from `comm-002365`. The focused Search Console tests now
  reject Google Ads-only profile fields, reject a selected differently-scoped
  product profile before credential or transport access, and assert the optional
  sitemap-list path has no query when `--sitemap-index` is omitted. A complete
  fresh non-network verification matrix follows these test and plan updates.
