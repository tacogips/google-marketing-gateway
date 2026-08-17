# Installed desktop OAuth and token lifecycle

**Status:** Implemented and independently adversarially reviewed
**Implementation closure:** 2026-08-14 deterministic non-network verification
passes with no unresolved high or medium finding. Live OAuth/provider behavior
remains intentionally outside this contract.
**Feature:** `installed-desktop-oauth`
**Issue:** `workflow-input:installed-desktop-oauth`
**Workflow mode:** `issue-resolution`
**Contract verification date:** 2026-08-13

## 1. Purpose and bounded scope

This slice extends the existing reader without changing writer or admin
allowlists. It adds backward-compatible installed-desktop OAuth, safe token
lifecycle commands, Google Ads v25 reads, and Google Analytics Data v1beta
reads. It preserves the existing environment access-token path and the
capability and product isolation already enforced by `CredentialProfile`.

The only provider operations added are:

| CLI operation | Operation ID | Provider contract |
|---|---|---|
| `google-ads accessible-customers list` | `google-ads.accessible-customers.list` | `GET https://googleads.googleapis.com/v25/customers:listAccessibleCustomers` |
| `google-ads search` | `google-ads.search` | `POST https://googleads.googleapis.com/v25/customers/{customerId}/googleAds:search` |
| `analytics-data metadata get` | `analytics-data.metadata.get` | `GET https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}/metadata` |
| `analytics-data reports run` | `analytics-data.reports.run` | `POST https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}:runReport` |
| `analytics-data compatibility check` | `analytics-data.compatibility.check` | `POST https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}:checkCompatibility` |

`searchStream`, arbitrary REST requests, caller-supplied origins or headers,
Ads mutations, Analytics batch/pivot/realtime/funnel/audience-export operations,
service accounts, live OAuth, and live provider calls are out of scope.

## 2. Configuration contract

### 2.1 Backward-compatible profile fields

`CredentialProfile` retains all current keys and adds optional references:

```json
{
  "id": "ads-reader",
  "product": "google-ads",
  "capability": "reader",
  "oauthScopes": ["https://www.googleapis.com/auth/adwords"],
  "accessTokenEnvironmentVariable": "GOOGLE_ADS_ACCESS_TOKEN",
  "oauthClientJSONPath": "credentials/google-desktop-client.json",
  "tokenStorePath": "tokens/ads-reader.json",
  "developerTokenEnvironmentVariable": "GOOGLE_ADS_DEVELOPER_TOKEN",
  "loginCustomerIdEnvironmentVariable": "GOOGLE_ADS_LOGIN_CUSTOMER_ID"
}
```

`oauthClientJSONPath` and `tokenStorePath` are optional so every current JSON
fixture and environment-only profile decodes unchanged. The existing
`accessTokenEnvironmentVariable` remains required, preserving environment-first
selection for every profile. The config contains references only. Before typed
decoding, a structural pass requires a root JSON object whose only key is
`profiles` and requires every profile object to contain only its documented
keys. Every unknown root or profile key is rejected, including secret-bearing
keys such as embedded client JSON, client secret, access token, refresh token,
developer token value, or token-store JSON. This compensates for Swift's
default unknown-key behavior.

Paths may be absolute or relative. Relative paths resolve against the directory
containing the selected config file, not the process working directory. The
resolved standardized absolute paths are runtime values and are never written
back into config. Each configured path is at most 4,096 UTF-8 bytes. Empty
paths, NUL bytes, a path resolving to `/`, and a token
store resolving to the config or OAuth client file are invalid. Distinct
profiles must resolve to distinct token-store paths. This prevents accidental
cross-profile overwrite or logout.

Installed login and refresh require both OAuth path fields. A profile with only
one is invalid. Environment-only profiles omit both and continue to work.
The existing public five-argument `CredentialProfile` initializer remains
source-compatible; new optional arguments default to `nil`.

