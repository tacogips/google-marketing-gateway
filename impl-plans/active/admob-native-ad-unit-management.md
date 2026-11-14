# AdMob Native ad-unit management

**Status**: Active; ready for implementation
**Feature ID**: `admob-native-ad-unit-writer`
**Workflow mode**: `issue-resolution`
**Issue reference**: `google-marketing-gateway; issue URL and number unavailable; supplied title/body authoritative`
**Workflow execution**: `codex-design-and-implement-review-loop-session-723`
**Design reference**: `design-docs/specs/design-admob-native-ad-unit-writer.md`
**Main mutation design**: `design-docs/google-marketing-gateway-design.md#93-mutation`
**User-decision references**: `design-docs/user-qa/pending-google-marketing-gateway-decisions.md#6-mutation-confirmation`, `#8-retention-defaults`, `#9-durable-one-shot-state`, and `#10-initial-mutation-exposure`
**Codex-agent references**: None supplied
**Created**: 2026-08-14

## Outcome

Implement the accepted Native-only AdMob writer operation
`admob.accounts.adUnits.createNative`. The writer plans validated input without
network access, persists only authenticated encrypted canonical plan data plus
keyed digests, and applies the plan once through the fixed official request:

`POST https://admob.googleapis.com/v1beta/{parent=accounts/*}/adUnits`

The operation requires an exact AdMob writer profile with only
`https://www.googleapis.com/auth/admob.monetization`. It accepts a bounded
account, matching external app ID, bounded display name, and the closed
`RICH_MEDIA`/`VIDEO` set; it always sends `NATIVE`. Update, delete, generic
create, arbitrary HTTP/body input, other mutations, live login, and live
provider verification remain unavailable.

## Accepted boundaries

- Keep `google-marketing-gateway-reader`, writer, admin, and compatibility modes
  separate. Only the writer may route this exact operation.
- `plan` performs no provider transport and emits a canonical preview plus one
  opaque, ten-minute, single-use token.
- `apply` reads exactly one bounded token line from redirected stdin and accepts
  no business input or argv token.
- Bind plans to the operation, schema, exact normalized input, profile,
  capability, exact scope, and credential generation.
- Persist the canonical request only as authenticated ciphertext protected by a
  system-credential-store key. Persist token and semantic intent only as
  domain-separated keyed digests.
- Atomically consume the token before request construction. Never replay after
  `executing`; retain an indefinite non-secret semantic-intent tombstone after
  an ambiguous transmission.
- Preserve the fixed origin, redirect rejection, bounded JSON response, and
  status-only provider error policy. A 403 may reflect limited access and does
  not establish entitlement or a gateway defect.
- Do not add update, patch, delete, arbitrary URL/path/body/header/scope input,
  Native SDK rendering behavior, or a recovery command in this slice.

## Deliverables

- [ ] Native-only typed input, validation, canonicalization, request, and
      response models.
- [ ] Fixed v1beta POST request construction with exact four-field JSON.
- [ ] AdMob writer profile validation and exact monetization-scope isolation.
- [ ] Durable encrypted plan store, keyed token/intent indexes, atomic claims,
      fenced execution, terminal cleanup, and ambiguous-intent blocking.
- [ ] Writer-only plan/apply parsing, help, routing, stdin token framing, and
      deterministic dependency injection.
- [ ] Complete operation catalog metadata without generic create/update/delete
      descriptors.
- [ ] Focused request, validation, store, credential, catalog, CLI, mode,
      concurrency, redaction, and compatibility tests.
- [ ] README/help documentation covering limited access and mobile-SDK scope.
- [ ] Lint, focused tests, full tests, build, zero-network CLI smoke checks, and
      plan progress/closure evidence.

## Planned implementation surfaces

### New production files

- `Sources/GoogleMarketingGatewayCore/AdMobNativeAdUnitModels.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobNativeMutationPlanStore.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobNativeMutationCrypto.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobNativeStateEpoch.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobWriterCredentials.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobNativeWriterCommand.swift`

Split persistence, cryptography/key storage, and command handling by
responsibility. Do not let `GatewayCLI.swift` or any new Swift file reach 1,000
lines.

### Modified production files

- `Package.swift` for only the macOS system framework/library links required by
  the accepted local encrypted SQLite state design; add no remote dependency
  unless implementation proves the platform modules insufficient and design
  review approves the change.
