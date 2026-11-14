# Search Console reader

**Feature ID**: `search-console-reader`

**Issue**: `workflow-input:Implement complete Search Console reader slice`

**Workflow execution**: `codex-design-and-implement-review-loop-session-713`

**Workflow mode**: `issue-resolution`

**Status**: Implemented; final adversarial review and verification complete
**Implementation closure**: 2026-08-14 all 27 focused deterministic tests and
the full non-network matrix pass with no unresolved high or medium finding.

**Risk level**: High

**Contract verification date**: 2026-08-13

## Purpose

Add the complete bounded Search Console read surface to
`google-marketing-gateway-reader`. The slice covers property discovery, Search
Analytics queries, sitemap reads, and URL inspection. It preserves the existing
reader/writer/admin executable boundary: Search Console `POST` report and
inspection methods are logical reads, while sitemap submission/deletion and site
association changes remain unavailable from every executable in this slice.

The gateway is not a generic Search Console proxy. Callers select only validated
operation inputs. They cannot select an origin, API version, arbitrary path,
method, header, authorization value, or raw request body.

## Scope

### Included

- Search Console reader profiles with the exact OAuth scope
  `https://www.googleapis.com/auth/webmasters.readonly`.
- Existing environment access-token resolution and installed-desktop OAuth
  store resolution.
- `sites.list`, `sites.get`, `searchanalytics.query`, `sitemaps.list`,
  `sitemaps.get`, and URL Inspection `index.inspect`.
- Strict typed Search Analytics JSON loaded from a bounded regular file.
- URL-prefix and `sc-domain:` property identifiers.
- Fixed-origin request construction, sanitized errors, operation catalog/help
  registration, deterministic tests, and non-network verification.

### Excluded

- Sitemap submit/delete, site add/delete, arbitrary URL fetches, batch or
  automatic pagination, mutation planning, response materialization, and live
  OAuth/provider calls.
- Deprecated Search Analytics `searchType` and unmodeled request fields.
- Provider-semantic decisions such as whether a property is verified, a URL is
  owned by a property, a filter combination is supported, or results are
  complete. Those remain provider validation.
- Any change to writer/admin mutation allowlists. Absence from reader help and
  the operation catalog is mandatory; exclusion is not merely documentation.

## Public command and operation contract

All routes require the shared `--config <path>` and `--profile <id>` selection.
The reader exposes exactly these Search Console routes:

| CLI route | Operation ID | Provider request |
| --- | --- | --- |
| `search-console sites list` | `search-console.sites.list` | `GET https://www.googleapis.com/webmasters/v3/sites` |
| `search-console sites get --site <property>` | `search-console.sites.get` | `GET https://www.googleapis.com/webmasters/v3/sites/{siteUrl}` |
| `search-console search-analytics query --site <property> --request-file <path>` | `search-console.search-analytics.query` | `POST https://www.googleapis.com/webmasters/v3/sites/{siteUrl}/searchAnalytics/query` |
| `search-console sitemaps list --site <property> [--sitemap-index <url>]` | `search-console.sitemaps.list` | `GET https://www.googleapis.com/webmasters/v3/sites/{siteUrl}/sitemaps[?sitemapIndex=...]` |
| `search-console sitemaps get --site <property> --feedpath <url>` | `search-console.sitemaps.get` | `GET https://www.googleapis.com/webmasters/v3/sites/{siteUrl}/sitemaps/{feedpath}` |
| `search-console url-inspection inspect --site <property> --inspection-url <url> [--language-code <BCP47>]` | `search-console.url-inspection.inspect` | `POST https://searchconsole.googleapis.com/v1/urlInspection/index:inspect` |

Unknown, duplicate, missing, or route-inapplicable flags fail locally. No route
accepts an origin, URL template, HTTP method, arbitrary query item, arbitrary
header, token, raw JSON, or inline Search Analytics expression.

Catalog descriptors use product `search-console`, capability `reader`,
availability `implemented`, and only the exact readonly scope. Writer and admin
continue to reject these CLI routes under their existing executable policy, and
their mutation catalogs remain unchanged.

## Profile and credential boundary

`MarketingProduct` adds the closed `search-console` product case. A selected
Search Console profile is valid only when:

- `product` is exactly `search-console`;
- `capability` is exactly `reader`;
- the OAuth scope array represents exactly the singleton set
  `{https://www.googleapis.com/auth/webmasters.readonly}`;
