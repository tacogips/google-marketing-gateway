# Divedra Implementation Workflow

Use this repository-facing workflow contract when a Divedra or Riela
issue-resolution run asks for implementation, review, documentation refresh, or
commit preparation in `google-marketing-gateway`.

## Workflow Modes

- `issue-resolution`: full issue work may update design docs, implementation
  plans, Swift implementation, tests, user-facing docs, and commit metadata.
- Non-`issue-resolution` modes must not silently expand scope into full issue
  implementation.

Step 8 documentation refresh runs only after Step 7 implementation review has
accepted the slice with `needs_revision: false`.

## Documentation Refresh Contract

For Step 8:

- Read the accepted design, implementation plan, implementation review output,
  and current repository diff together.
- Update user-facing documentation only for shipped behavior and accepted
  workflow contracts.
- Always review `README.md` and this file.
- Update other repository-facing workflow skills or README sections only when
  the accepted implementation directly affects them.
- Do not reopen design or implementation scope.
- Keep issue references, workflow mode, review decisions, verification
  commands, and deferred work explicit.

## Current Accepted Slice

Workflow mode: `issue-resolution`

Issue reference:
`google-marketing-gateway: Cover the complete official Google advertising and agency account operations surface`

Accepted implementation behavior:

- Google Ads API v25 reader routes for
  `google-ads.customer-client-links.list`,
  `google-ads.customer-clients.list`, and
  `google-ads.customer-users.list`.
- Provider-generated GAQL request builders over the official fixed
  `https://googleads.googleapis.com` origin.
- Implemented-only dispatch lookup through `OperationCatalog.operation(id:)`.
- Expanded operation descriptor metadata for official API family, version,
  stability, origin, provider method, request kind, spend risk, request body
  policy, response policy, and verification status.
- Catalog-only planned inventory for broader official Google advertising,
  analytics, publisher, commerce, content, and local surfaces.
- Fixed-origin descriptor validation.
- Writer/admin mutation allowlists remain empty.

Deferred work remains non-blocking unless a later accepted plan changes scope:

- Descriptor-bounded generic REST dispatch.
- Reusable request-file helpers.
- Expanded sanitizer fixtures.
- Writer/admin profile schema.
- Mutation plan model.

Accepted verification commands:

```bash
swift test --filter OperationCatalogTests
swift test --filter NewReaderRequestTests
swift test --filter NewReaderCLITests
swift test --filter GatewayCLITests
swift test --filter CredentialProfileTests
mise run lint
mise run test
mise run build
git diff --check
git status --short
```

No live billable Google action was performed. No unofficial scraping endpoint
was added. No codex-agent references were introduced.