### 2.2 Product and scope isolation

Profiles remain reader-only. Scope arrays must contain unique strings and must
exactly match one supported product bundle; being a subset of all known Google
scopes is insufficient.

| Product | Accepted reader scope bundles |
|---|---|
| `adsense` | exactly `adsense.readonly` |
| `admob` | exactly `admob.readonly`, exactly `admob.report`, or exactly both current scopes |
| `google-ads` | exactly `https://www.googleapis.com/auth/adwords` |
| `analytics-data` | exactly `https://www.googleapis.com/auth/analytics.readonly` |

The AdMob alternatives retain compatibility with the checked-in report-only
fixture. A scope belonging to a different product, an unknown scope, duplicate
scope, extra scope, or empty scope bundle is rejected before any credential
file or environment value is read. Operation authorization continues to
require matching product, reader capability, and an accepted operation scope.

Google Ads profiles must declare a safe uppercase
`developerTokenEnvironmentVariable`. Its value exists only in the process
environment and is never decoded from config, accepted as a CLI argument, or
persisted. Other products reject Ads-only fields.
`loginCustomerIdEnvironmentVariable` is optional and, when present, must be a
safe uppercase environment-variable name. Its resolved value must contain
1...20 ASCII digits; hyphens, whitespace, signs, and Unicode digits are
invalid. Google Ads operation `--customer-id` uses the same value rule. The
length bound is local input safety, not a claim about provider allocation.

### 2.3 File safety boundary

OAuth client and token-store I/O is behind an injected file-system protocol.
Production mutation does not validate a path and then mutate it through an
independent lookup. It traverses components without following symlinks, opens
the final parent directory descriptor, and uses descriptor-relative
`fstatat`/`openat`/`renameat`/`unlinkat` equivalents:

- OAuth client input must be a user-owned regular file of at most 1 MiB, opened
  without following the final symlink and read from that descriptor, never a
  symlink, directory, device, or socket.
- Token-store reads and logout reject a symlink or non-regular file. A present
  store must be owned by the current user and must not grant group/other bits.
- A missing final parent directory may be created with mode `0700`. The final
  store directory must be a current-user-owned real directory with no group or
  other permissions. Traversed components are opened without symlink following;
  directory descriptors, rather than re-resolved strings, anchor subsequent
  operations. An existing final store must pass ownership, type, mode, resolved
  profile, and device/inode checks before replacement.
- Persistence exclusively creates a random same-directory temporary name
  relative to the anchored descriptor with mode `0600`, writes the bounded
  payload, verifies descriptor metadata, syncs it, revalidates the destination
  name and expected device/inode when replacing an existing store, atomically
  renames relative to that descriptor, verifies the installed file, and syncs
  the directory. Cleanup unlinks only the exact temporary descriptor-relative
  name.
- Logout opens the final file without following symlinks, validates the
  token-store schema, `profileId`, product, owner, type, mode, and resolved path,
  records its device/inode, then verifies that the directory entry still names
  that device/inode immediately before descriptor-relative unlink. Because the
  anchored parent is private and not writable by group/other users, a
  substituted external target cannot pass this sequence. Missing files return
  `removed: false`; any mismatch fails closed and remains untouched.

These rules apply to production. The test file system is in-memory or rooted in
a test-created temporary directory and exposes injected failures around write,
sync, rename, and removal.

## 3. OAuth login

The reader adds:

```text
auth login --profile <id> --config <path>
  [--no-browser] [--redirect-uri <loopback-uri>] [--timeout-seconds <n>]
auth status --profile <id> --config <path>
auth logout --profile <id> --config <path>
```