- duplicate, empty, writer, admin, and cross-product scopes are rejected; and
- product-specific fields belonging to another adapter remain rejected.

The shared credential source contract is unchanged. A configured non-empty
environment token takes precedence; otherwise the installed OAuth client and
token-store references may resolve or refresh the token. Profile status and
errors expose neither token values nor OAuth file contents. Adding Search
Console must not alter which AdSense, AdMob, Google Ads, or Analytics Data
profiles are accepted.

Credential resolution is deliberately late. For every route, the CLI first
parses the full route, rejects unsupported or duplicate flags, validates all
operation values, and securely loads/strictly validates any request file. It
then loads and validates the selected product profile. Only after every local
input is valid may it call the injected credential resolver, construct the
request, or invoke the injected transport. Tests observe resolver and transport
call counts independently.

## Input validation

### Search Console property

The `--site` value is bounded to 4,096 UTF-8 bytes, non-empty, and free of ASCII
control characters and backslashes. It must match one of two forms:

1. A fully qualified `http` or `https` URL-prefix property. It requires a
   non-empty host and rejects user information, fragments, malformed percent
   escapes, raw spaces or other characters that a URL parser would silently
   percent-encode, ambiguous parser output, and a path not ending in `/`. The
   parsed serialization must round-trip byte-for-byte to the caller value. A
   path, query, explicit port, and already-percent-encoded URL content may be
   preserved because the registered property string is provider-owned. The
   gateway never resolves the host and never uses this URL as the request
   origin.
2. `sc-domain:<domain>`, with no scheme, user information, port, path, query,
   fragment, wildcard, or trailing dot. The domain is an ASCII DNS name of at
   most 253 bytes; each dot-separated label is 1 through 63 letters, digits, or
   hyphens and cannot start or end with a hyphen. Punycode labels are accepted;
   Unicode display names are not normalized locally.

The original validated string is retained. Case, trailing slash, path, query,
port, and inner URL percent escapes are not rewritten. Provider ownership and
registration remain provider checks.

### Sitemap and inspected URLs

`--sitemap-index`, `--feedpath`, and `--inspection-url` each accept a
fully-qualified `http` or `https` URL bounded to 8,192 UTF-8 bytes. Each requires
a host and rejects user information, fragments, ASCII controls, backslashes,
raw spaces or other parser-normalized input, and malformed percent escapes. The
parsed serialization must round-trip byte-for-byte to the caller value. Paths,
queries, ports, and valid inner percent escapes are preserved. The first two
are sitemap/feed identifiers and the last is JSON data; none can control an
HTTP request origin.

`--language-code`, when present, is at most 255 ASCII bytes and is parsed as a
well-formed BCP 47 language tag: hyphen-separated non-empty subtags, valid
language/script/region/variant/extension/private-use ordering, and documented
subtag length and character rules. Variant subtags must be unique under
case-insensitive comparison, so values such as `en-1901-1901` are rejected;
extension singletons are likewise unique under case-insensitive comparison.
Registry membership and provider support are provider validation. The original
validated spelling is encoded.

### Search Analytics request file

`--request-file` is required for Search Analytics. Inline JSON, stdin, directory
walking, and include/interpolation behavior do not exist. The maximum size is
1,048,576 bytes.

The loader reuses or specializes the secure descriptor-based local-file
boundary:

1. Resolve the parent path one directory component at a time without following
   symlinks and open the terminal entry read-only with `O_NOFOLLOW`.
2. Use `fstat` on the open descriptor and require a regular file. Reject terminal
   symlinks, symlinked parent components, directories, devices, sockets, and
   FIFOs.
3. Reject a reported size over 1 MiB and read no more than 1 MiB plus one byte,
   so concurrent growth cannot create an unbounded read.
4. Capture descriptor identity, regular-file type, byte size, modification
   timestamp, and change timestamp before reading. After the bounded read,
   `fstat` the same descriptor again and require every captured field to match.
   Reject concurrent in-place overwrite, truncation, growth, metadata change,
   identity change, or type change before JSON decoding. Timestamp comparisons
   use the platform's full available resolution rather than seconds alone. The
   parsed bytes come from that descriptor, never from a path reopen. This is a
   fail-closed stability check, not a claim that filesystem metadata provides a
   cryptographic snapshot against a malicious privileged writer.
