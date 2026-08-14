# AdMob Native Ad-Unit Writer

## Status

Proposed for adversarial review

| Metadata | Value |
|---|---|
| Workflow mode | `issue-resolution` |
| Issue reference | `google-marketing-gateway; issue URL and number not provided, so the supplied workflow title and body are authoritative` |
| Issue title | `Implement supported AdMob Native ad-unit management` |
| Checkpoint | `b6754f7` |
| Design verification date | 2026-08-14 |
| Implementation plan | `impl-plans/active/admob-native-ad-unit-management.md` |
| Codex-agent references | None supplied |

## 1. Purpose

Add the one public AdMob ad-unit mutation supported by the official API that is
needed for Native inventory: create a `NATIVE` ad unit through AdMob API
v1beta. The gateway exposes a typed, plan-first writer command; it does not
become a generic AdMob mutation proxy.

The design preserves the existing fixed-origin REST transport, redacted
provider errors, product-isolated profiles, and separate reader, writer, and
admin executables. It also records that API access is limited and that an HTTP
403 does not prove a gateway defect or an account entitlement.

## 2. Repository Findings

| Area | File | Finding |
|---|---|---|
| Checkpoint | Git `HEAD` | The requested checkpoint `b6754f7` is the current baseline. The worktree was clean before this design update. |
| Capability gate | `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift` | Reader dispatch is implemented. Writer and admin currently fail closed before route selection because their mutation allowlists are empty. |
| Credential validation | `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift` | Profiles are product-isolated but currently require `reader` capability and allow only AdMob read/report scopes. |
| Existing AdMob requests | `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift` | AdMob v1 account, app, ad-unit, and report readers use `https://admob.googleapis.com` and validate account resource structure. There is no v1beta writer request. |
| Operation catalog | `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift` | AdMob readers are implemented and cataloged. No AdMob writer descriptor is callable. |
| Error boundary | `Sources/GoogleMarketingGatewayCore/HTTPTransport.swift` | Provider failures retain only HTTP status and a bounded provider status token; response messages and request bodies are not surfaced. Redirects are rejected. |
| Tests | `Tests/GoogleMarketingGatewayCoreTests/PublisherRequestTests.swift`, `GatewayCLITests.swift`, `CredentialProfileTests.swift`, `OperationCatalogTests.swift` | Current tests cover fixed origins, resource traversal rejection, reader profile isolation, redacted 403 errors, and the empty writer allowlist. |

## 3. Official API Boundary

The authoritative public references checked on 2026-08-14 are:

- `https://developers.google.com/admob/api/reference/rest/v1beta/accounts.adUnits/create`
- `https://developers.google.com/admob/api/reference/rest/v1beta/accounts.adUnits`

They define:

- `POST https://admob.googleapis.com/v1beta/{parent=accounts/*}/adUnits`;
- a request body containing an `AdUnit`;
- the exact OAuth scope
  `https://www.googleapis.com/auth/admob.monetization`;
- a limited-access method that may return HTTP 403 without entitlement;
- `appId`, `displayName`, `adFormat`, and `adTypes` as writable data needed by
  this operation; and
- only `create` and `list` on the public `accounts.adUnits` resource. There is
  no public update, patch, or delete method for an ad unit.

The v1beta resource lists `RICH_MEDIA` and `VIDEO` as the supported `adTypes`
values and `NATIVE` as an `adFormat`. `name` and `adUnitId` are provider-owned
response fields. `rewardSettings` applies only to `REWARDED` and is invalid for
this Native-only gateway operation.

## 4. Scope

### In scope

- A single writer operation for creating a `NATIVE` AdMob ad unit.
- A typed request body with fixed field names and no caller-supplied JSON.
- Product- and capability-isolated AdMob writer credentials with the exact
  monetization scope.
- Plan-first CLI behavior and an explicit apply marker.
- Catalog metadata, help, routing, request/config/mode tests, and user docs.
- Honest handling and documentation of limited-access HTTP 403 responses.

### Out of scope

- Ad-unit update, patch, or delete, because the public API does not expose them.
- Other AdMob v1beta writers, including app, mediation group, experiment, and
  ad-unit-mapping mutations.
