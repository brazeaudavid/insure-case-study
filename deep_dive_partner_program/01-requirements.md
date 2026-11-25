# 01 · Requirements

Source: `../eng_case_study.pdf` (5 pages). This file restates what the case study says, what I observed, and how each stakeholder comment is answered.

## 1. The ask

| # | Requirement | Source |
|---|---|---|
| R-1 | Design and begin to build the foundation for partner-specific programs | p1 |
| R-2 | Customizations: application questions, rating factors and logic, discounts | p1, p4 |
| R-3 | Any combination of customizations can be active for a program | p1, p4 |
| R-4 | Keep one cohesive underwriting platform, not a fork per partner | p4 |
| R-5 | Design write-up: how to expand the systems and data model, why, trade-offs, what's left out of v1 | p1 |
| R-6 | A lightweight build artifact | p1 |
| R-7 | Evaluated on data modeling, architecture, system design, and extending the design live | p1 |

## 2. Current state

| Table | Columns | Relationships |
|---|---|---|
| `company` | id, legal_name, dba_name, created_at, updated_at, url, address1, address2, city, state, zip | 1 → 0..* application |
| `rating_engine_version` | id, effective_date, endpoint_url | 1 → * application, 1 → * application_question |
| `application` | id, created_at, updated_at, status, company_id, rating_engine_version_id | has * answers, * coverages |
| `application_question` | id, rating_engine_version_id, rating_engine_key, rating_engine_question_key, question_text, is_pricing_modifier | 1 → * answers |
| `application_answer` | id, application_id, question_id, answer_text | |
| `application_coverage` | id, coverage_id, computed_premium, limit, deductible, coverage_denied, additional_details, rating_engine_response | |

Systems: underwriters use a Django platform on Postgres. Django picks the rater version by effective date and calls that version's Lambda.

Rater input: `version`, `answers` (flat key → value), `coverages[]` with code, limit, deductible and `underwriter_discounts`. Output: per coverage, `premium_no_discount`, `discounted_amount`, `premium`.

## 3. Observations

| # | Observation | Consequence for the design |
|---|---|---|
| O-1 | Questions have a FK to a rater version, so a new rater version probably means re-creating its questions | Keep definitions per rater version (that's what the rater interprets) and immutable; carry them forward automatically on a new rater version. Wording moves to the program version. |
| O-2 | Discounts are questions (`is_pricing_modifier`) answered per application, but sent to the rater per coverage | New `application_discount` per coverage. Legacy discount answers stay as they are. |
| O-3 | The sample discounts don't reconcile. The output is 1,123 / 9,123 = 12.3%. The inputs 0.25 and 0.10 give 35% added, or 32.5% compounded (1 − 0.75 × 0.90). | Don't port discount logic until DS confirm the rule (Q-03) |
| O-4 | Only the rater's response is stored, not the request. Answers can be edited later, so a past premium can't be reproduced. | `rating_run` stores both, starting in phase 0 |
| O-5 | `application_coverage.coverage_id` has no target table | Use coverage codes until a coverage catalog exists (Q-07) |
| O-6 | The rater output has no decline field, but `coverage_denied` exists | Optional `declined` with a reason code in the response (Q-08) |
| O-7 | The version is sent twice: as the endpoint and as `"version": 100` | Django checks they match |
| O-8 | `answer_text` suggests untyped answers | Types enforced when answers are written. History isn't migrated. |
| O-9 | No partner or channel on `application`, no tax id on `company` | Add `partner_id`, `channel`, `external_ref`. Dedup across partners is later (Q-10). |

## 4. Stakeholder pain points and how they're answered

| # | Who | Pain point | Answer | Where |
|---|---|---|---|---|
| 1 | Data Science | Rating changes go spreadsheet → engineer → manual review of 1,000 applications | DS change the rater directly by pull request. CI generates the manifest, reports compatibility with live programs, and runs the backtest over the replay set, comparing to the cent against expected premiums exported from the spreadsheet. The report is posted on the PR. | 05 §1, §2 |
| 2 | Data Science | "We're technical and could implement rating logic directly" | They own rater tables, modules and base logic. Engineers own the module framework and the APIs. | 02 §6 |
| 3 | Insurance Ops | The question interface is too technical | The Ops interface: rating-input definitions generated from the manifest, a wording and options editor, form preview, version history, approval | 02 §2, 05 §1 |
| 4 | Insurance Ops | Want simple rating changes without engineering | Ops edit rate values the manifest marks as overridable, within limits, with automatic backtest and approval | 02 §5, 05 §1 |
| 5 | Insurance Ops | Must iterate and experiment faster | Underwriting and informational questions publish the same day with no rater change. A question can be collected first and priced later. Price experiments are out pending compliance. | 02 §2.3 |
| 6 | Partner Growth | Couldn't offer partners any customizations | Partner programs customize questions, rating and discounts in any combination | 02 §1 |
| 7 | Partner Growth | Partners want API integrations | External API with a per-program data contract, sandbox, drafts with autosave, idempotent submit | 04 |
| 8 | PM | Junk data from API partners | Partners map to our codes once against the schema. Every write is validated and rejected with field-level errors. Per-partner data-quality metrics. | 04 §3 |
| 9 | PM | Barely any submissions from API partners | Lower integration effort and make it measurable (submission funnel, silent-partner alarm). The root cause may be commercial (Q-09). | 04, 06 |
| 10 | PM | Partner customizations hardcoded as if/else in the rater | Config plus named modules, never partner checks. Existing branches converted one at a time with proof of identical premiums. | 02 §5, 08 phase 3b |
| 11 | PM | Question keys double-entered, causing errors | Keys declared once in the rater code, and everything else generated from or checked against the manifest by machine | 02 §4 |

## 5. Non-functional requirements (inferred, labelled as such)

- Every premium reproducible and explainable later (regulatory expectation).
- Deterministic rating: same payload and rater version, same premium.
- Money never in binary floating point.
- Partner data isolation: a partner sees only its own applications.
- Not stated anywhere: volumes, latency targets, number of partners, availability, retention. Phase 0 measures what it can (Q-02).
