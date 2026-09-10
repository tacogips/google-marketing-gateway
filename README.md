# google-marketing-gateway

An access token in the profile's `accessTokenEnvironmentVariable` overrides its
OAuth token file. Login reports the written file and the exact variable to unset
before subsequent commands can use that grant. Auth status follows the same
precedence as requests, and credential errors identify the selected source without
printing token values. Selecting an explicit config does not disable token overrides.

A Swift 6 command-line gateway for official Google marketing APIs. The package
uses a shared core and capability-separated executables modeled on
`mail-gateway`:

- `google-marketing-gateway-reader`
- `google-marketing-gateway-writer`
- `google-marketing-gateway-deleter`
- `google-marketing-gateway-admin`

The legacy `google-marketing-gateway` executable currently delegates to the
reader and prints a deprecation notice so existing Homebrew and CI automation
continues to work during the packaging migration.

## Current implementation

The publisher-reader foundation provides typed REST requests for:

- Google Ads API v25 accessible customers and GAQL search
- Google Ads API v25 generated agency reads for customer-client links,
  customer-client hierarchy rows, and customer user access rows
- Analytics Data v1beta metadata, `runReport`, and `checkCompatibility`
- AdSense v2 `accounts.list`
- AdSense v2 `accounts.payments.list`
- AdSense v2 ad client, ad unit, site, and policy-issue lists
- AdSense v2 ad hoc report generation (`GET` with official query fields)
- AdMob v1 `accounts.list`
- AdMob v1 app and ad-unit lists
- AdMob v1 network and mediation report generation (`POST` with an official
  `reportSpec` JSON body)
- Search Console Sites, Search Analytics, sitemap reads, and URL Inspection
  through its fixed official Webmasters v3 and URL Inspection v1 origins

The writer exposes a zero-network preview for the Native-only AdMob v1beta
`accounts.adUnits.create` request through `admob adunits create-native plan`.
It validates the exact `https://www.googleapis.com/auth/admob.monetization`
writer profile and constructs the narrowly typed request, but live apply stays
fail-closed until the reviewed durable anti-replay state is implemented. The
API has limited access and may return 403 without entitlement. Update and
delete are unavailable because the public API does not expose them.

Google Ads Search campaign creation is available in the writer through a typed,
atomic `GoogleAdsService.Mutate` request. Google Ads removal is isolated in the
deleter executable: reader, writer, and admin cannot emit provider `remove`
operations. Google Ads removal changes the resource status to `REMOVED`; the
provider does not expose a stronger physical-erasure operation. Google Trends is represented in the catalog as an official alpha API
requiring allowlist access; this project does not scrape `trends.google.com` or
use unofficial endpoints.

The operation catalog now includes richer descriptor metadata for official API
family, version, stability, fixed origin, provider method, request kind,
spend-risk classification, request-body policy, response policy, and
verification status. It also includes catalog-only planned inventory for Google
Marketing Platform, Google Ad Manager, Merchant Center, Analytics Admin,
Tag Manager, YouTube, Ads Data Hub, Authorized Buyers/RTB, Business Profile,
Local Services Ads, and excluded unofficial Trends scraping. Planned,
restricted, beta, deprecated, allowlisted, and excluded rows are documentation
inventory only; CLI dispatch is limited to implemented operations.

Inspect the current inventory and required OAuth scopes:

```bash
swift run google-marketing-gateway-reader catalog
```

### AdMob Native ad-unit creation

Use a product-isolated writer profile with only the monetization scope. The
plan command validates locally and does not contact Google:

```bash
ADMOB_WRITER_PLAN_TEST_TOKEN=fixture-token-not-a-secret \
swift run google-marketing-gateway-writer admob adunits create-native plan \
  --account accounts/pub-9876543210987654 \
  --app-id ca-app-pub-9876543210987654~0123456789 \
  --display-name "Local verification only" \
  --ad-types RICH_MEDIA,VIDEO \
  --profile fixture-admob-writer \
  --config Tests/GoogleMarketingGatewayCoreTests/Fixtures/admob-writer-plan.json
```

The preview deliberately emits no reusable plan token and cannot be applied.
Native layout, rendering, AdChoices, click and impression handling, and SDK
test-ad behavior remain mobile-app concerns.

### Google Ads Search campaign creation and removal

