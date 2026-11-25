# 0004 · Rating and discount customizations as a JSON config; modules instead of partner branches

**Status:** Accepted

## Context
Partner customizations are if/else branches in the rater. Ops want simple rate changes without engineering.

## Decision
`program_version.config` holds `rating` (table overrides, modules) and `discounts`, validated against the pinned manifest. Our Django service layer combines rater defaults, base config and partner config (tables by row, modules by name, discounts by code) and sends the result in the payload. Modules are named functions in the rater code, run in-process by the rater's entry point at fixed hooks, that config can switch on with parameters. No code travels in config, and modules aren't separate Lambdas, so a rater version stays one immutable, replayable artifact.

## Consequences
- + New partner programs are mostly config; the code never checks who's asking; payloads are self-contained and replayable.
- − No FKs inside the JSON, which publish validation makes up for. Module code grows and needs review.
