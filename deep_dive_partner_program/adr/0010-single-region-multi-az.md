# 0010 · Single US region, multi-AZ, cross-region backups

**Status:** Accepted (conditional on Q-15, Q-16)

## Context
No US data-localization requirement was found, and availability targets are unknown.

## Decision
All data in US regions. Primary region multi-AZ; backups and rater artifacts copied to a second US region; rebuild from IaC; annual DR test.

## Consequences
- + Low cost and complexity.
- − A regional outage means hours to recover.
