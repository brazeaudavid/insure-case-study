# 02 · Design

## 1. Programs

- A **program** is a sellable offering. The **base program** is InsureNext's own, today's behavior. A **partner program** belongs to a partner and derives from a base program. One partner can have several programs, for example "Acme Restaurants" and "Acme Retail".
- A **program version** is a numbered snapshot of a program. It pins one rater version and, for partner programs, one base program version. Drafts are editable. Published versions never change.
- Every application stores its program version, and its rater version is the one that program version pins. A composite FK enforces that (03 §3).
- **Version selection** follows today's rule. Django already picks the rater version by effective date. Program versions use the same rule and the same date. If the business wants the policy effective date instead, it's one function (Q-04).
- In-flight applications stay on the version they started with. Moving one to a newer version is a deliberate, logged action that re-validates answers and re-rates.

### Any combination

A program version's customizations are its question rows plus two optional config sections. Anything left out behaves like the base.

| Customizes | Has |
|---|---|
| Nothing (white-label) | no question rows, empty config |
| Questions only | question rows |
| Rating only | `config.rating` |
| Discounts only | `config.discounts` |
| Any mix | any subset |

Sections can depend on each other. Omitting a question can starve the rater or a module, and a module can need an input nobody asks. Publish validation catches those combinations statically (05 §3), and the backtest confirms them dynamically.

## 2. Questions

### 2.1 Immutable definitions, versioned presentation

**Why questions are immutable.** An application is a filed policy form in most states (Illinois, for example, defines a "policy form" to include an application blank), and forms carry an edition date. Changing the wording means filing a new edition that names the one it replaces. Healthcare's FHIR standard does the same for questionnaires: each response records the exact questionnaire version it answered, and item ids stay stable across versions. So a question that's been used is never edited, only superseded, and every application must resolve to exactly what it was answered under.

A question has two halves, versioned with different things:

| Half | Table | Holds | Scoped to | Changes by |
|---|---|---|---|---|
| Definition: what the answer means | `application_question` (existing) | key, `answer_type`, option codes, validation, `purpose` | Rater version, as today. **UK** (rating_engine_version_id, rating_engine_question_key) | A new rater version |
| Presentation: how it's asked | `program_version_question` (new) | mode (`ask`, `preset`, `omit`), exact wording, help text, option labels, section, order, required, allowed-options subset, show-if | Program version | A new program version |

- "That exact question on that exact rater version" is the unique key. The rater interprets answers by key, so the definition belongs with the rater, which is where today's schema already puts it.
- Definitions are immutable once a published question set or any answer references them (DB trigger). Drafts can still fix a definition nothing references yet.
- Presentation is snapshotted per program version, so the history shows the exact wording and option labels an applicant saw. Rewording is a normal program publish, with no rater change.
- `program_version_question` carries `rating_engine_version_id` and two composite FKs: (program_version_id, rating_engine_version_id) → `program_version` and (question_id, rating_engine_version_id) → `application_question`. The database refuses a question set that mixes in another rater version's questions.
- The base program lists its full set. A partner program on the same rater as its base lists only its differences (NULL columns mean "same as base"), overlaid on the base set by `question_id`. A partner program on its own rater version (customization level 4) lists a full set.
- Ops add an underwriting or informational question as a new definition under the program's current rater version. That's an insert, never an edit, so nothing existing is affected.

**Carrying definitions forward.** When CI registers a new rater version, the system generates its definitions from the previous version's rows and the new manifest:

| Previous definition | New manifest | Result |
|---|---|---|
| Rating input | Same key, same type and values | Copied as a new row |
| Rating input | Same key, type or values changed | New row from the manifest, flagged for Ops to review the wording |
| Rating input | Key gone | Not copied into the new edition. The old rows stay. Programs that use it can't move to the new rater until changed. |
| Not in previous version | New input | New row from the manifest, wording to be written by Ops before any program can adopt the rater |
| Underwriting or informational | n/a | Copied as a new row |