- Non-Native ad formats and rewarded settings.
- Arbitrary origin, URL, API version, path, headers, OAuth scope, HTTP method,
  or JSON body input.
- Live entitlement discovery, live login, or a live create call during this
  workflow.
- Mobile SDK behavior: Native layout or rendering, asset registration,
  AdChoices placement, click/impression handling, and SDK test-ad behavior.

## 5. Public Command Contract

The writer executable adds separate plan and apply commands:

```text
google-marketing-gateway-writer admob adunits create-native plan \
  --account accounts/pub-<digits> \
  --app-id ca-app-pub-<digits>~<digits> \
  --display-name <name> \
  --ad-types RICH_MEDIA[,VIDEO] \
  --profile <id> \
  [--config <path>]

google-marketing-gateway-writer admob adunits create-native apply \
  --plan-token-stdin \
  --profile <id> \
  [--config <path>]
```

`plan` is a zero-network operation. It validates all business input, loads the
selected configuration and exact writer profile, and resolves the credential
only far enough to bind the plan to a non-reversible credential-generation
fingerprint. It never contacts Google. It prints a canonical JSON preview
containing the stable operation id, fixed method/origin/path, fixed `NATIVE`
format, selected ad types, expiry, an opaque single-use plan token, and
`requestSent: false`.

The plan expires after ten minutes. Durable owner-only state stores the token
digest, not the bearer token, and a canonical semantic-intent digest covering
the operation, normalized business input, fixed request contract, profile id,
capability, exact scope, and credential-generation fingerprint. It also stores
an authenticated encrypted canonical payload containing only the validated
account, app id, display name, canonical ad types, fixed `NATIVE` format, schema
version, operation id, and expiry required to reconstruct the request.

The payload encryption key is protected by the system credential store and is
never configured or printed. Authenticated metadata binds the ciphertext to the
plan identifier, schema version, operation, profile, expiry, token digest, and
semantic-intent digest so records cannot be swapped or reinterpreted. Neither
credential values nor the opaque plan token appear in configuration, logs,
catalog output, errors, or persisted plan records. The opaque token is returned
once in the successful plan result so the caller can pipe it to `apply` without
placing it in process arguments or shell history.

`--plan-token-stdin` requires redirected standard input and refuses an
interactive terminal so the token is never echoed. It reads exactly one
newline-terminated UTF-8 token with a 128-byte total input cap. The token is an
unpadded base64url encoding of 32 random bytes; empty input, padding, whitespace
inside the token, non-base64url bytes, missing or additional lines, trailing
data, and oversized input fail before configuration or credential access. The
single line terminator is framing and is not part of the token digest. Errors
identify only `PLAN_TOKEN_INVALID`, `PLAN_EXPIRED`, or `PLAN_CONSUMED` as
applicable and never reproduce the token or stdin contents.

`apply` accepts no business fields. Both `--profile` and a config path supplied
by `--config` or `GOOGLE_MARKETING_GATEWAY_CONFIG` are required and must resolve
to the exact profile, scope, capability, and credential generation recorded by
the plan. The writer validates the token digest and expiry, then atomically
changes the durable plan from `planned` to `claimed`. This consumes the token
before any request can be constructed and prevents concurrent or repeated
apply.

Under the claim lease, apply decrypts the stored canonical payload, verifies its
authenticated metadata and closed schema, reruns every business validation, and
recomputes the semantic-intent digest. Any mismatch permanently rejects the
plan without transport. The verified stored payload, never caller-supplied
replacement fields, provides the exact path component and four request-body
fields. A claim must transition to `executing` under an unexpired fenced lease
immediately before request construction. A stale claim may be recovered only
while durable state proves that decryption succeeded but transmission was
impossible.

Once state reaches `executing`, no automatic or operator-triggered replay is
allowed. A successful response records `succeeded`; a conclusive provider
rejection records `providerRejected`; and a timeout, lost connection, or crash
after transmission may have begun records `ambiguous`. Because the API supplies
no idempotency key, delete method, unique lookup key, or conclusive negative
reconciliation signal, an ambiguous semantic-intent digest remains blocked
from replanning. The user must inspect AdMob independently and explicitly
resolve the outcome through a separately reviewed recovery capability; this
slice does not add such a capability.