Use separate Google Ads writer and deleter profiles even though Google exposes
the same OAuth scope for both. Binary routing, profile capability, typed request
builders, and catalog descriptors enforce the separation:

```json
{
  "profiles": [
    {
      "id": "google-ads-writer",
      "product": "google-ads",
      "capability": "writer",
      "oauthScopes": ["https://www.googleapis.com/auth/adwords"],
      "accessTokenEnvironmentVariable": "GOOGLE_ADS_ACCESS_TOKEN",
      "developerTokenEnvironmentVariable": "GOOGLE_ADS_DEVELOPER_TOKEN",
      "loginCustomerIdEnvironmentVariable": "GOOGLE_ADS_LOGIN_CUSTOMER_ID"
    },
    {
      "id": "google-ads-deleter",
      "product": "google-ads",
      "capability": "deleter",
      "oauthScopes": ["https://www.googleapis.com/auth/adwords"],
      "accessTokenEnvironmentVariable": "GOOGLE_ADS_ACCESS_TOKEN",
      "developerTokenEnvironmentVariable": "GOOGLE_ADS_DEVELOPER_TOKEN",
      "loginCustomerIdEnvironmentVariable": "GOOGLE_ADS_LOGIN_CUSTOMER_ID"
    }
  ]
}
```

The campaign request file includes every resource required for an enabled
Search campaign. Budget and CPC inputs are micros and are capped at 500,000,000:

```json
{
  "customerId": "0987654321",
  "campaignName": "Gateway verification",
  "dailyBudgetMicros": 1000000,
  "adGroupName": "Gateway verification",
  "cpcBidMicros": 250000,
  "geoTargetConstantId": "2392",
  "languageConstantId": "1005",
  "keywords": [{"text": "swift marketing gateway", "matchType": "EXACT"}],
  "headlines": ["Swift Marketing Gateway", "Typed Google Ads Control", "Safe Campaign Operations"],
  "descriptions": ["Manage Google marketing operations with a typed Swift command line tool.", "Separate reading, writing, and removal with explicit capabilities."],
  "finalUrls": ["https://example.com/google-marketing-gateway"]
}
```

Plan is local and zero-network. Validate sends the same request with
`validateOnly`. Apply creates the enabled budget, campaign, location/language
criteria, ad group, keywords, and responsive Search ad atomically:

```bash
swift run google-marketing-gateway-writer google-ads search-campaigns create plan \
  --request-file campaign.json --profile google-ads-writer --config profiles.json

kinko exec --env GOOGLE_ADS_ACCESS_TOKEN,GOOGLE_ADS_DEVELOPER_TOKEN -- \
  swift run google-marketing-gateway-writer google-ads search-campaigns create validate \
  --request-file campaign.json --profile google-ads-writer --config profiles.json

kinko exec --env GOOGLE_ADS_ACCESS_TOKEN,GOOGLE_ADS_DEVELOPER_TOKEN -- \
  swift run google-marketing-gateway-writer google-ads search-campaigns create apply \
  --request-file campaign.json --profile google-ads-writer --config profiles.json \
  --confirm-customer-id 0987654321
```

Removal has the same plan/validate/apply stages and requires the full target
resource name as apply confirmation:

```bash
kinko exec --env GOOGLE_ADS_ACCESS_TOKEN,GOOGLE_ADS_DEVELOPER_TOKEN -- \
  swift run google-marketing-gateway-deleter google-ads campaigns remove apply \
  --customer-id 0987654321 \
  --resource-name customers/0987654321/campaigns/456789 \
  --confirm-resource-name customers/0987654321/campaigns/456789 \
  --profile google-ads-deleter --config profiles.json
```

The deleter supports campaigns, campaign budgets, campaign criteria, ad groups,
ad group criteria, and ad group ads. Create and update operations are rejected
by the deleter before credentials are read.

Create a JSON config containing product-isolated reader profiles. Config stores
only environment-variable names, never token values:

```json
{
  "profiles": [
    {
      "id": "adsense-reader",
      "product": "adsense",
      "capability": "reader",
      "oauthScopes": ["https://www.googleapis.com/auth/adsense.readonly"],
      "accessTokenEnvironmentVariable": "ADSENSE_ACCESS_TOKEN"
    },
    {
      "id": "admob-reader",
      "product": "admob",
      "capability": "reader",
      "oauthScopes": [
        "https://www.googleapis.com/auth/admob.readonly",
        "https://www.googleapis.com/auth/admob.report"
      ],
      "accessTokenEnvironmentVariable": "ADMOB_ACCESS_TOKEN"
    }
  ]
}
```

Validate config and inspect token availability without printing token values:

```bash
swift run google-marketing-gateway-reader config validate --config profiles.json
swift run google-marketing-gateway-reader config status --config profiles.json
```

Select exactly one profile for every reader operation. Supply its short-lived
access token only through the configured environment variable:

```bash
ADSENSE_ACCESS_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader adsense adclients list \
  --account accounts/pub-123 --profile adsense-reader --config profiles.json

ADSENSE_ACCESS_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader adsense reports generate \
  --account accounts/pub-123 --start-date 2026-08-01 --end-date 2026-08-07 \
  --dimensions DATE --metrics CLICKS,ESTIMATED_EARNINGS \
  --profile adsense-reader --config profiles.json

ADMOB_ACCESS_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader admob network-report generate \
  --account accounts/pub-123 --start-date 2026-08-01 --end-date 2026-08-07 \
  --dimensions DATE,APP --metrics CLICKS,ESTIMATED_EARNINGS \
  --profile admob-reader --config profiles.json
```

The CLI never accepts access tokens as command arguments and sanitizes provider
errors before printing them. `GOOGLE_MARKETING_GATEWAY_CONFIG` can provide the
config path instead of `--config`.

Google Ads v25 profiles also declare a `developerTokenEnvironmentVariable` and
may declare a `loginCustomerIdEnvironmentVariable`. Both fields contain only
environment-variable names; the resolved values remain solely in the process
environment. Use a manager-routed profile with
`loginCustomerIdEnvironmentVariable` only when the client is linked below that
manager. For a directly accessible, unlinked client, use a separate profile
that omits `loginCustomerIdEnvironmentVariable`; Google otherwise returns
`USER_PERMISSION_DENIED`. The checked-in `profiles.json` provides
`google-ads-direct-reader`, `google-ads-direct-writer`, and
`google-ads-direct-deleter` for that case. The reader supports
`google-ads accessible-customers list` and
`google-ads search --customer-id <digits> --query-file <path>`. It also
supports generated agency reads:

```bash
GOOGLE_ADS_ACCESS_TOKEN='<redacted>' GOOGLE_ADS_DEVELOPER_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader google-ads customer-client-links list \
  --customer-id 1234567890 --profile google-ads-reader --config profiles.json

GOOGLE_ADS_ACCESS_TOKEN='<redacted>' GOOGLE_ADS_DEVELOPER_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader google-ads customer-clients list \
  --customer-id 1234567890 --page-token next-page \
  --profile google-ads-reader --config profiles.json

GOOGLE_ADS_ACCESS_TOKEN='<redacted>' GOOGLE_ADS_DEVELOPER_TOKEN='<redacted>' \
  swift run google-marketing-gateway-reader google-ads customer-users list \
  --customer-id 1234567890 --profile google-ads-reader --config profiles.json
```

These agency reads use provider-generated GAQL over the official Google Ads
`googleAds:search` method. Callers provide only the operating customer ID and
optional page token; they cannot alter the GAQL, origin, headers, developer
token, or login customer ID.

Keyword ideas are a typed reader operation. The local request file accepts one
to ten geo targets, a language, up to twenty seed phrases, an optional HTTPS
URL, and a response page size capped at 1,000:

```json
{
  "customerId": "9708882574",
  "languageConstantId": "1005",
  "geoTargetConstantIds": ["2392"],
  "keywords": ["画面翻訳", "OCR 翻訳"],
  "url": "https://konjac-note.com/",
  "pageSize": 100
}
```

```bash
kinko exec --env GOOGLE_ADS_ACCESS_TOKEN,GOOGLE_ADS_DEVELOPER_TOKEN,GOOGLE_ADS_LOGIN_CUSTOMER_ID -- \
  swift run google-marketing-gateway-reader google-ads keyword-ideas generate \
  --request-file keyword-ideas.json --profile google-ads-reader --config profiles.json
```

