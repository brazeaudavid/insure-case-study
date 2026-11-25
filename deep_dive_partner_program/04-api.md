# 04 · APIs

## 1. Two surfaces, one standard, one codebase

| Surface | Audience | Auth | Stability |
|---|---|---|---|
| External `/v1` | Partner backends, partner-built UIs (through their backend) | Cognito client credentials, one app client per partner per environment | Versioned. Breaking changes need a new major version. |
| Internal `/internal/v1` | Ops interface, underwriting UI, internal services, rater CI | Staff SSO federated through Cognito; IAM or service tokens for CI and jobs | Evolves with our UIs, still linted and contract-tested |

Both are thin adapters over one Django service layer, so business rules exist once. They run as separate process groups from the same image, so partner traffic can't starve the internal UIs. Both sit behind Amazon API Gateway (07 §2).

Rejected: one API for everyone, because internal fields and actions would leak into the partner contract. Also rejected: a separate partner service, because it would duplicate validation, which is the double-entry problem again.

## 2. The standard

| Concern | Rule |
|---|---|
| Contract | OpenAPI 3.1, contract-first. CI runs Spectral lint, an `oasdiff` breaking-change check, and contract tests of implementation against spec. |
| Style | REST, plural nouns, `snake_case` fields |
| IDs | Opaque, prefixed public IDs. Never DB PKs. Other partners' resources return 404. |
| Errors | RFC 9457 `application/problem+json` with `errors[]` of `{pointer, code, message}`. All errors in one response. |
| Validation | External rejects unknown fields |
| Pagination | Cursor (`limit`, `cursor`, `next_cursor`) |
| Concurrency | `ETag` on every mutable resource; `If-Match` required on PATCH and state transitions; 412 on conflict |
| Idempotency | `Idempotency-Key` on creates and transitions; same key and body returns the stored response; different body returns 409; kept 24h |
| State changes | Action endpoints (`/submit`, `/publish`), never PATCH a status |
| Long work | 202 plus an operation resource (backtests) |
| Money | `{"amount": "8000.00", "currency": "USD"}`, decimal strings |
| Correlation | `X-Request-Id` in and out; in every error |
| Rate limits | 429 with `Retry-After` |

## 3. The application schema

```
GET /v1/programs/{program_id}/application-schema            → redirects to the version in effect
GET /v1/program-versions/{version_id}/application-schema    → immutable, long-cacheable
GET /v1/programs/{program_id}/versions?effective_after=…     → upcoming versions, for planned changes
```

It returns plain JSON Schema built from the resolved question set:

```json
{
  "$id": "https://api.insurenext.example/v1/program-versions/prv_01J…/application-schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["annual_revenue", "num_employees"],
  "properties": {
    "annual_revenue": { "type": "string", "format": "decimal", "title": "Annual revenue (USD)", "description": "Last fiscal year" },
    "num_employees":  { "type": "integer", "minimum": 1, "title": "How many staff do you employ?" },
    "serves_alcohol": { "type": "boolean", "title": "Do you serve alcohol?" },
    "liquor_sales_pct": { "type": "integer", "minimum": 0, "maximum": 100, "title": "Share of revenue from alcohol (%)" }
  },
  "allOf": [ { "if": { "properties": { "serves_alcohol": { "const": true } } },
               "then": { "required": ["liquor_sales_pct"] } } ]
}
```

- Preset questions don't appear. The partner never sends them, and Django writes them.
- Enums use `oneOf` with `const` (the code) and `title` (the label).
- No layout hints. Title and description already cover what the user reads. Sections and order are our UI's concern, served only on the internal form endpoint.
- The same compiled validator, cached per version id, checks every write on both surfaces. There's one definition of valid.

### Why this isn't restrictive

| Level | Who decides | How |
|---|---|---|
| What gets asked | Partner and us, configured by Ops | Their partner program: omit, preset, relabel, add questions; rating and discounts |
| How it's asked | The partner, entirely | Their screens, order, steps, branding, pre-fill from their own systems |

What partners can't do is invent keys or values. That's the junk-data fix at the source: partners map their data to our codes once, against the sandbox, and every write after that is checked against the same schema we use.

## 4. Not breaking partner integrations

Two contracts, each with its own guard:

1. **API contract** (`/v1` endpoints, fields, statuses): `oasdiff` blocks breaking changes in CI. Partners see a stable, simplified projection of internal statuses (`draft`, `submitted`, `quoted`, `declined`, `referred`). Clients must ignore unknown response fields, so additive changes are safe. Deprecations use `Deprecation` and `Sunset` headers with a support window (Q-12).
2. **Program schema** (the questions): applications stay pinned to their version, so in-flight work never breaks. At publish, the new resolved schema is compared with the live one:

| Change | Class | Rule |
|---|---|---|
| New optional question, label or help text change, new show-if branch that only adds optional questions | Non-breaking | Publish normally |
| New required question, removed question, removed or renamed option, type change, tighter range | Breaking | `effective_from` ≥ now + the partner's notice period, available in sandbox immediately, partner notified, partner manager acknowledges |

A base program change only reaches a partner's schema through a published partner version (a rebase), which goes through the same comparison.

## 5. External resources

| Method and path | Purpose |
|---|---|
| `GET /v1/programs` | Programs this client may sell |
| `GET /v1/programs/{id}/application-schema` | Data contract (§3) |
| `POST /v1/applications` | Create a draft (program, company, coverages, `external_ref`); returns `requirements[]` |
| `GET /v1/applications` | List own applications (cursor, status, external_ref) |
| `GET /v1/applications/{id}` | Application, answers, `requirements[]`, status |
| `PATCH /v1/applications/{id}` | Save answers and coverages while draft; each answer stored once and updated in place |
| `POST /v1/applications/{id}/validate` | Full check without submitting |
| `POST /v1/applications/{id}/submit` | No body. Completeness check, then rating. |
| `GET /v1/applications/{id}/quote` | `pending`, `quoted`, `declined`, `referred`, `needs_attention`; premium per coverage |

No data is ever posted twice. Answers are saved progressively, submit carries no data, retries are idempotent, and `external_ref` stops duplicate applications. Company details live on the company, not repeated as questions.

Webhooks (designed, not built): `application.quoted`, `application.declined`, `application.status_changed`, HMAC-signed with retries. Until then, partners poll the quote.

## 6. Internal resources

| Area | Endpoints |
|---|---|
| Partners | `/partners`, `/partners/{id}/api-clients` (secret shown once, rotate, revoke) |
| Question definitions | `GET /rating-engine-versions/{id}/questions`; `POST …/questions` (new underwriting or informational definition; insert only, no update once referenced) |
| Programs | `/programs`, `/programs/{id}/versions`, `/program-versions/{id}` (GET; PATCH draft with `If-Match`) |
| Version workflow | `/program-versions/{id}/validate`, `/backtests`, `/submit-for-review`, `/approve`, `/reject`, `/publish`; `POST /programs/{id}/versions?restore_from={vid}`; `GET /program-versions/{id}/diff?against={vid}` |
| Rebase | `GET /programs?behind_base=true`; `POST /program-versions/{base_id}/rebase-drafts` |
| Form preview | `GET /program-versions/{id}/form` (works on drafts, includes sections and order) |
| Raters | `POST /rating-engine-versions` (CI registers version, endpoint, manifest, code_ref); `GET …/manifest`; `GET /program-versions?live=true&rater={id}` (CI compatibility report) |
| Applications | Full view; `/applications/{id}/discounts`; `POST /applications/{id}/rate`; `/applications/{id}/rating-runs` |
| What-if | `POST /rating/preview` (program version or draft plus answers gives premiums; never persisted to a coverage) |
| Test cases | `/rating-test-cases` CRUD |

## 7. Auth

| Principal | Mechanism | Authorization |
|---|---|---|
| Partner backend | Cognito client credentials, token validated at the gateway, claims re-checked in Django | Scopes, plus partner tenancy enforced in one query path in the service layer |
| Staff | SSO through Cognito (OIDC, PKCE) | Roles: `underwriter`, `config_author`, `approver`, `data_scientist`, `partner_manager`, `admin`, `read_only` |
| Rater CI | IAM-authenticated service role | Register rater versions, read live programs |

Partner secrets never go in a browser. Partner UIs call their own backend, which calls us. Partners must cache tokens until expiry, because Cognito bills per machine-to-machine token request.
