# Partner Programs: Deep Dive

Private prep material behind `../partner-programs-design.md`. The submission doc is the short version. This folder has the detail I'd want in hand for the live review.

The approach throughout is **expand what's there**: Django and Postgres stay the system of record, the existing rater Lambdas stay the rating engine, and the schema changes are additive, plus one deliberate refactor (questions stop belonging to a rater version). Existing services get refactored where the design needs it. Nothing is rebuilt.

## Files

| File | What it covers |
|---|---|
| `01-requirements.md` | What the case study says, what I observed in the current model, and each stakeholder pain point mapped to the design |
| `02-design.md` | Programs, questions, presets, rating config, modules, discounts, base rebase, and the questions I expect in the live review |
| `03-data-model.md` | Every table: PKs, FKs, constraints, indexes, relationships, version history mechanics, migration |
| `04-api.md` | API standard, external and internal surfaces, the application schema contract, schema compatibility policy, auth |
| `05-workflows-and-safety.md` | The change workflows (Ops and Data Science), backtest, impact thresholds, the validation chain, failure modes |
| `06-observability.md` | Logging schema, metrics, alarms, log lake, dashboards |
| `07-infrastructure.md` | Stack, API Gateway, region and DR, data residency |
| `08-rollout.md` | Phases, exit criteria, rough effort |
| `09-risks-and-open-questions.md` | Risks (R-xx) and questions I'd ask stakeholders (Q-xx) |
| `adr/` | Architecture decision records 0001–0010 |
| `diagrams/` | Diagram sources (D2, Mermaid) with rendered SVGs; see `diagrams/README.md` |

## The design in one paragraph

Add partners and programs. Each program has numbered versions with Confluence-style history: one autosaved draft, publish creates the next version, any two versions can be diffed, and any old version can be restored as a new draft. A version selects its questions as rows with real foreign keys. Question definitions stay scoped to the rater version and are never edited once used, while the wording lives on the program version. It also carries a small JSON config for rate-table overrides, modules and discounts. A partner program stores only its differences from the base program version it's pinned to. The rater is refactored once: it declares its inputs in code (which generates a manifest), reads overrides from the payload, and has a module registry instead of partner `if` branches. Every check from rater build to rater call validates against that manifest, so missing or junk data is stopped before rating. Partners integrate through an external API that publishes each program's JSON Schema data contract. Every rating stores its exact request in `rating_run`, so it can be replayed, and those replays drive automated backtests for every change.
