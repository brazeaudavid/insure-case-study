# 0005 · Partner programs pinned to a base version, with automatic rebase drafts

**Status:** Accepted (business confirmation Q-17)

## Context
Live inheritance would let a base change silently reprice partners. Manual upgrades would make yearly base increases busywork.

## Decision
Partner versions pin `base_program_version_id`. When a base version is approved, rebase drafts are created for every partner program on the old base, with partner overrides carried over and conflicts flagged, then validated and backtested. `follow_base` programs publish with the base. `manual` programs go to the partner manager.

## Consequences
- + Nobody is repriced without a published version; base increases still reach every intended program in one approval.
- − More versions and approvals per base change, mostly automated.