After `executing` begins, the cleartext payload is discarded from memory as soon
as request construction completes. On `succeeded`, `providerRejected`, expiry,
or `ambiguous`, the encrypted payload and its payload-key reference are removed;
the durable ledger retains only bounded non-secret state and digests for the
existing retention period. An ambiguous semantic-intent tombstone remains for
the unbounded duplicate-risk horizon even after payload removal. Missing keys,
authentication failure, schema mismatch, or cleanup uncertainty fails closed
and never falls back to caller-provided input or plaintext persistence.

Neither command accepts `--url`, `--origin`, `--path`, `--body`,
`--request-file`, `--format`, `--scope`, `--header`, `--access-token`, or a raw
ad-type string outside the defined enum. Unknown, repeated, missing-value, and
mode-inappropriate flags fail before credentials. `apply` additionally rejects
`--plan-token`, account, app, display-name, ad-type, and format flags so the
token cannot enter argv and the reviewed plan input cannot drift.

The catalog operation id is
`admob.accounts.adUnits.createNative`; its official provider method is
`accounts.adUnits.create`. The distinct gateway id makes the Native-only
restriction visible and prevents the catalog from implying support for every
format accepted by the provider method.

## 6. Typed Input and Validation

Validation completes before configuration access, credential resolution, or
transport execution.

| Input | Accepted form | Rejection rules |
|---|---|---|
| Account | `accounts/pub-` followed by 1 to 32 ASCII digits. | Reject other prefixes, empty publisher ids, non-ASCII digits, separators, traversal, query/fragment syntax, whitespace, control bytes, and extra path segments. The bound is a gateway safety bound; Google remains authoritative about whether the id exists. |
| App ID | `ca-app-pub-` followed by 1 to 32 ASCII publisher digits, `~`, then 1 to 32 ASCII app digits. | Reject resource paths, `/`, extra delimiters, non-ASCII digits, whitespace, and controls. The publisher digits must equal the account publisher digits to prevent an accidental cross-account create. |
| Display name | 1 through 80 Swift characters and at most 1,024 UTF-8 bytes. | Reject empty or whitespace-only values, C0/C1 controls, DEL, invalid encoding, or values outside either bound. Preserve the accepted value rather than silently trimming or normalizing it. The 80-character limit is the provider limit; the byte cap is a local allocation/logging bound. |
| Ad types | A non-empty, duplicate-free set drawn only from `RICH_MEDIA` and `VIDEO`. | Reject unknown case variants, empty elements, duplicates, and more than two values. Encode in the canonical order `RICH_MEDIA`, then `VIDEO`, regardless of CLI order. |
| Ad format | No caller input. | Always encode `NATIVE`; reject any attempt to supply a format flag. |

The typed request body has exactly this shape:

```json
{
  "adFormat": "NATIVE",
  "adTypes": ["RICH_MEDIA", "VIDEO"],
  "appId": "ca-app-pub-9876543210987654~0123456789",
  "displayName": "Example Native"
}
```

`name`, `adUnitId`, `rewardSettings`, unknown fields, and null fields are never
encoded. JSON output is deterministic for tests; field ordering is not part of
the provider contract.

## 7. Credential and Capability Isolation

An AdMob writer profile is valid only when all of these conditions hold:

- `product` is exactly `admob`;
- `capability` is exactly `writer`;
- `oauthScopes` contains exactly one value,
  `https://www.googleapis.com/auth/admob.monetization`;
- the scope is neither combined with nor substituted by `admob.readonly`,
  `admob.report`, or a cross-product scope; and
- credentials remain references to an environment variable or existing secure
  OAuth files. Token, refresh-token, and client-secret values never appear in
  config, catalog, stdout, stderr, or errors.

Configuration decoding may accept the existing reader profiles and this one
explicit writer profile shape. It continues to reject every admin profile and
all other writer product/scope combinations until those operations receive
their own reviewed designs. Profile selection then requires equality between
binary mode, profile capability, operation capability, product, and exact
operation scope.