Old rows are never touched, and nothing is ever deleted. Every rater version and its definitions stay replayable for as long as records are retained. When a program version moves to the new rater (an upgrade or a rebase), its question-set rows are re-pointed to the new definitions by key, automatically, and the diff shows any definition that changed. Analysis across rater versions joins on the key, which stays the same.

Sources: [Illinois 50 Ill. Adm. Code 1405.20 (application blank is a policy form; edition dates)](https://www.law.cornell.edu/regulations/illinois/Ill-Admin-Code-tit-50-SS-1405.20) · [Wisconsin OCI form filing (superseded form must be listed)](https://oci.wi.gov/Pages/Regulation/Bulletin19960815FormFiling.aspx) · [FHIR QuestionnaireResponse (canonical questionnaire reference, linkId)](https://hl7.org/fhir/questionnaireresponse.html)

### 2.2 Scale

Answers are one row per application and question, so the number of questions doesn't change the shape. A program with 500 questions is 500 question-set rows per version (copy on write when a draft is created), plus 500 definition rows per rater version (copied automatically at registration), and up to 500 answer rows per application. Both are indexed by their parent id. If version copies ever get large, question-set rows can be shared between versions by content hash. Nothing suggests that's needed.

### 2.3 Purpose, and why it matters for iteration

Every question can change the outcome, either the price or the underwriting decision, so all of them go through versioning, validation and approval. Purpose decides who can add one and which checks apply.

| Purpose | Read by | Added by | Backtest needed |
|---|---|---|---|
| `rating_input` | The rater | DS declare it in the rater, then Ops pick it from the manifest list | Yes |
| `underwriting` | Underwriters and referral rules | Ops | No |
| `informational` | Reporting | Ops | No |

That gives Ops a fast experiment loop that never touches pricing. Ops add an underwriting or informational question and publish it the same day. If the answers turn out to predict loss, DS declare that key as an input in the next rater version. At registration, the definition is carried forward as a rating input under the same key. The manifest check confirms the type and options match, and every answer collected so far is usable for the new factor.

### 2.4 Keys

- Rating inputs: the key, type and values come from the rater's declaration, via the manifest. The definition is generated at registration. Ops only write the wording.
- Other questions: the key is generated from the label (`how_did_you_hear`), and it can be fixed until a published version or an answer references it.
- Nobody types a rating key twice. When DS promote an existing question to a rating input, the rater references the existing key, and CI fails if the type or options disagree. That's a reference checked by machine, not a second entry that can drift.

### 2.5 Allowed values

For anything the rater reads, a closed list is required by determinism. The rater has to do something specific with every value it can receive, so the list already exists in the code. Today it's implicit, often a silent `else` default. The refactor makes it explicit in the declaration. Codes (`pest_control`) live on the definition, and labels ("Pest Control") on the program version, so wording can change without touching rating. Numbers get a type and range. Free text that the rater doesn't read has no list. A program can narrow a list (`allowed_options`), never widen it.

## 3. Presets

A preset answers a question without asking it. The case study's restaurant example: the program omits industry questions, but the rater still needs `industry` to pick a class factor. Hiding the question without supplying the value would leave the rater with nothing, so it either errors or silently defaults. The restaurant program presets `industry = restaurant`.

- At application creation, preset answers are written as answer rows with `source = preset`, so the record and the payload match.
- Publish requires every required rater input to be covered by a required, always-visible question or a preset. A required input behind a show-if condition counts only if the rater declares the input as conditional on the same thing.
- There's no "no program" case. Direct business runs under the base program, the migration links every existing application to it, and `application.program_version_id` becomes NOT NULL.

## 4. The manifest

The rater declares its inputs once in its own code: key, type, allowed values, required or conditional. It reads answers only through that declaration, so using an undeclared key fails in tests. The build generates the manifest from the declaration and from the module registry and table definitions:

```json
{
  "inputs": [ { "key": "industry", "type": "enum", "values": ["restaurant", "pest_control", "other"], "required": true } ],
  "coverages": [ { "code": "epl", "limits": ["1000000", "5000000"], "deductibles": ["25000"] } ],
  "tables": [ { "name": "class_factor", "dims": ["industry"], "overridable": true, "min": "0.5", "max": "2.0" } ],
  "modules": [ { "name": "liquor_sales_surcharge", "hook": "post_factors", "params_schema": { "rate": "decimal 0..0.25" }, "requires_inputs": ["liquor_sales_pct"] } ],
  "discounts": { "underwriter_keys": ["schedule_credit"], "stacking": "confirm with DS (Q-03)" }
}
```

CI registers the manifest with the new `rating_engine_version` row. From then on it's what the Ops interface offers, what publish validates against, and what Django preflights every payload against.

## 5. Rating config

### 5.1 The document

```json
{
  "rating": {
    "table_overrides": { "class_factor": [ { "key": { "industry": "restaurant" }, "value": "0.92" } ] },
    "modules": [ { "name": "liquor_sales_surcharge", "params": { "rate": "0.05" } } ]
  },
  "discounts": {
    "underwriter_limits": { "schedule_credit": { "max": "0.15" } },
    "program": [ { "code": "member_discount", "coverages": ["epl"], "value": "0.05", "mode": "automatic" } ]
  }
}
```

Validated by a versioned JSON Schema on save and against the pinned manifest at publish. Money and factors are decimal strings.

### 5.2 Combining base and partner

Our Django service layer combines the layers (rater defaults, then base config, then partner config) before rating. That's a small merge function we write, not something the framework provides:

- **Rate tables row by row.** The base `class_factor` has 40 rows, and the partner overrides `restaurant`. The rater gets the base table with that one row replaced.
- **Modules by name.** The partner can switch on a module, change its parameters, or switch off one the base uses (`"enabled": false`).
- **Discounts by code.**

The combined result goes into the payload, and its hash is stored with the publish, so `rating_run` shows exactly what was applied.

### 5.3 Modules

A module is a function that already lives in the rater code, registered under a name with a hook point (where in the calculation it runs), a parameter schema, and the inputs it needs. It ships inside the rater Lambda. Config can only switch on modules the deployed rater has and pass parameters. No code travels in config. Modules are named for what they do (`liquor_sales_surcharge`), not for a partner, so they stay reusable.

**In-process, not a Lambda per module.** The rater's entry point is the controller. It reads `rating_config` from the payload, looks up enabled modules in its registry, and calls each at its hook (for example `post_factors`, `pre_discount`) in a fixed pipeline order. The manifest isn't read at runtime. It's generated at build time and used to validate configs before publish.

| | Modules in-process (chosen) | Module per Lambda, orchestrated |
|---|---|---|
| Reproducibility | One rater version = one immutable artifact | A rater version must pin exact versions of N Lambdas |
| Latency, failure | Function calls | A network hop per module, partial failures, retries |
| Backtest | Run the rater code as a library | Must emulate the orchestration |
| Deploy | New module = new rater version, backtested | Independent deploys that can change old ratings if not pinned |

A rating that genuinely needs its own deployable gets its own rater version (level 4).

| Level | Example | Code? |
|---|---|---|
| 1. Values | Restaurant class factor 0.92 instead of 1.00 | No. Override within the manifest limits. |
| 2. Reuse logic | Liquor surcharge used by several restaurant programs at different rates | Once, when the module is first written |
| 3. New logic | A calculation only one program uses | Yes, a new module switched on by config |
| 4. Different rating | Little in common with the base | A separate rater version that the program pins |

### 5.4 Payload

Existing fields keep working, and new fields are optional:

```json
{
  "version": 100,
  "program": { "version_id": "prv_01J…", "content_hash": "…" },
  "answers": { "industry": "restaurant", "annual_revenue": "2500000" },
  "coverages": [ { "code": "epl", "limit": 5000000, "deductible": 25000,
                   "underwriter_discounts": { "schedule_credit": "0.1" },
                   "program_discounts": { "member_discount": "0.05" } } ],
  "rating_config": { "table_overrides": { "…": "…" }, "modules": [ "…" ] }
}
```

`answers` holds only the declared inputs. Underwriting and informational answers aren't sent. If the rater calls outside services today, those results must become inputs, or the stored payload can't replay the rating (Q-05).

## 6. Who changes what

| Who | Changes | How |
|---|---|---|
| Insurance Ops | Questions (non-rating freely, rating inputs from the manifest), question sets, presets, overridable rate values, module parameters, discount limits and program discounts | Ops interface: draft, automatic checks, backtest where pricing changes, approval, publish |
| Data Science | Rater tables, modules, base logic, input declarations | Rater pull request, CI, new rater version, adopted by a base program version that the business approves |
| Partner manager | Partner program requests, `manual` rebase approvals | Ops interface |
| Engineering | Module framework, APIs, schema | Normal code review |

If products are admitted, rate and discount publishes carry a filing reference and an approved effective date (Q-01).

## 7. Discounts

- New applications store discounts per coverage (`application_discount`, with `source` underwriter, program or partner).
- Programs can narrow underwriter discount limits and define program discounts.
- Stacking and caps belong to the rater and are listed in the manifest once DS confirm them (Q-03).
- Partner-specific discounts need compliance sign-off if products are admitted (Q-01).

## 8. Base rate increases and rebasing

![Base rebase](diagrams/base-rebase.svg)

Partner programs are pinned to a base version, so a base change never silently reprices a partner. But rates rise across the board every year, and that increase has to reach the programs that should get it, without manual busywork.

1. The increase is a base program change, usually a base rate or rate-level factor.
2. When the base version is approved, the system creates a **rebase draft** for every partner program on the previous base. Partner overrides carry over. A partner override of a value the base also changed is flagged as a conflict.
3. Each rebase draft is validated and backtested automatically.
4. `program.base_upgrade_policy = follow_base` (the default): included in the base approval and published on the same effective date.
5. `manual` (a contractual rate lock, a partner with notice terms): goes to the partner manager's queue and publishes on its own date.
6. The Ops interface always shows which programs are behind the latest base.

Partner overrides are deltas, so an increase to rows the partner didn't override flows through on rebase automatically. Closing a rater version to new programs prompts rebases the same way. Old versions stay replayable.

## 9. Questions I expect in the live review

| Question | Answer |
|---|---|
| Why not send partners a form? Isn't that restrictive? | We send a data contract (JSON Schema), not a UI. What gets asked is tailored per partner program. How it's asked is entirely the partner's: their screens, order, steps, pre-fill from their own data. They can't invent keys or values, which is the point. |
| What if a schema change breaks a partner? | Applications are pinned to their version. Publish classifies schema changes, and breaking ones need a future effective date that respects the notice period, plus sandbox first (04 §4). |
| Why rows for questions but JSON for rates? | Questions are many, referenced by answers, edited often, and diffed per item, so they need FKs. Rate overrides are small parameter blobs whose shape the manifest defines, always read together. |
| What does the partner see if the rater is down? | Submit succeeds, the quote is `pending`, rating retries with backoff (it's deterministic, so retries are safe), and the alarm fires. |
| A partner wants different coverages or limits | Add a `coverages` section to the config, with allowed values from the manifest. Same pattern. |
| Rates vary by state | Rate tables gain a state dimension, and overrides can be per state. Filing rules apply (Q-01). |
| Refer risky applications to an underwriter | A module returns referral reasons, and the quote status becomes `referred`. |
| A regulator asks why a premium was X | Replay the stored `rating_run` request through the same published Lambda version and show the identical result. |
| 100× partner volume | Scale the external process group and gateway limits. Rating is per application and stateless. Extract a dedicated service only if measurements require it. |
| The same company arrives via two partners | Add a company identity key (FEIN) and an attribution rule (Q-10). |
| Commissions | A `commission` config section and a payout export. |
| Webhooks | Outbox table plus a signed sender. Events are already defined (04 §5). |
| Partners want to edit their own program | A partner portal on the internal API with partner-scoped roles. The approval workflow stays the same. |