5. Require valid UTF-8 and exactly one valid JSON object. Reject empty input,
   malformed JSON, trailing JSON, duplicate JSON object keys at every nesting
   level, nesting beyond 64 containers including the root object, and every
   unknown field before model construction. The depth verifier must fail closed
   before descending into container 65; the 1 MiB byte bound does not substitute
   for this independent stack-safety bound.

Errors report only an allowlisted category such as invalid request file,
invalid request JSON, or invalid Search Analytics field. They never quote a
file fragment, filter expression, token, credential-bearing URL, raw provider
body, or decoded request object. Ordinary local file errors may identify the
caller-supplied path, but provider/transport errors may not.

## Search Analytics typed request

The strict `Codable`, `Sendable`, and `Equatable` request model uses the official
camelCase wire keys:

- required `startDate` and `endDate`;
- optional `dimensions`, `type`, `aggregationType`, `rowLimit`, `startRow`,
  `dataState`, and `dimensionFilterGroups`;
- each dimension-filter group has `groupType` and `filters`;
- each filter has required `dimension` and `expression` plus optional
  `operator`, whose provider default is `equals`.

No arbitrary JSON dictionary reaches the request builder. `searchType` is an
unknown field and therefore rejected.

### Closed values

- Dimensions: `query`, `page`, `country`, `device`, `date`, `hour`, and
  `searchAppearance`.
- Type: `web`, `image`, `video`, `news`, `discover`, and `googleNews`.
- Aggregation type: `auto`, `byPage`, `byProperty`, and
  `byNewsShowcasePanel`.
- Data state: `all`, `final`, and `hourly_all`.
- Filter group type: `and` only.
- Filter dimensions: `country`, `device`, `page`, `query`, and
  `searchAppearance`. `date` and `hour` are grouping dimensions but are not
  accepted filter dimensions by the official request contract.
- Filter operators: `equals`, `notEquals`, `contains`, `notContains`,
  `includingRegex`, and `excludingRegex`.

Unsupported spelling or capitalization is rejected rather than passed through.
The implementation must re-check the current official discovery/reference
contract if these closed sets differ at implementation time; it must update
this design and tests rather than silently accepting a new value.

### Semantic validation

- Dates are exact zero-padded Gregorian `YYYY-MM-DD`, represent real calendar
  dates, and satisfy `startDate <= endDate`.
- `rowLimit`, when present, is an integer in `1...25_000`.
- `startRow`, when present, is an integer in `0...Int.max`; booleans,
  fractions, exponent forms, numeric strings, and overflow are rejected by the
  strict decoder.
- `dimensions`, when present, contains no duplicates and no more than the seven
  supported dimensions. An empty array is accepted as the provider's
  no-dimension aggregation request.
- `dimensionFilterGroups`, when present, contains 1 through 100 groups. Every
  group must use `groupType: "and"`, every group contains at least one filter,
  and the request contains at most 100 filters in total. The group/filter counts
  are local resource-safety bounds; multiple AND groups retain the provider's
  all-groups-must-match semantics.
- Every filter expression is non-empty after a whitespace-only check, no more
  than the official 4,096-character limit, no more than 16,384 UTF-8 bytes as a
  local resource bound, valid UTF-8 by construction, and contains no ASCII
  control character. It is preserved exactly: no regex compilation, trimming,
  normalization, interpolation, logging, or inclusion in errors. Regex and
  dimension semantics remain provider validation.

- URL parsing must not silently normalize the caller value. Inputs that require
  URLComponents percent-encoding or host normalization are rejected locally;
  accepted identifiers retain their original validated spelling.

The 1 MiB file limit, group/filter count limits, 16,384-byte expression limit,
property limit, and URL limits are explicit local safety bounds, not claimed
provider quotas. The 4,096-character expression ceiling is provider-defined.

## Fixed-origin request construction

Two constant origins are allowed:

- Webmasters API: scheme `https`, host `www.googleapis.com`, base path
  `/webmasters/v3`;
- URL Inspection API: scheme `https`, host
  `searchconsole.googleapis.com`, base path `/v1`.

The request builders accept typed validated values and a resolved bearer token.
They do not accept a base URL, `URLComponents`, raw path, raw body, header map,
or `URLRequest` from a caller.