Only `google-marketing-gateway-writer` can plan or apply the create operation.
The reader and admin executables reject it before configuration or credential
access. The writer continues to reject unknown commands, every admin operation,
and every mutation except this cataloged Native create. Existing reader routes
and scope alternatives remain unchanged.

This slice does not broaden installed OAuth login behavior. A live apply uses a
short-lived access token supplied through the configured environment-variable
reference or an already provisioned compatible token store. No live OAuth flow
is exercised by implementation verification.

## 8. Request and Response Data Flow

```text
CLI arguments
  -> closed command/flag parser
  -> typed local validation
  -> config/profile capability and exact-scope validation
  -> credential-generation binding
  -> canonical no-network plan plus expiring single-use token
  -> encrypted canonical payload plus durable digests and intent block
  -> separate apply command reading bounded token-only authority from stdin
  -> atomic planned -> claimed token consumption
  -> authenticated payload recovery, full revalidation, and digest comparison
  -> fenced claimed -> executing transition
  -> typed four-field JSON encoding
  -> fixed POST https://admob.googleapis.com/v1beta/<account>/adUnits
  -> redirect-rejecting transport
  -> durable succeeded, providerRejected, or ambiguous outcome
  -> bounded JSON success or redacted structured failure
```

No step accepts a caller-selected host or provider path. The URL is assembled
only from the fixed origin, fixed v1beta template, and validated account
resource. The authorization token exists only in the request header.

On success, the existing response policy may return the provider's bounded JSON
AdUnit, including generated `name` and `adUnitId`. It must not add a claim that
the unit is serving, approved, or producing revenue.

On failure:

- HTTP 403 remains `PROVIDER_FAILURE` with HTTP status and a safe provider
  status such as `PERMISSION_DENIED` only;
- help and documentation explain that the create method has limited access and
  may require account-manager enablement;
- the gateway does not claim entitlement, instruct the user to bypass access
  controls, or expose the provider message/body;
- timeout or transport failure remains outcome-ambiguous and is not retried;
  the token remains consumed and the same semantic intent remains blocked, so
  listing or AdMob inspection is diagnostic rather than permission to replay;
  and
- no request body, display name, account/app identifier, token, configuration
  contents, or provider detail is added to error output.

## 9. Operation Catalog Metadata

The implemented descriptor records:

| Field | Value |
|---|---|
| `id` | `admob.accounts.adUnits.createNative` |
| `product` | `admob` |
| `capability` | `writer` |
| `oauthScopes` | exactly `https://www.googleapis.com/auth/admob.monetization` |
| `availability` | `implemented` |
| `apiFamily` | `admob` |
| `apiVersion` | `v1beta` |
| `stability` | `beta-limited-access` |
| `origin` | `https://admob.googleapis.com` |
| `providerMethod` | `accounts.adUnits.create` |
| `requestKind` | `mutate` |
| `idempotencyClass` | `non-idempotent-create` |
| `confirmationPolicy` | `expiring-single-use-plan-token-via-stdin` |
| `duplicateRiskHorizon` | `unbounded-after-ambiguous-transmission` |
| `reconciliationPolicy` | `no-automatic-replay; explicit separately reviewed resolution required` |
| `planPayloadPolicy` | `authenticated-encrypted-canonical-input; digest-only terminal state` |
| `spendRisk` | `indirect-serving` |
| `requestBodyPolicy` | `typed-native-ad-unit-only` |
| `responsePolicy` | `bounded-json` |
| `verification` | `deterministic-no-live-mutation` |

Catalog lookup remains fail-closed: only the exact implemented descriptor is
callable. No generic `admob.accounts.adUnits.create`, update, patch, or delete
descriptor is added.

## 10. Issue-to-Design Mapping