`--config` may still be supplied by `GOOGLE_MARKETING_GATEWAY_CONFIG`.
`--no-browser` is the explicit manual/test mode: the command emits the
authorization URL and continues waiting for the loopback callback. Browser
launch uses an injected opener and a fixed executable invocation, never a
shell. `--redirect-uri` is optional and intended for deterministic tests; it
must be `http://127.0.0.1:<1...65535>/<path>` with no user info, query, or
fragment. Its path is 1...1,024 ASCII bytes, begins with `/`, and contains no
percent encoding, dot segment, control byte, or NUL. The default binds IPv4
`127.0.0.1` on port `0` and uses
`/oauth2callback`, then constructs the redirect from the assigned random port.

The downloaded OAuth JSON is size-bounded, UTF-8 JSON, and must contain an
`installed` object with a nonblank `client_id`. A `web`-only file is rejected.
The bound is 1 MiB; `client_id` and endpoint text fields are each at most 4,096
UTF-8 bytes, and the optional client secret is at most 16,384 bytes. NUL and
ASCII control bytes are invalid.
The optional client secret is consumed for token exchange but never exposed.
Authorization and token endpoints are gateway constants on official Google
HTTPS origins; config file URI fields cannot redirect network traffic.

Login generates state and a PKCE verifier independently from a cryptographically
secure injected random-byte source. Each is derived from at least 32 random
bytes using unpadded base64url. The verifier meets RFC 7636's 43-128 character
set; the challenge is unpadded base64url SHA-256 and the method is exactly
`S256`.

The authorization URL contains only gateway-owned keys: `client_id`, the exact
loopback `redirect_uri`, `response_type=code`, the profile's exact joined scope
bundle, random `state`, `code_challenge`, `code_challenge_method=S256`,
`access_type=offline`, `include_granted_scopes=false`, and `prompt=consent`.
Duplicate or caller-defined authorization parameters are impossible.

The loopback timeout defaults to 300 seconds and accepts 1...600 seconds. It
handles at most 32 invalid connections, an 8 KiB request line, 16 KiB aggregate
headers, and 32 KiB total request bytes per connection. It accepts `GET` only.
The raw request-target path bytes must equal `/oauth2callback` or the explicitly
configured ASCII path byte-for-byte; percent-encoded aliases, dot segments,
duplicate query keys, fragments, and malformed encoding are invalid. The state
is 43 characters and must match exactly for every terminal callback, including
a provider `error`. Invalid method/path/state requests receive a fixed response
and are ignored within the connection limit so a stray request cannot
immediately terminate login. A state-valid callback with a provider error
terminates through a fixed sanitized category; a state-valid callback with a
missing or empty code fails. The code is at most 8 KiB. Neither code nor state
is emitted. Only the first state-valid terminal callback is processed.

The authorization-code exchange is injected and sends an
`application/x-www-form-urlencoded` POST to the fixed Google token endpoint
with `code`, `client_id`, optional client secret, exact `redirect_uri`,
`grant_type=authorization_code`, and the verifier. Request bodies, URLs, and
headers are never placed in errors or logs.

The decoded token response requires a valid header-safe access token and
`token_type` equal to Bearer when compared case-insensitively. A returned scope
string must exactly match the selected profile's scope set; if omitted, the
requested profile scopes are recorded. `expires_in` is required in the range
1...31,536,000 seconds so addition cannot overflow the injected clock; it becomes the
required `expiresAt`. Login requires a valid refresh token because persistent
installed OAuth is the purpose of the command. Only after all validation
succeeds is the store atomically persisted.

## 4. Token store, resolution, refresh, status, and logout

The private token store is bounded to 1 MiB and is versioned Codable JSON containing `schemaVersion`,
`profileId`, product, exact scopes, access token, refresh token, token type,
`expiresAt`, and `updatedAt`. It contains no developer token or OAuth client
secret. Unknown schema versions, profile/product/scope mismatches, malformed
dates, missing access token, or non-Bearer token types fail closed.

Reader token resolution is:

1. Validate config, selected profile, product, capability, and operation scope.
2. If the configured environment variable contains a nonblank access token,
   use it immediately. Do not read OAuth client or token-store files and do not
   attempt refresh.
