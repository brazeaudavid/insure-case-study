# 0001 · Programs as versioned records with Confluence-style history

**Status:** Accepted

## Context
Partners need programs whose questions, rating and discounts can be customized in any combination. Premiums must be explainable later, and Ops need to see, compare and undo changes.

## Decision
`partner` → `program` → `program_version`. Every application stores its program version, and direct business runs under a base program. Each program has one open draft. Publish assigns the next version number and an effective window. Any two versions can be diffed, and restoring a version creates a new draft from it. Published versions are immutable (service layer, DB trigger, exclusion constraint, content hash).

## Consequences
- + Reproducible pricing, full audit trail, trivial rollback, cacheable by id.
- − Every change, however small, is a new version that goes through review.