| Requested behavior | Design disposition |
|---|---|
| Create an AdMob Native ad unit | Typed `create-native` writer route using the official v1beta POST method. |
| Product-isolated writer credential | Exact `admob` + `writer` + monetization-scope profile, with reader/admin mismatch rejection. |
| Bounded account, app id, display name, and ad types | Closed grammars, explicit bounds, publisher consistency, and fixed enums in Section 6. |
| Fix Native format in the gateway | No format flag; body always encodes `NATIVE`. |
| No arbitrary URL/path/body | Fixed request template and four-field typed body only. |
| Keep update/delete unavailable | No catalog entries, commands, or builders for methods absent from the public API. |
| Preserve redaction and fixed origin | Existing redirect-rejecting transport and status-only provider failures remain the boundary. |
| Honest limited-access 403 | Catalog stability, help, errors, and docs state limited access without claiming entitlement. |
| Add metadata, CLI, tests, and docs | Explicit catalog contract, separate token-bound plan/apply commands, verification matrix, README/help updates. |
| Avoid live changes and spend during workflow | Plan-first CLI and deterministic local verification; no login or live apply command is run. |
| Exclude mobile Native responsibilities | SDK layout, rendering, AdChoices, events, and test ads remain documented out of scope. |

## 11. Verification and Review Matrix

Implementation tests must cover:

- typed request success: fixed host, v1beta path, POST, headers, exact JSON keys,
  fixed `NATIVE`, canonical ad-type ordering, and no response-only fields;
- every validation boundary and adversarial path/account/app string, including
  account/app publisher mismatch;
- display-name character, UTF-8 byte, whitespace, and control limits;
- ad-type empty, duplicate, case-variant, and unknown rejection;
- plan mode proving zero provider transport, exact profile/scope validation,
  ten-minute expiry, non-reversible credential binding, token-digest-only
  persistence, authenticated encrypted canonical request persistence, and
  canonical preview output with deterministic clock/random fixtures;
- apply mode proving business-input flags are rejected, the stored input cannot
  drift, the exact request is reconstructed from the authenticated payload,
  every validation and digest comparison reruns, token/profile/credential
  mismatches fail, and validation precedes transport;
- token-input tests proving `--plan-token` and positional tokens are rejected,
  interactive stdin is refused, exactly one bounded base64url line is accepted,
  malformed/multiline/oversized input fails before configuration, and no token
  bytes appear in stdout, stderr, logs, or errors;
- payload-state tests covering ciphertext tampering, authenticated-metadata
  swapping, missing keys, schema-version mismatch, cleanup, no plaintext
  persistence, and digest-only terminal/ambiguous records;
- single-use token tests covering atomic concurrent claims, repeated apply,
  expiry, fenced recovery before `executing`, and no recovery after
  `executing`;
- semantic-intent tests proving unresolved ambiguous creates block replanning
  and cannot be replayed;
- exact writer scope acceptance and reader/report/mixed/extra/cross-product
  scope rejection;
- reader/writer/admin route isolation and the unchanged rejection of every
  other mutation;
- catalog fields and absence of update/delete/generic-create descriptors;
- a stubbed 200 response and stubbed limited-access 403 with no provider body,
  token, request body, display name, account id, or app id in stderr; and
- existing reader/config/OAuth test compatibility.

Expected implementation files are:

- `Sources/GoogleMarketingGatewayCore/AdMobNativeAdUnitModels.swift`
- `Sources/GoogleMarketingGatewayCore/PublisherRequests.swift`
- `Sources/GoogleMarketingGatewayCore/CredentialProfiles.swift`
- `Sources/GoogleMarketingGatewayCore/OperationCatalog.swift`
- `Sources/GoogleMarketingGatewayCore/GatewayCLI.swift`
- `Sources/GoogleMarketingGatewayCore/AdMobNativeMutationPlanStore.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AdMobNativeAdUnitTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/AdMobNativeMutationPlanStoreTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/CredentialProfileTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/OperationCatalogTests.swift`
- `Tests/GoogleMarketingGatewayCoreTests/GatewayCLITests.swift`
- `README.md`

Required verification commands are:

```bash
mise run lint
swift test --filter AdMobNativeAdUnit
swift test --filter CredentialProfile
swift test --filter GatewayCLI
mise run test
mise run build
swift run google-marketing-gateway-writer --help
swift run google-marketing-gateway-writer catalog
swift run google-marketing-gateway-writer admob adunits create-native plan \
  --account accounts/pub-9876543210987654 \
  --app-id ca-app-pub-9876543210987654~0123456789 \
  --display-name "Local verification only" \
  --ad-types RICH_MEDIA,VIDEO \
  --profile fixture-admob-writer \
  --config Tests/Fixtures/admob-writer-plan.toml
```

