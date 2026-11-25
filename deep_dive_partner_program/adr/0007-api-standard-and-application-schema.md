# 0007 · One API standard, two surfaces, and a per-program data contract

**Status:** Accepted

## Context
Partners need robust integrations, past partners sent junk data, and our internal needs must not leak into the partner contract.

## Decision
OpenAPI 3.1 contract-first standard (RFC 9457 errors, cursor pagination, ETag/If-Match, idempotency keys, public IDs, decimal money). External `/v1` and internal `/internal/v1` as thin adapters over one Django service layer. Each program version publishes a plain JSON Schema (no layout hints) that partners integrate against and that every write is validated with. Schema changes are classified at publish, and breaking ones require a notice period.

## Consequences
- + One definition of valid data; partners own their UX; integrations don't break without notice.
- − Two specs to maintain; publish needs the compatibility check.