- `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift`
- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift` only if a narrow
  outcome-classification boundary is needed without weakening existing errors.

### Tests and fixtures

- `Tests/GoogleMarketingGatewayCoreTests/AdMobNativeAdUnitTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AdMobNativeMutationPlanStoreTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AdMobWriterCredentialTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AdMobNativeWriterCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/Fixtures/admob-writer-plan.json`

The design's example fixture path uses a `.toml` suffix, while the repository's
current strict configuration decoder and fixtures are JSON. Preserve the
existing JSON configuration contract and use the JSON fixture path consistently
in tests, README, design verification examples, and the final zero-network
smoke command; do not introduce a second config format as part of this feature.

### Documentation and plan evidence

- `README.md`
- `design-docs/specs/design-admob-native-ad-unit-writer.md` only for factual
  status, fixture-path consistency, and final verification evidence
- `impl-plans/active/admob-native-ad-unit-management.md`, moved to
  `impl-plans/completed/` only after every completion criterion passes

## Dependencies and sequencing

- Existing dependencies: `CredentialProfileConfiguration`, the environment and
  installed-token-store behavior currently behind `ReaderCredentialResolving`,
  `PublisherRequests`, `OperationCatalog`,
  `GoogleRESTClient`, `HTTPTransport`, `GatewayError`, and the capability-mode
  executables.
- Platform dependencies: macOS 14 system credential storage for both secret key
  generations and the non-secret external `StateEpochAnchor`, authenticated
  cryptography, secure random generation, owner-only filesystem state, and
  SQLite transactional locking. Keep each behind an injected protocol so tests
  use temporary state and deterministic clocks/randomness without real secrets.
- TASK-001 precedes every source edit. TASK-002 and TASK-003 establish request
  and state contracts. TASK-004 depends on TASK-003. TASK-005 depends on
  TASK-002 and TASK-004. TASK-006 depends on TASK-002 through TASK-005. TASK-007
  depends on TASK-002 and may proceed alongside TASK-003/004 only while its
  shared-file write scope stays disjoint. TASK-008 follows feature integration;
  TASK-009 is the final closure gate.
- Shared files `Package.swift`, `CredentialProfiles.swift`,
  `OperationCatalog.swift`, `GatewayCLI.swift`, existing shared test files,
  `README.md`, and the design document must be edited serially and never
  replaced wholesale.
- No Codex-agent reference or Cursor adapter input exists, so reference mapping,
  intentional divergence, and Cursor adapter work are not applicable.

## Task breakdown

### TASK-001: Reconcile baseline and freeze independent contracts

**Parallelizable**: No
**Dependencies**: None
**Write scope**: This plan's progress log only

Inspect the current worktree, package boundaries, nearby source/tests,
SwiftLint/mise/CI configuration, and line counts before source edits. Translate
the accepted design into literal test vectors that do not derive expected URLs,
JSON, or state transitions from production helpers.

**Completion criteria**:

- [ ] Record `git status --short --untracked-files=all`, relevant file inventory,
      Swift line counts, and baseline focused/full test outcomes.
- [ ] Preserve unrelated user changes and record overlaps before editing.
- [ ] Recheck the official AdMob v1beta references at implementation start and
      record the URL template, four writable request fields, `NATIVE` format,
      `RICH_MEDIA`/`VIDEO` values, exact monetization scope, create/list-only
      surface, limited-access status, and verification date. Pause for design
      review if any accepted contract changed.
- [ ] Freeze literal positive and adversarial vectors for input grammar, exact
      body keys, headers, v1beta path, token framing, plan expiry, state
      transitions, and redaction.
- [ ] Record injected clock, random-byte, credential-generation, secret-store,
      state-epoch-anchor/database-ID, SQLite/state-path, stdin/TTY, and transport
      seams needed for deterministic tests.

### TASK-002: Add Native input, validation, and fixed request construction

**Parallelizable**: Yes, after TASK-001
**Dependencies**: TASK-001
**Write scope**: `AdMobNativeAdUnitModels.swift`, the isolated AdMob create block
in `PublisherRequests.swift`, `AdMobNativeAdUnitTests.swift`, and isolated
additions to `PublisherRequestTests.swift`

Model the closed Native request and validate every business value before config,
credential, state, or transport access.

**Completion criteria**:

- [ ] Account accepts only `accounts/pub-` plus 1-32 ASCII digits; traversal,
      controls, whitespace, Unicode digits, and extra segments fail.
- [ ] App ID accepts only the bounded external `ca-app-pub-...~...` form and its
      publisher digits must match the account.
- [ ] Display name enforces 1-80 Swift characters, at most 1,024 UTF-8 bytes,
      non-whitespace content, and no C0/C1/DEL controls without normalization.
- [ ] Ad types are a nonempty duplicate-free closed set of `RICH_MEDIA` and
      `VIDEO`, encoded in canonical order; ad format is fixed to `NATIVE`.
- [ ] The builder emits only POST, fixed AdMob origin, exact v1beta path,
      Authorization/Accept/Content-Type, and exactly `appId`, `displayName`,
      `adFormat`, and `adTypes`.
- [ ] Response-only, rewarded, null, unknown, caller-selected path/origin/body,
      and generic-format fields cannot be encoded.

### TASK-003: Build canonical plan cryptography and secret storage

**Parallelizable**: Yes, after TASK-001, alongside TASK-002
**Dependencies**: TASK-001
**Write scope**: `AdMobNativeMutationCrypto.swift`,
`AdMobNativeStateEpoch.swift`, crypto/secret-store/epoch-specific tests within
`AdMobNativeMutationPlanStoreTests.swift`, and the required isolated
`Package.swift` linker-setting block

Implement the accepted versioned canonical serialization, domain-separated
HMAC/HKDF key derivation, authenticated payload encryption, constant-time digest
comparison, secure random token generation, system-credential-store master-key
lifecycle, and external non-secret state-epoch anchor behind injected interfaces.

**Completion criteria**:

- [ ] Tokens are exactly 32 random bytes encoded as unpadded base64url; persisted
      state never contains the bearer token.
- [ ] Canonical bytes cover the complete semantic intent and plan schema with
      deterministic ordering and explicit version/domain labels.
- [ ] Purpose-key derivation includes the state epoch, key generation, and
      purpose; every active verification generation remains usable while a plan
      or indefinite semantic tombstone references it.
- [ ] For each new semantic intent, derive its domain-separated digest under the
      active generation and every retained semantic-intent verification
      generation. A match under any generation blocks insertion; the
      implementation must not compare only the active generation after rotation.
- [ ] Token and semantic-intent indexes use keyed digests; ciphertext associated
      data binds state epoch, database id, key generation, plan id, schema,
      operation, profile, expiry, token digest, and intent digest.
- [ ] The anchor adapter stores only the non-secret monotonic epoch, active
      state-key generation, and last accepted database id outside SQLite and its
      backups; it never falls back to an in-database anchor.
- [ ] Key values, plaintext payloads, identifiers, and display names never enter
      errors, logs, config, previews beyond reviewed fields, or terminal records.
- [ ] Missing keys, authentication failure, generation mismatch, and malformed
      canonical data fail closed with stable redacted categories.
- [ ] Tests use ephemeral keys and deterministic fixtures; they do not read or
      mutate the developer's real credential store.

### TASK-004: Implement durable plan and mutation-ledger state

**Parallelizable**: No
**Dependencies**: TASK-003
**Write scope**: `AdMobNativeMutationPlanStore.swift`, state/concurrency portions
of `AdMobNativeMutationPlanStoreTests.swift`, and any remaining isolated
`Package.swift` SQLite link setting

Add owner-only SQLite-backed state with schema/version and external-epoch
validation, crash-safe transactions, bounded lock waits, atomic token claims,
fenced leases, encrypted payload cleanup, and semantic-intent tombstones.

**Completion criteria**:

- [ ] Plan creation atomically stores token digest, keyed intent digest,
      authenticated ciphertext, expiry, profile/scope/capability/credential
      binding, state epoch, database id, key generation, and `planned` state.
- [ ] Before that insertion commits, the store checks the canonical semantic
      intent against every retained verification generation in one fail-closed
      transaction and rejects if any live plan, ledger entry, or indefinite
      ambiguous tombstone matches.
- [ ] First-use initialization establishes one database id and external anchor
      through a crash-safe protocol; normal startup requires exact equality
      among the anchor, database epoch/id, and every plan/keyed record binding.
- [ ] Apply atomically moves `planned -> claimed`, prevents concurrent/repeated
      consumption, authenticates/decrypts/revalidates, then moves through a
      fenced `executing` boundary exactly once.
- [ ] Stale recovery is possible only before `executing` and only when durable
      state proves transmission was impossible.
- [ ] Outcomes are `succeeded`, `providerRejected`, or `ambiguous`; no retry or
      reclaim is possible after `executing`.
- [ ] Terminal/expired payload ciphertext and key references are removed; only
      bounded non-secret ledger data remains for the accepted 30-day retention
      period. Ambiguous intent retains an indefinite blocking tombstone.
- [ ] Pruning never shortens the indefinite ambiguous duplicate-risk horizon or
      deletes a digest/key generation still required to block an intent.
- [ ] Missing, older, newer, duplicated, or mismatched anchor/database pairings;
      restored or copied replayable records; corruption; migration mismatch;
      unavailable store; lock timeout; key loss; cleanup uncertainty; and
      rollback/reopen attempts fail before transport without selecting the
      newest-looking database or minting a replacement epoch.
- [ ] Tests use multiple store connections and a subprocess race fixture to
      prove cross-process atomic claims and fencing, not merely actor-local
      serialization.
- [ ] Deterministic tests cover clean initialization, restart with an exact
      anchor/database match, epoch and database-id mismatch in both directions,
      missing/duplicated anchor, copied/rolled-back database rejection, state-key
      generation mismatch, and fail-closed loss after planned and ambiguous
      records exist.
- [ ] Deterministic rotation tests create an indefinite ambiguous tombstone under
      an older generation, activate a new generation, and prove the equivalent
      intent remains blocked through cross-generation comparison while a distinct
      intent can still be planned.
- [ ] Restore, disaster-recovery, break-glass, and ambiguous-resolution commands
      remain explicitly deferred; this slice implements only validation and
      fail-closed behavior needed to prevent replay.

### TASK-005: Add exact writer profile and credential-generation binding

**Parallelizable**: No
**Dependencies**: TASK-002, TASK-004
**Write scope**: `CredentialProfiles.swift`,
`AdMobWriterCredentials.swift`, `CredentialProfileTests.swift`,
`AdMobWriterCredentialTests.swift`, and the writer fixture

Extend strict configuration decoding by exactly one accepted writer profile
shape. Add a writer-specific credential adapter over the existing environment
and installed-token-store sources, plus a non-reversible credential-generation
binding usable by plan/apply without renaming or exposing the reader-only CLI
authentication surface.

**Completion criteria**:

- [ ] Accept only `product=admob`, `capability=writer`, and the singleton exact
      monetization scope for this operation.
- [ ] Reject readonly/report/mixed/duplicate/extra/cross-product writer scopes,
      every admin profile, and all other writer products still lacking accepted
      operations.
- [ ] Reader profiles and existing installed/environment credential behavior
      remain compatible.
- [ ] Writer credential resolution is reached only after writer capability,
      operation, product, and exact-scope checks; reader/admin cannot invoke the
      writer adapter, and the writer gains no login command.
- [ ] Plan and apply require the same profile, capability, exact scope, and
      non-reversible credential generation; mismatch fails before request
      construction or transport.
- [ ] Configuration, output, catalog, errors, and persisted plan records contain
      references/fingerprints only, never access, refresh, client-secret, or key
      values.

### TASK-006: Implement writer-only plan/apply command flow

**Parallelizable**: No
**Dependencies**: TASK-002, TASK-003, TASK-004, TASK-005
**Write scope**: `AdMobNativeWriterCommand.swift`, isolated routing/help changes
in `GatewayCLI.swift`, `AdMobNativeWriterCLITests.swift`, and isolated
compatibility assertions in `GatewayCLITests.swift`

Add closed parsing and dispatch with injected local services. Keep generic CLI
behavior unchanged and split writer handling from `GatewayCLI.swift` before that
file reaches 1,000 lines.

**Completion criteria**:

- [ ] `plan` accepts only the designed business/profile/config flags, validates
      locally, binds credentials, persists the plan, prints canonical JSON with
      `requestSent: false`, and records zero transport calls.
- [ ] `apply` accepts only `--plan-token-stdin`, profile, and required config;
      business fields, positional/argv tokens, and arbitrary HTTP/body flags fail
      before config or credential access.
- [ ] Stdin must be redirected and contain exactly one newline-terminated UTF-8
      base64url token within the 128-byte total cap; malformed, missing,
      multiline, padded, whitespace, trailing, oversized, and interactive input
      fail without reproducing bytes.
- [ ] Apply reconstructs the request only from authenticated stored input,
      revalidates it, verifies all bindings, consumes state, sends at most once,
      and records the correct conclusive or ambiguous outcome.
- [ ] Decrypted canonical input has the narrowest practical lexical lifetime and
      is released immediately after request construction; it is never cached,
      copied into errors, or retained in terminal state.
- [ ] Reader, admin, and compatibility modes reject this route before config,
      credential, state, or transport; writer rejects every other mutation.
- [ ] Provider 403 stays redacted `PROVIDER_FAILURE` with bounded status only;
      timeouts/disconnects are ambiguous and never retried.

### TASK-007: Extend the operation catalog contract

**Parallelizable**: Yes, after TASK-002 and while TASK-003/004 edit disjoint files
**Dependencies**: TASK-002
**Write scope**: `OperationCatalog.swift` and `OperationCatalogTests.swift`

Extend descriptor metadata only as needed to express the accepted mutation
contract, preserving existing descriptor encoding and defaults.

**Completion criteria**:

- [ ] Add exactly `admob.accounts.adUnits.createNative` as implemented,
      `admob`/writer, exact monetization scope, v1beta, limited access, fixed
      origin, provider method, mutate/non-idempotent, indirect-serving risk,
      typed-body, bounded-response, plan/apply, duplicate-risk, reconciliation,
      payload, and deterministic-verification policies.
- [ ] No generic create, update, patch, delete, wildcard scope, or other AdMob
      mutation becomes implemented or callable.
- [ ] Catalog validation rejects incomplete/inconsistent writer metadata and all
      existing reader/catalog tests continue to pass.

### TASK-008: Document the supported and excluded behavior

**Parallelizable**: No
**Dependencies**: TASK-005, TASK-006, TASK-007
**Write scope**: `README.md`, factual status/fixture corrections in the accepted
design, and this plan progress log

Document exact commands and safety boundaries without implying live entitlement
or provider execution.

**Completion criteria**:

- [ ] README/help show exact plan/apply syntax, JSON configuration fixture shape,
      stdin-only token application, and no-network plan semantics.
- [ ] Documentation states that create is limited access and 403 may require
      account-manager enablement without claiming access.
- [ ] Update/delete and every other AdMob mutation remain unavailable; Native
      layout, rendering, assets, AdChoices, click/impression handling, and SDK
      test-ad behavior are explicitly mobile-app responsibilities.
- [ ] Examples use non-secret fixture values, never invoke apply, and never tell
      verification to log in or contact Google.
- [ ] The JSON fixture references `ADMOB_WRITER_PLAN_TEST_TOKEN`; the smoke
      command supplies only the documented non-secret test value and verifies
      that neither the value nor its derived fingerprint is emitted.

### TASK-009: Run closure verification and archive the plan

**Parallelizable**: No
**Dependencies**: TASK-001 through TASK-008
**Write scope**: This plan progress/status, accepted-design status/evidence, and
move from `impl-plans/active/` to `impl-plans/completed/` only after acceptance

Run narrow-to-broad deterministic verification, review all diffs, and record
exact results. Do not invoke live login or apply.

**Completion criteria**:

- [ ] SwiftLint completes; new serious violations are fixed and remaining
      repository warnings are reported accurately.
- [ ] Focused request/model, plan-store/crypto, profile/catalog, and CLI/mode
      tests pass.
- [ ] Full `mise run test` and `mise run build` pass.
- [ ] Help/catalog and the fixture-backed `plan` command pass without transport;
      the emitted token is not passed to `apply`.
- [ ] Tests prove stubbed 200/403/transport ambiguity, concurrent single use,
      ciphertext tampering, missing key, state-epoch/database mismatch and
      rollback rejection, cross-generation ambiguous-intent blocking after key
      rotation, no plaintext persistence, redaction, and unchanged reader/admin
      behavior.
- [ ] Closure evidence records the TASK-001 official-contract recheck; any
      changed v1beta method, schema, scope, enum, access policy, or create/list
      surface blocks completion pending design review.
- [ ] `git diff --check`, trailing-whitespace, secret/private-URL/machine-path,
      and Swift file-length checks pass for the implementation scope.
- [ ] No live Google login, provider request, ad-unit creation, spend, commit, or
      push occurred.
- [ ] Independent implementation review has no unresolved high or mid finding;
      then mark complete, record closure evidence, and move this file to
      `impl-plans/completed/admob-native-ad-unit-management.md`.

## Verification commands

```bash
git status --short --untracked-files=all
wc -l $(rg --files Sources Tests -g '*.swift') | sort -n
mise run lint
swift test --filter AdMobNativeAdUnit
swift test --filter AdMobNativeMutationPlanStore
swift test --filter AdMobNativeStateEpoch
swift test --filter AdMobWriterCredential
swift test --filter AdMobNativeWriterCLI
swift test --filter CredentialProfile
swift test --filter OperationCatalog
swift test --filter GatewayCLI
mise run test
mise run build
swift run google-marketing-gateway-writer --help
swift run google-marketing-gateway-writer catalog
ADMOB_WRITER_PLAN_TEST_TOKEN=fixture-token-not-a-secret \
swift run google-marketing-gateway-writer admob adunits create-native plan \
  --account accounts/pub-9876543210987654 \
  --app-id ca-app-pub-9876543210987654~0123456789 \
  --display-name "Local verification only" \
  --ad-types RICH_MEDIA,VIDEO \
  --profile fixture-admob-writer \
  --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/admob-writer-plan.json
