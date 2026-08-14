# Foundation and publisher readers

Status: complete for the bounded foundation and currently planned reader slices

## Delivered

- Shared `GoogleMarketingGatewayCore` target.
- Capability-separated reader, writer, and admin executables.
- Machine-readable operation/scope catalog.
- Typed AdSense `accounts.list` and `payments.list` requests.
- Typed AdMob `accounts.list` request.
- Product-isolated reader credential profiles with exact scope declarations,
  environment-only token lookup, validation, status, and `--profile` selection.
- Typed AdSense ad client, ad unit, site, policy-issue, and report readers.
- Typed AdMob app, ad-unit, network-report, and mediation-report readers.
- Official AdSense report query encoding and AdMob `reportSpec` POST-body
  encoding with deterministic request and CLI coverage.
- Injected HTTP transport, fixed Google origins, environment-only bearer token,
  sanitized provider errors, and deterministic tests.
- Google Trends is cataloged as official alpha with allowlist access; no scraping
  or unofficial endpoint is implemented.
- Installed desktop OAuth, Google Ads v25, and Analytics Data v1beta are
  implemented, adversarially reviewed, and verified without live provider calls.
  The unavailable historical pre-edit snapshot is explicitly waived; the
  complete current untracked inventory is the authoritative closure evidence.
- Search Console reader slice: six fixed-origin read/inspection operations,
  exact readonly profile scope, bounded strict Search Analytics request files,
  and reader-only catalog/help exposure are implemented, adversarially reviewed,
  and covered by fresh non-network verification.

## Future roadmap (not active tasks)

1. Create separate accepted designs and implementation plans before adding
   Merchant, YouTube, Analytics Admin, or Tag Manager readers.
2. Review individual mutations before enabling any writer/admin operation.
