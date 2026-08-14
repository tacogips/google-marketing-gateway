# Google Ads v25 reader

**Feature ID**: `google-ads-v25-reader`
**Issue**: `workflow-input:google-ads-v25-reader`
**Workflow mode**: `issue-resolution`
**Status**: Implemented and independently adversarially reviewed
**Implementation closure**: 2026-08-14 deterministic non-network verification
passes with no unresolved high or medium finding. Live Google Ads access remains
intentionally outside this contract.
**Last reviewed**: 2026-08-13
**Related shared contract**: `design-docs/specs/installed-desktop-oauth.md`

## Purpose

Add a bounded, read-only Google Ads surface to the reader executable. The
surface supports listing accessible customer resource names and running one
paged GAQL search against a caller-selected customer. It uses a product-isolated
OAuth profile, reads the Google Ads developer token only from an environment
variable named by that profile, and never allows callers to choose an HTTP
origin, path, method, or header.

This document is the Google Ads feature contract. Installed-desktop OAuth login,
token refresh, token-store persistence, status, and logout are shared reader
credential capabilities designed and implemented outside this feature. This
feature consumes the shared access-token resolver and adds only Google
Ads-specific profile fields and request behavior.

## Scope

### Included

- Google Ads reader profiles using the exact OAuth scope
  `https://www.googleapis.com/auth/adwords`.
- A required `developerTokenEnvironmentVariable` reference and an optional
  `loginCustomerId` in Google Ads profiles.
- `google-ads accessible-customers list`.
- `google-ads search --customer-id <digits> --query-file <path>
  [--page-token <token>]`.
- Fixed Google Ads API v25 request construction, bounded GAQL file loading,
  catalog/help/config documentation, and deterministic tests.
- Compatibility with the existing environment access-token profile form and
  with the shared installed-desktop OAuth profile form.

### Excluded

- Mutations, streaming search, automatic pagination, query generation, query
  rewriting, customer discovery beyond `listAccessibleCustomers`, arbitrary
  Google Ads endpoints, live provider calls, and OAuth bootstrap internals.
- Validation of GAQL semantics that only Google Ads can authoritatively decide.
- Reading developer-token values from config files, command arguments, token
  stores, stdin, or OAuth client JSON.

## Public configuration contract

The existing JSON `profiles` array remains the configuration container. The
shared credential work makes access-token environment references and installed
OAuth paths alternative credential sources without invalidating old fixtures.
Google Ads adds these product-specific properties:

| Property | Requirement | Validation and handling |
| --- | --- | --- |
| `product` | Required | Must equal `google-ads`. |
| `capability` | Required | Must equal `reader`. |
| `oauthScopes` | Required | Set must equal exactly `{https://www.googleapis.com/auth/adwords}`; duplicates, omissions, and every cross-product scope are rejected. |
| `developerTokenEnvironmentVariable` | Required | Non-empty, safe environment-variable name using the existing uppercase ASCII identifier rules. Only the referenced environment value is read at operation execution time. |
| `loginCustomerId` | Optional | When present, must be a non-empty sequence of ASCII digits. Hyphens, whitespace, signs, separators, Unicode digits, and path characters are rejected. |

Every profile retains its existing required `accessTokenEnvironmentVariable`.
An installed OAuth profile additionally supplies both optional shared
OAuth-client JSON path and token-store path references; resolution still checks
the named access-token environment value first. Config files contain references
and paths only: client JSON content, client secrets, access tokens, refresh
tokens, and developer-token values are forbidden configuration values.

Example shape, with values intentionally limited to non-secret references:

```json
{
  "profiles": [
    {
      "id": "ads-reader",
      "product": "google-ads",
      "capability": "reader",
      "oauthScopes": ["https://www.googleapis.com/auth/adwords"],
      "accessTokenEnvironmentVariable": "GOOGLE_MARKETING_ADS_ACCESS_TOKEN",
      "developerTokenEnvironmentVariable": "GOOGLE_MARKETING_ADS_DEVELOPER_TOKEN",
      "loginCustomerId": "1234567890"
    }
  ]
}
```

Unknown product-specific fields continue to follow the shared decoder policy.
The two known Google Ads-only fields are rejected when present on any other
product profile. No Google Ads addition may change the meaning of previously
valid AdSense or AdMob profile fixtures. Scope validation is modeled as
product-specific allowed bundles so Google Ads can require its singleton exact
bundle while retaining the already accepted bundles for existing products.

## Credential resolution and safe output

For either Google Ads operation, resolution occurs in this order:

1. Load and validate the selected `--config` and `--profile`.
2. Require `product == google-ads`, `capability == reader`, and the exact Google
   Ads scope bundle.
3. Resolve the OAuth bearer token through the shared reader token resolver. Its
   contract prefers the configured access-token environment value and otherwise
   loads or refreshes the selected installed-app token store.
4. Read the developer-token value only from the environment-variable reference
   on the validated profile. Reject a missing, whitespace-only, over-4096-byte,
   or ASCII-control-bearing value with a sanitized missing/invalid-credential
   error before request construction. The 4096-byte cap is a local header-safety
   limit, not a claimed provider limit.
5. Construct the fixed request. The secret values exist only in request headers
   and are never copied into result, status, catalog, help, debug, or error text.

Auth status uses the shared installed-OAuth allowlist and does not add Google
Ads-specific fields. In particular, it emits neither developer-token name,
value, nor availability and emits neither login customer ID nor a configured
flag. It must not emit bearer or refresh tokens, OAuth client secret, full
token-store content, constructed headers, or provider bodies. Provider and
transport errors use the existing allowlisted status-code projection and never
include response bodies or request headers.

## Command and operation contracts

| CLI | Catalog operation ID | Method and fixed URL |
| --- | --- | --- |
| `google-ads accessible-customers list` | `google-ads.accessible-customers.list` | `GET https://googleads.googleapis.com/v25/customers:listAccessibleCustomers` |
| `google-ads search --customer-id <digits> --query-file <path> [--page-token <token>]` | `google-ads.search` | `POST https://googleads.googleapis.com/v25/customers/{customerId}/googleAds:search` |

Both descriptors use product `google-ads`, capability `reader`, availability
`implemented`, and only the `adwords` OAuth scope. CLI routing must explicitly
support the two-token `google-ads search` command instead of assuming every
reader command has three command words. Unknown or duplicate flags remain
errors. `--config` and `--profile` remain mandatory through the existing
selection contract.

### Identifier and flag validation

- `--customer-id` uses the same non-empty ASCII-digits-only rule as
  `loginCustomerId`; it is interpolated only after validation.
- `--query-file` is required and is the only source of GAQL. There is no
  `--query` flag or stdin fallback.
- `--page-token`, when present, must be non-empty, no larger than 16,384 UTF-8
  bytes, and contain no ASCII control characters. The byte cap is a local
  request-safety limit, not a provider contract. The token remains opaque and is
  placed only in JSON.
- Accessible-customers accepts no operation-specific flags.
- No command accepts origin, URL, path, version, HTTP method, header, developer
  token, access token, or login customer ID overrides.

## Bounded GAQL file handling

The implementation defines `1_048_576` bytes (1 MiB) as the maximum GAQL file
size. Loading is injectable for deterministic tests and follows these rules:

1. Open the caller-selected path read-only without following a terminal symlink.
2. Inspect the opened descriptor, require a regular file, and reject directories,
   devices, sockets, FIFOs, and terminal symlinks.
3. Reject a reported size over 1 MiB, then read at most 1 MiB plus one byte so a
   concurrent growth cannot make the read unbounded.
4. Require valid UTF-8 and reject empty or whitespace-only content.
5. Preserve the validated text exactly in the request model; do not trim,
   normalize, expand includes, interpolate variables, or interpret paths found
   inside it.

Errors identify the invalid input category without echoing file contents,
tokens, headers, or provider response bodies. The selected query path may be
reported only where ordinary CLI argument errors already report user-supplied
paths; it is never included in provider-facing JSON.

## Fixed transport contracts

### Accessible customers

- Scheme and host are exactly `https` and `googleads.googleapis.com`.
- Method is `GET`; path is exactly
  `/v25/customers:listAccessibleCustomers`; query and body are absent.
- Headers include `Authorization: Bearer <resolved-access-token>` and
  `developer-token: <environment-value>`.
- `login-customer-id: <validated-config-value>` is included only when configured.

### Paged search

- Scheme and host are exactly `https` and `googleads.googleapis.com`.
- Method is `POST`; the only variable path segment is the validated customer ID.
- `Content-Type` is `application/json`; credential and optional login-customer
  headers are identical to accessible-customers.
- A typed `Codable` body uses official camelCase keys:

```json
{
  "query": "SELECT ...",
  "pageToken": "opaque-next-page-token"
}
```

`pageToken` is omitted when absent. The request builder accepts typed validated
inputs, not arbitrary `URLRequest`, `URL`, header dictionaries, or raw JSON.
Response handling remains the shared JSON-validated, sanitized pass-through.

## Type and dependency boundaries