Path parameters are encoded exactly once as one segment. The encoder operates
on the original validated UTF-8 bytes, leaving only RFC 3986 unreserved bytes
(`A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, `~`) literal and percent-encoding every
other byte with uppercase hex. In particular `/`, `:`, `%`, `?`, `#`, and `@`
inside a property or feed URL cannot become path delimiters or authority
syntax. Constant path components are joined separately with the encoded
segments. The builder assigns the resulting value as an already-percent-encoded
path and never asks a URL API to encode it again. A literal inner `%2F` therefore
becomes `%252F` in the outer API path, preserving the property identifier rather
than double-decoding it.

`sitemapIndex` is the sole optional Webmasters query item. It is assigned through
`URLComponents.queryItems`; it is not concatenated into the path or query text.
The selected site and sitemap URL cannot change scheme, host, port, base path,
method, or headers.

All requests set `Accept: application/json` and
`Authorization: Bearer <resolved-token>`. The two POST operations also set
`Content-Type: application/json`:

- Search Analytics encodes the strictly decoded typed request with official
  camelCase keys and omits absent optionals.
- URL inspection encodes `inspectionUrl`, `siteUrl`, and optional
  `languageCode`; it has no caller-defined fields.

The default transport uses a dedicated session that rejects every HTTP redirect.
This preserves the fixed-origin boundary after request construction: a 307 or
308 response cannot replay a Search Analytics or URL Inspection body to a
different origin. Redirect responses are returned to the REST client as
non-success provider failures; the transport never follows them.

GET requests have no body. No operation adds a provider cursor or pagination
flag not present in the official method contract.

## Data flow and error behavior

The operation sequence is:

1. Parse route and flags into an operation-specific input.
2. Validate every scalar and securely load/strictly validate the request file.
3. Load the selected profile and enforce product/capability/exact-scope
   isolation.
4. Resolve the access token through the injected resolver.
5. Build the fixed request from typed values.
6. Execute once through the existing injected transport and validate the JSON
   response through `GoogleRESTClient`.
7. Return the successful provider JSON under the existing CLI result contract.

Local validation, configuration, credential, transport, provider, and invalid
response failures retain distinct structured error codes. Provider failures may
expose only the HTTP status and the existing allowlisted uppercase provider
status token. Transport failures use a generic message. Neither failure class
may include a request URL, response body, headers, access/refresh token, OAuth
client contents, site/feed/inspection URL containing credentials, Search
Analytics expression, or request-file contents. Although credential-bearing
URLs are rejected locally, redaction tests still use such sentinels to prove
that lower-level errors cannot echo them.

## Type and file boundaries

Implementation remains in `GoogleMarketingGatewayCore` and should use focused
files rather than expanding mixed-product files:

- `Sources/GoogleMarketingGatewayCore/SearchConsoleModels.swift` for closed
  values and strict request models;
- `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift` for
  property, URL, language-tag, dates, filters, and strict file decode;
- `Sources/GoogleMarketingGatewayCore/SearchConsoleRequests.swift` for fixed
  URLRequest construction;
- a focused Search Console CLI extension/file if needed to keep
  `GatewayCLI.swift` cohesive;
- focused matching tests under
  `Tests/GoogleMarketingGatewayCoreTests/`.

The existing `SecureLocalFiles`, credential resolver, `HTTPTransport`, and
`GoogleRESTClient` boundaries are reused where their behavior meets this
contract. Search Console must not create a second transport, token lookup path,
or generic provider adapter. Every non-generated Swift file remains below
1,000 lines.

## Deterministic verification contract

Independent tests, not fixtures derived from the request builders, cover:

- exact singleton scope acceptance for environment-token and installed OAuth
  profiles; duplicate, writer, empty, mixed, and cross-product scope rejection;
- isolation of existing product fixtures and rejection of misplaced
  product-specific fields;
- all six catalog descriptors, all six reader help spellings, dispatch of every
  route, and writer/admin rejection without mutation-catalog changes;
- exact method, scheme, host, port absence, percent-encoded path, query items,
  headers, and body for every operation;
- URL-prefix properties with paths/ports/inner percent escapes and
  `sc-domain:` properties, plus exact `%25`, `%2F`, `%3A`, and delimiter cases
  proving single-segment encoding without origin or traversal control;
- rejection of userinfo, fragments, backslashes, malformed escapes, empty DNS
  labels, invalid domain labels, invalid schemes, relative URLs, URL-prefix
  properties without a trailing slash, and oversized values;
- exact Search Analytics camelCase JSON, nil omission, row limits 1 and 25,000,
  `startRow` zero, every supported enum, AND filters, and duplicate dimension
  rejection;
- unknown and duplicate JSON keys at the root and every nested level; invalid
  UTF-8/JSON/trailing JSON; deprecated `searchType`; invalid Gregorian dates and
  reversed ranges; numeric strings/fractions/exponents/overflow; unsupported
  enums; zero/25,001 row limits; negative start rows; empty/over-limit groups;
  empty/oversized/control-bearing expressions; `hourly_all`; filter-only versus
  grouping-only dimensions; optional operator defaulting; and group/filter-count
  bounds;
- request files at exactly 1 MiB and above 1 MiB, terminal and parent symlinks,
  directories and other non-regular entries, concurrent in-place overwrite,
  truncation, growth, metadata/identity/type change, full-resolution timestamp
  comparison, and descriptor-only parsing;
- language-code omission and representative language, script, region,
  extension, and private-use tags plus malformed/oversized cases and repeated
  case-insensitive variants such as `en-1901-1901`;
- raw-space and other parser-normalization URL cases for property, sitemap, feed,
  and inspection inputs, proving rejection before credential resolution;
- direct strict-parser tests at containers 64 and 65 using a syntactically valid
  JSON root, independently of typed unknown-field decoding, plus an end-to-end
  request-file rejection at the excessive-depth boundary;
- resolver and transport spies proving zero calls for every malformed local
  input, with credential resolution occurring only after complete validation;
- provider/transport failure fixtures containing bearer tokens,
  credential-bearing URLs, query expressions, request JSON, and file-content
  sentinels, all absent from public output.

Verification performs no live OAuth or Search Console calls. The implementation
handoff must report exact results for:

```bash
mise run lint
swift test
swift build
swift run google-marketing-gateway --help
swift run google-marketing-gateway-reader --help
swift run google-marketing-gateway-reader catalog
swift run google-marketing-gateway-reader config validate --config <fixture>
git diff --check
git status --short --untracked-files=all
rg --files -uu -g '!.git' -g '!.build/**'
```

The handoff also records the exact repository secret scan, private-URL scan,
machine-local path scan, and Swift line-limit command used. The whitespace scan
must explicitly inspect untracked source/document files because this repository
has no tracked baseline; `git diff --check` alone is insufficient.

## Documentation and rollout

Implementation updates this design status, the active implementation plan,
`README.md`, `design-docs/google-marketing-gateway-design.md`, and
`impl-plans/completed/foundation-publisher-readers.md` truthfully. The operation
catalog and help are the executable evidence. Search Console is complete only
after every operation and negative boundary test passes; partial route delivery
must remain labeled incomplete.

Rollback removes the six reader descriptors/routes and Search Console profile
case together. It must not leave catalog entries that dispatch nowhere, accept
the scope without an operation, or broaden writer/admin behavior.

## Reference and intentional divergence

`<mail-gateway-checkout>` was inspected as a structural
reference. In
`Sources/MailGatewayCore/MailGatewayUtilities.swift`, `isWithinRoot` sends the
configured root and caller path through `normalizedPath` and `canonicalPath`,
which resolves existing symlink components, before applying the containment
check used by attachment and download flows. Independent traversal,
sibling-prefix, and symlink-escape expectations live in
`Tests/MailGatewayCoreTests/PathAndDownloadKeyTests.swift`. The reusable lesson
is to keep caller-selected paths behind a narrow, independently tested file
boundary; mail-gateway has no Search Console adapter or authoritative Search
Console behavior to reuse.

The request-file flow intentionally diverges from that canonical-path
containment model. Search Analytics accepts an explicit file rather than a path
under an allowlisted root, so local
`Sources/GoogleMarketingGatewayCore/SecureLocalFiles.swift` walks parent
components with descriptor-relative `openat`, `O_DIRECTORY`, and `O_NOFOLLOW`,
opens the terminal entry with `O_NOFOLLOW`, verifies the open descriptor with
`fstat`, and performs the bounded stability-checked read consumed by
`Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift`. This avoids
using pre-open canonicalization as a TOCTOU security boundary and follows the
official 2026-08-13 Search Console contracts. No codex-agent or Cursor CLI
behavior reference was supplied, so no Cursor adapter or behavior mapping is
introduced.

## Adversarial design review record

Decision: the implemented contract remains accepted, but the workflow may not
declare the slice complete until every prior high/medium finding below is
remediated and the complete non-network matrix is rerun after the final source,
test, plan, and documentation changes.

The review found and resolved these high/medium design risks:

1. **Origin confusion and traversal**: raw provider identifiers could have been
   interpreted as authority or path syntax. The accepted design validates
   identifier shape, fixes both origins, encodes only unreserved bytes literally,
   and treats each caller value as one already-encoded segment.
2. **Double encoding/decoding**: generic URL path APIs could transform inner
   percent escapes. The accepted design specifies byte-level one-pass encoding,
   already-percent-encoded path assignment, and independent literal expectations.
3. **DNS and userinfo ambiguity**: fully qualified inputs could conceal
   credentials or ambiguous host syntax. The accepted design rejects userinfo,
   fragments, backslashes, malformed escapes, and invalid domain properties;
   these URLs never become the request origin.
4. **Request-file race and resource exhaustion**: path validation before reopen
   would permit TOCTOU and unbounded reads, while identity checks alone would
   miss same-inode content changes. The accepted design uses no-follow descriptor
   opens, regular-file checks, limit-plus-one reads, pre/post identity, size,
   full-resolution modification/change-time and type comparison, strict
   duplicate-key decoding, and semantic collection bounds. Any observed change
   fails before decoding or credential access.
5. **Credential access before validation**: a generic dispatch pipeline could
   resolve OAuth before reading the query. The accepted sequence makes complete
   operation and request-file validation precede resolver and transport calls.
6. **Cross-product privilege drift**: accepting broad scope bundles or cataloging
   future mutations would weaken executable separation. The accepted design
   requires the exact singleton readonly scope and an unchanged empty
   writer/admin Search Console mutation surface.
7. **Data leakage**: provider bodies and interpolated local validation errors
   could expose expressions, URLs, or file contents. The accepted design limits
   provider output to status/category and specifies sentinel redaction tests.
8. **Mirrored-test defects**: request-builder-derived expected URLs could approve
   the same encoding error. The accepted test contract requires independently
   authored method/origin/path/body literals and hostile delimiter cases.

## Rerun remediation record

Workflow execution `codex-design-and-implement-review-loop-session-713` carries
eight unresolved medium findings from session 712. Their design-level decisions
are binding for implementation and plan review:

1. `impl-plans/completed/search-console-reader.md:261`: `TASK-002` and `TASK-003`
   may not both claim parallel ownership of
   `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleValidationTests.swift`.
   The plan must assign disjoint write scopes or serialize those tasks.
2. `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift:123`:
   repeated BCP 47 variants are rejected case-insensitively before credential
   resolution, with an independent `en-1901-1901` regression.
3. `design-docs/google-marketing-gateway-design.md:150`: main evidence must state
   that the slice is implemented while distinguishing pending remediation and
   final verification from implementation availability.
4. `impl-plans/completed/search-console-reader.md:215`: `TASK-001` baseline,
   inventory, inspection, line-count, baseline-test, and test-contract evidence
   must be completed or explicitly waived before dependent completion is
   credible.
5. `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift:46`: raw
   spaces and every other URL value that requires parser normalization are
   rejected locally before credentials or transport.
6. `Sources/GoogleMarketingGatewayCore/SearchConsoleValidation.swift:184`: the
   strict JSON verifier enforces the 64-container bound before descending beyond
   it, despite the separate 1 MiB file limit.
7. `Tests/GoogleMarketingGatewayCoreTests/SearchConsoleRequestFileTests.swift:77`:
   the nesting regression must directly isolate the 64/65 parser boundary and
   must not rely only on a typed-decoder unknown-field failure.
8. `impl-plans/completed/search-console-reader.md:702`: final evidence must execute
   the complete `TASK-009` non-network matrix after all remediation changes.

No unresolved user decision blocks implementation.

## Session 715 fresh verification record

After the final prior-remediation changes, Step 6 ran one new non-network
evidence set: focused Search Console tests (24), the full suite (69), build,
lint (60 warnings and zero serious violations), compatibility/reader/writer/admin
help, reader catalog, fixture config validation, auth smoke syntax/execution,
tracked and untracked whitespace checks, status/inventory, security/privacy
scans, and Swift line limits. The command runner timed out only after completion
output for SwiftPM and lint commands; the completed command output showed success.
No live OAuth/provider call, commit, or push occurred. Step 7 independent
adversarial review remains the completion gate.
