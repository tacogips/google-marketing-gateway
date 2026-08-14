# google-marketing-gateway

A Swift 6 command-line gateway for official Google marketing APIs. The package
uses a shared core and capability-separated executables modeled on
`mail-gateway`:

- `google-marketing-gateway-reader`
- `google-marketing-gateway-writer`
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

Writer and admin mutation allowlists intentionally remain empty until each
operation receives an operation-specific scope, concurrency, and recovery
review. Google Trends is represented in the catalog as an official alpha API
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
may declare a hyphen-free `loginCustomerId`; their values remain solely in the
environment. The reader supports `google-ads accessible-customers list` and
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