3. Otherwise require the installed OAuth paths and load the selected private
   token store.
4. If the access token expires more than 60 seconds after the injected current
   time, use it.
5. Otherwise require the refresh token and installed client, POST a refresh
   request to the fixed Google token endpoint through the injected transport,
   validate the response, preserve the existing refresh token when Google omits
   a replacement, and atomically persist before returning the new token.

Refreshing uses `grant_type=refresh_token`, refresh token, client ID, and
optional client secret. A returned scope, if present, must exactly match the
profile. A refresh response also requires `expires_in` in the same
1...31,536,000-second range, making
`expiresAt` mandatory for every persisted store. Refresh persistence is
required: an operation does not proceed with a
new token that could not be stored. Concurrent refreshes are serialized within
the process per resolved store path; atomic replace and schema validation keep
cross-process outcomes well formed, but cross-process duplicate refresh is an
accepted residual risk for this local CLI slice.

`auth status` performs no network request and never refreshes. It outputs only
an allowlisted JSON object: profile ID, product, exact configured scopes,
`environmentTokenAvailable`, `tokenStoreConfigured`, `tokenStoreExists`, store
state (`missing`, `ready`, `near-expiry`, `expired`, or `invalid`), `expiresAt`,
and `hasRefreshToken`. It never emits token values, client ID, client secret,
authorization URL, developer-token name/value, HTTP headers, raw provider body,
or token-store contents. An invalid store reports `invalid` without echoing
parser input.

`auth logout` does not mutate environment values or the OAuth client file. It
applies the safe deletion rules in section 2.3 and returns only profile ID,
product, and `removed`. It is idempotent for a missing store.

## 5. Google Ads v25 reader

Both requests use only the fixed `https://googleads.googleapis.com` origin and
the literal `v25` prefix. They set `Authorization: Bearer <resolved token>` and
`developer-token: <environment value>`. `login-customer-id` is added only from
validated profile config. No CLI option can add or override a header, origin,
method, or path.

Access tokens, refresh tokens, authorization codes, client IDs/secrets, and
developer tokens are bounded opaque values: 1...16,384 UTF-8 bytes, except the
client ID's 4,096-byte bound and the callback code's 8 KiB bound above. NUL and
ASCII controls are invalid in every use. Values placed in HTTP headers must
additionally be ASCII bytes `0x21...0x7E`; spaces, DEL, and non-ASCII bytes are
invalid. Blank, oversized, or unsafe environment tokens fail with a fixed error
that does not echo the value.

`accessible-customers list` uses the exact GET URL in section 1 and has no
caller-defined path or body.

`search` requires `--customer-id <digits>` and a 1...4,096 UTF-8 byte
`--query-file <path>` without NUL, with an
optional opaque `--page-token`. GAQL is never accepted inline. The file must be
a no-follow regular file, valid UTF-8, nonempty after whitespace trimming, and
no larger than the documented gateway safety limit of 1 MiB. This is a local
resource bound, not a claimed provider maximum. The query is preserved rather
than rewritten. A page token must be 1...8,192 UTF-8 bytes with no NUL or ASCII
control bytes when present.

The typed Codable body uses official camelCase JSON:

```json
{"query":"SELECT ...","pageToken":"opaque-provider-token"}
```

`pageToken` is omitted when absent. The request uses `Content-Type:
application/json`; headers and secrets are never printed. Provider output
remains validated JSON passthrough, consistent with current reader operations.

## 6. Analytics Data v1beta reader

All operations use only `https://analyticsdata.googleapis.com` and the literal
`v1beta` prefix. `--property` must exactly match `properties/<ASCII digits>`.
The property ID contains 1...20 digits as a local input-safety bound.
Metadata uses GET and no body. Report and compatibility use POST with
`Content-Type: application/json` and typed Codable bodies with explicit
camelCase coding keys. Every request uses only the resolved bearer
`Authorization` header plus gateway-owned standard headers; callers cannot add
or override headers, origins, methods, or paths.

