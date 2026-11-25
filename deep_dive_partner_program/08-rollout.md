# 08 · Rollout

Each phase ships on its own and leaves the platform working. Effort is rough engineer-weeks for people who know the codebase. It isn't validated: team size (Q-13) and the rater code (Q-05) could move it a lot.

| Phase | Ships | Done when | Rough effort |
|---|---|---|---|
| 0 | **Safety net.** Characterization tests that record today's premiums on the replay set and fail CI if any change. Contract tests for the Django-to-rater payload and the existing underwriting flows (create, answer, rate, discount). CI gates on both. Logging library, alarms, log lake. Start writing `rating_run`. | No change reaches production without passing the premium and contract tests; real volume and latency numbers exist | 2–4 |
| 1 | `partner`, `program`, `program_version`; base program created per existing rater version; every application linked; public IDs | Every application has a program version; phase 0 tests still pass unchanged | 2–3 |
| 2 | API standard, API Gateway, Cognito, internal API skeleton | Contract tests pass in CI; oasdiff gate active | 4–6 |
| 3 | Rater input declaration and generated manifest, config-aware rater (overrides, module registry), preflight check, backtest harness, `rating_test_case` | Empty config reproduces today's premiums exactly (the parity rule) | 4–7 |
| 3b | Convert each hardcoded partner branch to a partner program | Each partner's historical applications rate identically; branch deleted | 1–3 |
| 4 | Definition metadata and carry-forward, program question sets, presets, Ops interface with version history (diff, restore), approvals, schema compatibility check | Ops publish a question change with no engineer | 5–8 |
| 5 | Per-coverage discounts, program discounts, rebase drafts | Discounts rate correctly per coverage; a base change produces rebase drafts | 2–4 |
| 6 | External API, sandbox, partner docs, one pilot partner | Pilot's submissions and data quality reviewed with the PM | 4–6 |

Total roughly 24–41 engineer-weeks. Time to a first partner program is roughly half of that: phases 0–2, enough of 3 for that partner's needs, 4, and 6.

Phase 0 is first on purpose. Its tests are what every later phase is measured against, and every day without `rating_run` is history we can't get back.