git diff --check
awk 'length($0) && /[[:space:]]$/{print FNR ":" $0; bad=1} END{exit bad}' \
  impl-plans/active/admob-native-ad-unit-management.md \
  design-docs/specs/design-admob-native-ad-unit-writer.md README.md
```

Do not run `apply`, `auth login`, a live curl/request, release, commit, or push
as verification for this workflow.

## Completion criteria

The feature is complete only when every task checkbox is satisfied, the exact
Native create operation is the sole new mutation, plans are zero-network and
single-use, apply is authenticated-stored-input-only and at-most-once, ambiguous
outcomes cannot replay, all credentials and payloads remain isolated/redacted,
all deterministic checks pass, documentation is truthful about limited access
and mobile scope, and independent review has no unresolved high or mid finding.

## Progress log expectations

Append dated entries below throughout implementation. Each entry must name task
IDs, files changed, exact commands and results, decisions or deviations, review
findings addressed, residual risks, and whether network, login, apply, commit,
or push occurred. Do not mark a task complete from code inspection alone when a
listed deterministic test is available. Any design deviation pauses
implementation until the design and this plan are revised and reviewed.

## Progress log

- 2026-08-14: Plan created from the Step 3-accepted design. Step 3 reported no
  findings and accepted the design for implementation planning. No Codex-agent
  reference mapping applies. Plan creation changed documentation only and did
  not run login, provider transport, apply, commit, or push.
- 2026-08-14: Author self-review added an explicit writer-only credential
  adapter/test surface, 30-day terminal-retention and indefinite-tombstone
  pruning criteria, bounded decrypted-payload lifetime, and a complete
  non-secret environment-backed plan smoke command. These close the identified
  plan-only mapping gaps without changing the accepted architecture. No design
  revision, provider transport, apply, commit, or push occurred.
- 2026-08-14: Step 5 revision added the accepted external `StateEpochAnchor`
  implementation/test surface, epoch/database/key-generation binding and
  fail-closed rollback criteria, while explicitly deferring recovery commands.
  It also made the implementation-start official v1beta contract recheck a
  TASK-001 and closure requirement. No design revision, provider transport,
  apply, commit, or push occurred.
- 2026-08-14: Step 5 follow-up revision made cross-generation semantic-intent
  checks explicit in TASK-003 and TASK-004. New plans must be checked against
  every retained verification generation in a fail-closed insertion transaction,
  and deterministic rotation tests must prove an older indefinite ambiguous
  tombstone remains blocking. No design revision, provider transport, apply,
  commit, or push occurred.
- 2026-08-14: Implementation started. TASK-002 added closed Native input
  validation and the exact v1beta POST builder; TASK-005 added the writer-only
  credential-profile validation; TASK-006 added closed writer preview routing;
  TASK-007 added the Native-only catalog descriptor; TASK-008 documented
  limited access and mobile SDK exclusions. Self-review rejected the initial
  process-local plan/apply store because it could not meet the durable safety
  contract. That store and apply route were removed; the catalog now marks the
  operation preview-only and the CLI emits no reusable token. Focused
  `nativeAdUnitCreate` and `AdMobNative` tests passed. No Google login, provider
  transport, apply, commit, or push occurred. Durable encrypted SQLite state,
  external state-epoch persistence, and their concurrency/rotation tests remain
  required before TASK-003, TASK-004, TASK-006, TASK-007, and TASK-009 can be
  checked complete.

## Residual risks

- Correct implementation can still receive limited-access HTTP 403 without
  provider entitlement.
- Transmission can become ambiguous after Google accepts the create; absence of
  provider idempotency, update/delete, or conclusive lookup requires permanent
  local duplicate blocking until separately reviewed resolution.
- A writer scope accepted by reader/admin or another product would break
  capability isolation.
- Lost/corrupt encryption keys, plan ciphertext, state epoch, or SQLite state
  must fail closed and can leave intents blocked.
- The v1beta schema, access policy, or supported Native ad types can change and
  must be rechecked before release.