Client-account creation is isolated in the admin executable and uses
`CustomerService.CreateCustomerClient`. Plan performs no network request;
apply requires the exact manager ID. Google does not provide `validateOnly` for
this method. Currency and time zone are fixed when the account is created.

```json
{
  "managerCustomerId": "3827004490",
  "descriptiveName": "Konjac Note API Client",
  "currencyCode": "JPY",
  "timeZone": "Asia/Tokyo"
}
```

```bash
swift run google-marketing-gateway-admin google-ads client-accounts create plan \
  --request-file client-account.json --profile google-ads-admin --config profiles.json

kinko exec --env GOOGLE_ADS_ACCESS_TOKEN,GOOGLE_ADS_DEVELOPER_TOKEN,GOOGLE_ADS_LOGIN_CUSTOMER_ID -- \
  swift run google-marketing-gateway-admin google-ads client-accounts create apply \
  --request-file client-account.json --profile google-ads-admin --config profiles.json \
  --confirm-manager-customer-id 3827004490
```

Google currently limits API account creation to eligible advertisers with more
than USD 1,000 in spend and good policy standing. Basic Access approval is also
needed for this production manager workflow.

Analytics Data v1beta supports metadata, `runReport`, and
`checkCompatibility` with the
`https://www.googleapis.com/auth/analytics.readonly` scope. Installed OAuth
profiles declare only `oauthClientJSONPath` and `tokenStorePath`; never place
client JSON, tokens, refresh tokens, or developer-token values in config.

Installed desktop OAuth uses a Google `installed` client JSON file, PKCE S256,
and a random IPv4 loopback callback. Relative profile paths resolve from the
config file directory. Login, status, and logout select the same profile and
never print credential material:

```bash
swift run google-marketing-gateway-reader auth login --profile analytics-reader --config profiles.json \
  --no-browser --timeout-seconds 300
swift run google-marketing-gateway-reader auth status --profile analytics-reader --config profiles.json
swift run google-marketing-gateway-reader auth logout --profile analytics-reader --config profiles.json
```

The optional `--redirect-uri http://127.0.0.1:<port>/<path>` login flag is for
bounded manual or deterministic test callbacks. Environment access tokens take
precedence over a token store. Stored OAuth tokens are private, profile-bound,
versioned JSON; near-expiry tokens refresh with a 60-second leeway.

Google Ads requests are pinned to v25: accessible customers uses
`GET /v25/customers:listAccessibleCustomers` and GAQL search uses
`POST /v25/customers/<id>/googleAds:search`. The generated agency reads use the
same fixed v25 origin and method with gateway-authored queries for
`customer_client_link`, `customer_client`, and `customer_user_access`.
Analytics Data is pinned to v1beta: metadata is `GET`, while `runReport` and
`checkCompatibility` are `POST` to the fixed `analyticsdata.googleapis.com`
origin.

Search Console reader profiles use exactly
`https://www.googleapis.com/auth/webmasters.readonly`. The reader provides
`search-console sites list|get`, `search-console search-analytics query`,
`search-console sitemaps list|get`, and `search-console url-inspection inspect`.
Search Analytics accepts its complete query only through `--request-file`: it
must be a regular, non-symlinked UTF-8 JSON file of at most 1 MiB with only the
documented camelCase request fields. The reader accepts URL-prefix and
`sc-domain:` properties, but always encodes them as single fixed-origin API path
segments. Sitemap submission/deletion and site association changes remain
unavailable.

## Development

```bash
mise install
mise run build
mise run test
mise run lint
swift run google-marketing-gateway-reader --help
```

See [the gateway design](design-docs/google-marketing-gateway-design.md) for the
Google Ads, Analytics, Merchant, Search Console, YouTube, Tag Manager, AdSense,
AdMob, and Trends inventory. See the Google Ads agency design and
implementation plan at [design-docs/google-ads-agency-operations.md](design-docs/google-ads-agency-operations.md)
and [impl-plans/google-ads-agency-operations.md](impl-plans/google-ads-agency-operations.md)
for the current issue-resolution slice, accepted verification commands, and
deferred writer/admin work.

## Homebrew

The existing Formula and Cask automation still packages the compatibility
executable. A later packaging slice will install all three capability binaries.
See `packaging/homebrew/README.md` for the current release workflow.