`reports run` requires real Gregorian `YYYY-MM-DD` values for `--start-date`
and `--end-date`, with start not later than end, plus at least one nonblank
comma-separated metric. Optional dimensions use the same nonblank list parser.
The gateway does not impose undocumented provider metric or dimension name
semantics. It rejects duplicates, control characters, and values beyond local
input-size/count safety bounds documented in CLI help.

`--offset`, when present, is a nonnegative signed-64-bit value. `--limit` is a
positive signed-64-bit value. They encode as decimal JSON strings, matching the
API's Int64 JSON representation; no undocumented provider maximum is imposed.
`--currency-code` is exactly three uppercase ASCII letters. Optional
`--keep-empty-rows` and `--return-property-quota` are boolean switches and are
omitted from JSON when not supplied. The request model is structurally:

```json
{
  "dateRanges": [{"startDate":"2026-08-01","endDate":"2026-08-07"}],
  "metrics": [{"name":"activeUsers"}],
  "dimensions": [{"name":"date"}],
  "offset": "0",
  "limit": "1000",
  "currencyCode": "JPY",
  "keepEmptyRows": true,
  "returnPropertyQuota": true
}
```

`compatibility check` requires metrics and accepts optional dimensions. Its
body contains only `metrics` and the optional `dimensions` arrays. No report
dates, pagination, or arbitrary compatibility filters are introduced.

For both Analytics POST operations, metrics contain 1...100 items and
dimensions contain 0...100 items. Each trimmed item is 1...256 UTF-8 bytes,
contains no ASCII control or NUL byte, and is unique within its list; the total
encoded CLI value for either list is at most 32 KiB. These are gateway resource
bounds, not assertions about provider field-name or count maxima.

## 7. Code boundaries and injection

The existing `GoogleMarketingGatewayCore` target remains the only library
target. Responsibilities are split before any file reaches 1000 lines:

- `CredentialProfiles.swift`: schema and product/bundle validation.
- `CredentialProfilePaths.swift`: config-relative path resolution.
- `OAuthModels.swift`: client/token Codable models and sanitized validation.
- `OAuthPKCE.swift`: secure state/verifier/challenge and authorization URL.
- `OAuthLoopback.swift`: bounded IPv4 callback receiver.
- `OAuthTokenStore.swift`: safe versioned persistence and inspection.
- `OAuthClient.swift`: fixed-endpoint exchange and refresh.
- `ReaderCredentialResolver.swift`: environment-first selection and refresh.
- `ReaderAuthCommands.swift`: login/status/logout orchestration and safe output.
- `GoogleAdsRequests.swift`: v25 typed request construction and GAQL loading.
- `AnalyticsDataRequests.swift`: v1beta typed request models and construction.
- `GatewayCLI.swift` plus focused extensions: command routing and flags.
- `OperationCatalog.swift`: the five exact operation descriptors.

Injection covers transport, clock, secure randomness, browser opening, callback
receiver, environment, and file system. Default production implementations are
`Sendable`; tests use deterministic fakes. Auth transport shares the existing
async `HTTPTransport` abstraction but has separate response decoding so token
payloads cannot flow through public API output.

## 8. Error and redaction policy

All failures map to stable gateway codes and fixed messages. Sanitization may
retain an HTTP status and a provider status/reason only when each matches a
strict bounded safe-character allowlist. It never includes localized underlying
errors, request descriptions, response bodies, query contents, file contents,
callback parameters, environment values, headers, token response fields,
client fields, or secret-bearing URLs.

Tests seed unique canary values into every secret source and assert absence
from stdout, stderr, thrown messages, descriptions, and debug output for both
success metadata and each failure category.

## 9. Documentation and compatibility