- `CredentialProfile` owns optional Google Ads metadata and delegates
  product-specific validation to a closed product rule.
- A dedicated Google Ads request builder owns v25 origin/path/method/header/body
  construction.
- A small bounded UTF-8 file-reader protocol separates filesystem behavior from
  CLI parsing and is injectable in tests.
- The CLI maps command words and flags to typed Google Ads inputs, asks the
  shared access-token resolver for a bearer token, resolves the developer token,
  then invokes the existing `GoogleRESTClient` through injected transport.
- Closed enums or typed route values represent supported operations; no public
  mutation or general-purpose transport surface is added.
- New and modified non-generated Swift files remain below 1000 lines and follow
  existing SwiftPM target boundaries.

## Failure behavior

Validation and local I/O failures exit without any network request. They use the
existing structured error envelope and distinguish invalid arguments,
configuration/profile failures, missing credentials, transport failure,
provider failure, and invalid responses. Error strings do not interpolate
credential values, HTTP headers, OAuth client/token JSON, GAQL contents, or raw
provider/client error bodies.

## Deterministic verification contract

Tests must cover:

- exact Google Ads scope acceptance and rejection of mixed, duplicate, empty,
  and cross-product bundles while old profile fixtures still decode;
- required and safely named developer-token environment references, missing or
  blank, control-bearing, and over-limit environment values, and optional login
  customer ID validation;
- shared safe config/auth status projections and error redaction with developer
  token/login-customer metadata and sentinel secret values absent from output;
- both operation catalog entries and dispatch of both CLI shapes;
- exact methods, scheme, host, v25 paths, absent query strings, JSON camelCase,
  omitted optional page token, and all required/conditional headers;
- rejection of malformed customer IDs and forbidden flags before transport;
- GAQL missing, unreadable, symlink, non-regular, empty, whitespace-only,
  invalid-UTF-8, exactly-at-limit, over-limit, and concurrent-growth cases;
- opaque page-token handling, including exact-limit and over-limit cases,
  without moving it to a URL or header;
- transport recording proving no request on local validation failures and no
  arbitrary origin/path/header mutation surface;
- sanitized provider/client errors that cannot echo bearer, developer token,
  login customer ID, GAQL, token store, or OAuth client secret sentinels.

All network behavior is exercised with injected fakes. Verification performs no
live OAuth flow and no Google Ads call.

## Documentation requirements

The operation catalog, CLI help, README, this design status/evidence, and
`impl-plans/completed/foundation-publisher-readers.md` must identify Google Ads API
v25, the exact `adwords` scope, the two commands, environment-only developer
token resolution, optional hyphen-free login customer ID, the 1 MiB GAQL bound,
and the absence of mutation and arbitrary transport support.

## Review record

### Design self-review

Decision: accepted after correction. The first pass left the bounded-file race
and variable command arity implicit and did not make rejection of Google
Ads-only fields on other products normative. The design now requires
descriptor-based regular-file checks, a limit-plus-one read, explicit two-token
search routing, and rejection of misplaced Ads metadata. These were design
defects because they changed security, isolation, and dispatch contracts.

### Independent adversarial design review

Decision: accepted after correction. The review identified two medium design
findings in the first saved draft: a terminal symlink could redirect the GAQL
read after validation, and safe status metadata could accidentally reveal the
configured login customer ID. The accepted design rejects terminal symlinks at
open time and adds no Ads fields to shared auth status.

A second independent pass found three medium integration/safety defects: local
operation IDs disagreed with the accepted shared OAuth design, page tokens had
no local byte bound, and developer-token values containing header controls were
not expressly rejected. The accepted design now uses
`google-ads.accessible-customers.list` and `google-ads.search`, caps page tokens
at 16,384 UTF-8 bytes, and rejects developer-token values over 4096 bytes or
containing ASCII controls before transport. No high or medium design finding
remains.

The review also checked credential leakage, profile/scope isolation, identifier
injection, path traversal and special-file reads, unbounded input, arbitrary
transport exposure, API-version drift, provider-error reflection, and legacy
fixture compatibility.

## Implementation references

- `<mail-gateway-checkout>/Sources/MailGatewayCore/ConfigLoading.swift`
- `<mail-gateway-checkout>/Tests/MailGatewayCoreTests/ConfigLoadingTests.swift`

These references inform config-relative path handling, validation timing, and
compatibility testing only. Their support for secret JSON environment values is
not copied: this gateway's config and environment contracts permit secret values
only in the dedicated access-token/developer-token environment channels, the
referenced installed-desktop client JSON file, and the shared token store, never
embedded client/token JSON configuration fields.
