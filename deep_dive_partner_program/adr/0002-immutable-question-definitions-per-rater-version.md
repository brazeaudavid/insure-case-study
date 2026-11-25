# 0002 · Immutable question definitions per rater version; wording versioned per program version

**Status:** Accepted (revised 2026-11-24: replaces a shared, rater-independent question library)

## Context
Questions are tied to a rater version today (`application_question.rating_engine_version_id`). Ops need to add and reword questions quickly, the number of questions is unknown, and every past application must resolve to exactly what it was answered under. Application forms are filed policy forms with edition dates in most states, so a wording change means a new edition. FHIR responses likewise pin the exact questionnaire version. A shared, editable library was rejected: one edit would reach every past application and rater that used the question.

## Decision
- The definition (key, type, option codes, validation, purpose) stays in `application_question`, scoped to the rater version, with UK (rating_engine_version_id, rating_engine_question_key). It's immutable once referenced.
- The presentation (wording, option labels, order, required, show-if, ask/preset/omit) is in `program_version_question`, snapshotted per program version. Composite FKs force a question set to use only its own rater's definitions.
- When a rater version is registered, definitions are carried forward automatically from the previous version and the new manifest, with lineage in `carried_from_question_id`. Programs moving to the new rater are re-pointed by key.

## Consequences
- + No existing column changes; history can't be altered; the DB enforces that questions match the rater; wording changes need no rater change.
- − Definition rows are copied per rater version (automated). Analysis across versions joins on the key.