The implementation updates operation catalog/help, `README.md`, this design's
status/evidence, and `impl-plans/completed/foundation-publisher-readers.md` only
when implementation is performed. Documentation must state Google Ads v25,
Analytics Data v1beta, exact scopes, path-only config, environment-first token
selection, developer-token environment lookup, installed login commands, and
the prohibition on live secrets in commands or config.

Compatibility acceptance requires the existing `reader-profiles.json` fixture
to decode and all current AdSense/AdMob CLI tests to pass unchanged. New
optional fields must not change environment-token behavior or require OAuth
files when the environment token is present.

## 10. Verification and acceptance

Deterministic tests must cover:

- OAuth URL keys, percent encoding, state entropy source, PKCE S256 vectors,
  callback method/path/state/duplicate-key/size/timeout behavior, and manual
  versus browser launch;
- installed versus web client parsing, fixed endpoint use, token response
  parsing, exact returned scopes, Bearer validation, and expiry calculation;
- user-only atomic store modes, interrupted writes, symlink/non-regular/wrong
  owner/profile/product/scope rejection, safe status, and scoped logout;
- environment precedence with zero file/network calls, fresh-store selection,
  near-expiry refresh, refresh-token preservation, required persistence, and
  injected concurrent/error paths;
- exact scope bundles, cross-product/secret-key rejection, Ads-only field
  isolation, path resolution, duplicate token paths, and old fixture decoding;
- exact Ads method/origin/v25 paths, identifier/header inclusion rules, body,
  page token, GAQL regular-file/UTF-8/empty/oversize behavior, and no arbitrary
  request surfaces;
- exact Analytics method/origin/v1beta paths, camelCase bodies, property/date/
  list/numeric/currency/boolean validation, omitted optionals, and required
  metrics;
- catalog and CLI dispatch of all five operations plus auth commands, help and
  non-network smoke behavior, provider/auth/file error redaction, and current
  operation regression coverage.

Expected URLs, headers, and JSON in contract tests are hand-authored and do not
reuse production endpoint constants, request builders, encoders, or validators.
OAuth primitives include published RFC 7636 vectors; parser fixtures and
transport/file-system spies are independent of production serialization and
prove absence as well as presence of calls.

No live OAuth or provider call is an acceptance command. Required local
verification is:

```bash
mise run lint
mise run test
mise run build
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config <fixture>
swift run google-marketing-gateway-reader auth status --profile <fixture-id> --config <fixture>
swift run google-marketing-gateway-reader auth logout --profile <missing-store-fixture-id> --config <fixture>
git diff --check
```

The final review also checks non-generated Swift files remain below 1000 lines
and scans the diff for secret-like values, private URLs, machine-local absolute
paths, authorization headers in output, and unintended files. Placeholders in
commands above must be replaced by checked-in non-secret test fixtures.

## 11. Review record and residual risks

Self-review on 2026-08-13 found and corrected these design defects before
independent review: unknown-key decoding could admit embedded secrets; relative
path resolution and cross-profile token-store collision were unspecified;
logout could delete an unrelated configured file; environment precedence did
not explicitly prohibit credential-file reads; Analytics Int64 JSON encoding
and boolean switch omission were ambiguous. Independent review then found one
high-severity filesystem race/deletion defect and five medium-severity defects:
unsafe header values, absent-expiry ambiguity, callback denial/path ambiguity,
incomplete root-key rejection, and unspecified resource limits. The accepted
revision anchors mutations to private directory descriptors with inode
revalidation, validates bounded header values, requires expiry, ignores invalid
callbacks within explicit limits, strictly allowlists all config keys, and
defines deterministic bounds. Its low findings also made initializer source
compatibility, Analytics header isolation, and independent test oracles explicit.

Residual low risks accepted for this slice are cross-process duplicate refresh,
user disclosure of the manual authorization URL, and provider contract changes
after the verification date. Atomic persistence prevents malformed stores;
manual mode is explicit; pinned versions and contract tests detect drift before
an intentional version update.
