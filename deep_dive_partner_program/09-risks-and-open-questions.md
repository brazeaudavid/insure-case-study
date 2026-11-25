# 09 · Risks and Open Questions

## Risks

| ID | Risk | Why it bites | Handling |
|---|---|---|---|
| R-01 | Regulation | If products are admitted, rates, rules and often discounts must be filed. Ops rate changes, partner discounts and price experiments may need filings. | `filing_ref` and approved effective date on publish; price A/B tests out of v1; confirm first (Q-01) |
| R-02 | Rater code resists overrides | If factors are inlined rather than in tables, they must be extracted first | Extraction under the parity rule; effort depends on Q-05 |
| R-03 | Discount math | The sample doesn't reconcile (12.3% vs 35% added or 32.5% compounded) | Don't port discount logic until DS confirm the rule (Q-03) |
| R-04 | Existing hardcoded partner branches | The rater only sees the payload, never API credentials, so today's branches key on something in it: an answer value, a company name, a discount key, or a dedicated rater version. Deleting them carelessly reprices those partners. | Inventory from the rater code (Q-06); convert one at a time with parity proof (phase 3b). New traffic is identified by credentials → api_client → partner → program. |
| R-05 | Valid but wrong change | A value within limits can still be a mistake | Impact thresholds and a DS approver, test cases for segments without history, drift alarm, restore (05 §2.3) |
| R-06 | Partner schema changes break integrations | A new required question breaks a partner that hardcoded fields | Pinned applications; compatibility classes; notice period; sandbox first (04 §4) |
| R-07 | Omitting a question starves the rater | The case study's own restaurant example | Presets plus the publish coverage check (02 §3) |
| R-08 | Base change reprices partners silently | If partners inherited the base live | Pinned base with rebase drafts (02 §8) |
| R-09 | "Immutable" rater changes underneath us | `$LATEST` or a moved alias changes the code behind a version | Numbered Lambda versions only, validated at registration |
| R-10 | Rater calls external services | Breaks determinism and replay | Fetch in Django before rating and pass as inputs (Q-05) |
| R-11 | Money in floating point | Rounding breaks parity checks | Decimal strings in new fields, `numeric` in Postgres (Q-11) |
| R-12 | Effective-date data quality | Overlapping `effective_date` rows fail the exclusion constraint | Inspect before phase 1 |
| R-13 | Partner data leak | One missing filter exposes another partner's applications | One scoped query path, per-endpoint cross-partner tests, 404 for others' resources |
| R-14 | PII in logs or replay sets | Answers may contain personal data | No answer values in logs; replay sets access-controlled (Q-18) |
| R-15 | Low partner submissions aren't technical | The PM gives no root cause | Funnel metrics and the silent-partner alarm make it visible (Q-09) |
| R-16 | Untyped legacy answers | `answer_text` history may be "1M", "$1,000,000" | New writes typed and canonical; replay tooling tolerates legacy formats |
| R-17 | Lambda concurrency | Partner bursts compete with legacy raters | Reserved concurrency per rater; backtests never call Lambda |
| R-18 | Duplicate keys in existing question rows | A unique (rater version, key) constraint fails on existing data | Inspect first; add the constraint `NOT VALID` for history if needed (Q-21) |

## Open questions

Blocking or shaping v1:

| ID | Question | Affects | Default if unanswered |
|---|---|---|---|
| Q-01 | Admitted or surplus lines, per product and state? | Ops rate changes, partner discounts, experiments | Design for filings (superset) |
| Q-02 | Volumes and latency expectations? | Sizing, alarm thresholds | Phase 0 measures them |
| Q-03 | The real discount stacking rule, with a worked example that reconciles? | Discount logic | Don't port until known |
| Q-04 | Which date does Django use to pick the rater version today, and should programs differ? | Version resolution | Same rule as today |
| Q-05 | Rater source, language, whether factors are tabular, whether it calls outside services; the DS spreadsheet and the 1,000 applications | Phase 3 scope, replay set | Inspect the code |
| Q-06 | Which partner branches exist in the rater, and what they key on? | Phase 3b | Inventory from Q-05 |

Before the related phase:

| ID | Question | Default |
|---|---|---|
| Q-07 | What does `application_coverage.coverage_id` reference? | Use coverage codes |
| Q-08 | Who sets `coverage_denied`, the rater or the underwriter? | Rater returns `declined`; underwriters can also set it |
| Q-09 | Why did past API partners fail: volumes, rejected fields, feedback? | Pilot with one partner and measure |
| Q-10 | Company identity (FEIN) and attribution across partners? | Capture partner and channel now; dedup later |
| Q-11 | Postgres version, PK type, column types, `btree_gist` availability? | Inspect |
| Q-12 | API deprecation window for partners? | 12 months |
| Q-13 | Team size and frontend capacity? | React SPA if possible, else HTMX |
| Q-14 | How staff reach internal tools (VPN or not)? | Private API if VPN |
| Q-15 | Availability targets and RTO/RPO? | Single region, multi-AZ, cross-region backups |
| Q-16 | Entity type and domicile; data clauses in carrier and partner contracts? | US regions only; counsel review |
| Q-17 | Who approves what; impact thresholds per program? | Four-eyes on every publish; thresholds in 05 §2.3 |
| Q-18 | Data classification of answers; retention for `rating_run`? | No values in logs; retain for policy lifetime plus the regulatory period |
| Q-19 | Notice period for breaking schema changes, per partner? | 30 days |
| Q-20 | Does "experiment faster" mean question and UX experiments, or price? | Questions and UX only |
| Q-21 | What's the difference between `rating_engine_key` and `rating_engine_question_key`, and are keys unique within a rater version today? | Treat `rating_engine_question_key` as the answer key; inspect for duplicates |
| Q-22 | Are application forms filed with regulators for these products? If so, does a wording change need a new filing? | Version wording per program version either way; add `filing_ref` to question-wording publishes if needed |