The fixture credential reference used by the last command is a non-secret local
test value. The command must report a plan with `requestSent: false`; its output
token must not be passed to `apply`. Verification must not supply live
credentials, log into Google, invoke the apply command, or contact the provider.

## 12. Decisions

| Decision | Rationale |
|---|---|
| Use a dedicated design document. | The first gateway writer operation changes profile validation, CLI mode routing, irreversible-mutation behavior, and review requirements; compact command or architecture notes would hide important boundaries. |
| Expose `createNative`, not a generic create. | The issue requests Native only, and a narrower operation id prevents format/body expansion by implication. |
| Use distinct `plan` and `apply` commands with an expiring single-use token. | Create has no public delete, idempotency key, or conclusive negative reconciliation signal; combining planning and execution would violate the gateway mutation boundary. |
| Accept the apply token only through bounded redirected stdin. | A command-line capability can leak through process listings and shell history; stdin preserves explicit apply while keeping the token out of argv. |
| Consume the token atomically before transmission and block ambiguous intent. | Cross-process apply races and retries after a lost response can create durable duplicates, so replay prevention must survive process failure. |
| Persist the canonical request only as authenticated ciphertext until execution terminates. | Apply must recover the exact reviewed request without accepting drift-prone caller input, while account, app, and display-name data must not remain in plaintext mutation state. |
| Require account/app publisher consistency. | The official external app id carries publisher digits; matching them locally prevents an avoidable cross-account mistake. |
| Accept only `RICH_MEDIA` and `VIDEO`. | These are the only public v1beta `adTypes` values and avoid arbitrary strings. |
| Keep admin unable to invoke writer operations. | Capability separation is an allowlist boundary, not a privilege hierarchy. |
| Do not retry ambiguous creates. | A timeout can occur after provider acceptance; retrying could create a duplicate with no API delete path. |
| Keep 403 as a redacted provider failure. | The API explicitly has limited access, while the gateway cannot determine or promise account entitlement. |

## 13. Open Questions

None. The official schema and supplied issue body are sufficient for planning.
The separate token-bound plan/apply contract follows the existing mutation
policy in `design-docs/google-marketing-gateway-design.md` and
`design-docs/user-qa/pending-google-marketing-gateway-decisions.md`; it is not an
intentional divergence requiring a new user decision.

## 14. Risks and Rollout Constraints

| Risk | Impact | Mitigation |
|---|---|---|
| Limited-access 403 | A correctly built command may not work for an unentitled account. | Label the operation beta/limited-access, retain safe status, and never claim access was provisioned. |
| Duplicate create after timeout | Durable duplicate inventory with no public delete method. | Expiring single-use token, atomic claim, no replay after `executing`, and an unbounded semantic-intent block for ambiguous outcomes. |
| Writer scope accepted by reader/admin | Broader mutation authority crosses executable boundaries. | Exact capability/profile/operation checks and negative tests before credential resolution. |
| Cross-account app id | Ad unit is requested against the wrong account/app pairing. | Require matching publisher digits locally. |
| Generic body or enum expansion | Unsupported formats or provider fields become writable. | Typed four-field body, fixed Native format, closed ad-type enum, unknown-flag rejection. |
| Sensitive data in errors or state | Tokens, identifiers, names, or credential values leak into logs or durable plan records. | Store the canonical request only as authenticated ciphertext with a system-protected key; retain digest-only terminal records, preserve status-only provider errors, and add adversarial redaction fixtures. |
| Beta contract change | Request schema or access policy becomes stale. | Keep `v1beta` and limited access explicit; recheck official references before release. |

Rollout is complete only after adversarial review accepts the design, the active
implementation plan maps every requirement, all deterministic checks pass, and
documentation clearly distinguishes local implementation from live provider
entitlement. No commit or push occurs in this workflow.
