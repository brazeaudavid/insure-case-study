-- Partner programs: the question part of the data model, with its real constraints.
-- A runnable subset of deep_dive_partner_program/03-data-model.md. Columns that only
-- matter for audit, APIs or rating (public ids, approvals, config, rating_run, ...) are
-- left out so the rules about questions are easy to see.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Existing table, plus manifest. Versions from before the input declaration have no manifest.
CREATE TABLE rating_engine_version (
  id              bigint PRIMARY KEY,
  effective_date  date   NOT NULL,
  endpoint_url    text   NOT NULL,
  manifest        jsonb
);

-- Existing table. A question DEFINITION: what the answer means. Scoped to a rater version as today.
CREATE TABLE application_question (
  id                         bigint PRIMARY KEY,
  rating_engine_version_id   bigint NOT NULL REFERENCES rating_engine_version (id),
  rating_engine_question_key text   NOT NULL,
  question_text              text   NOT NULL,            -- default wording, copied into question sets
  answer_type                text   NOT NULL CHECK (answer_type IN ('text','integer','decimal','money','boolean','enum')),
  options                    jsonb,                      -- [{code, label}] for enums
  validation                 jsonb,                      -- {min, max}
  purpose                    text   NOT NULL CHECK (purpose IN ('rating_input','underwriting','informational')),
  carried_from_question_id   bigint REFERENCES application_question (id),
  -- One definition of each key per rater version.
  CONSTRAINT application_question_key_per_rater_uk UNIQUE (rating_engine_version_id, rating_engine_question_key),
  -- Target of the composite FK from program_version_question.
  CONSTRAINT application_question_id_rater_uk UNIQUE (id, rating_engine_version_id),
  CHECK ((answer_type = 'enum') = (options IS NOT NULL))
);

CREATE TABLE partner (
  id    bigint PRIMARY KEY,
  name  text NOT NULL
);

CREATE TABLE program (
  id               bigint PRIMARY KEY,
  name             text NOT NULL,
  partner_id       bigint REFERENCES partner (id),       -- null = base program
  base_program_id  bigint REFERENCES program (id),
  CHECK ((partner_id IS NULL) = (base_program_id IS NULL))
);

CREATE TABLE program_version (
  id                        bigint PRIMARY KEY,
  program_id                bigint NOT NULL REFERENCES program (id),
  version_no                int,
  status                    text   NOT NULL CHECK (status IN ('draft','published','superseded')),
  rating_engine_version_id  bigint NOT NULL REFERENCES rating_engine_version (id),   -- the pin
  base_program_version_id   bigint REFERENCES program_version (id),
  effective_from            timestamptz,
  effective_to              timestamptz,
  CONSTRAINT program_version_no_uk UNIQUE (program_id, version_no),
  CONSTRAINT program_version_id_rater_uk UNIQUE (id, rating_engine_version_id),
  -- Two published versions of the same program can't be in effect at the same time.
  CONSTRAINT program_version_no_overlap EXCLUDE USING gist (
    program_id WITH =, tstzrange(effective_from, effective_to) WITH &&
  ) WHERE (status IN ('published','superseded'))
);

-- How a question is ASKED in one program version: wording, labels, ask/preset/omit.
-- Partner rows are overlays on the base version: null columns mean "same as base".
CREATE TABLE program_version_question (
  id                        bigint PRIMARY KEY,
  program_version_id        bigint NOT NULL,
  question_id               bigint NOT NULL,
  rating_engine_version_id  bigint NOT NULL,
  mode                      text   NOT NULL CHECK (mode IN ('ask','preset','omit')),
  preset_value              text,
  required                  boolean,
  label                     text,
  option_labels             jsonb,     -- {code: label}
  allowed_options           text[],    -- narrow an enum, never widen it
  validation                jsonb,     -- narrow a range, never widen it
  display_order             int,
  CONSTRAINT pvq_question_once_uk UNIQUE (program_version_id, question_id),
  -- Both composite FKs carry the same rater id, so a question set can only use
  -- definitions that belong to its own program version's rater.
  CONSTRAINT pvq_program_version_same_rater_fk FOREIGN KEY (program_version_id, rating_engine_version_id)
    REFERENCES program_version (id, rating_engine_version_id),
  CONSTRAINT pvq_question_same_rater_fk FOREIGN KEY (question_id, rating_engine_version_id)
    REFERENCES application_question (id, rating_engine_version_id),
  CONSTRAINT pvq_preset_has_value CHECK ((mode = 'preset') = (preset_value IS NOT NULL))
);

-- Existing table, plus program_version_id and the composite FK that keeps its rater consistent.
CREATE TABLE application (
  id                        bigint PRIMARY KEY,
  program_version_id        bigint NOT NULL,
  rating_engine_version_id  bigint NOT NULL REFERENCES rating_engine_version (id),
  channel                   text   NOT NULL CHECK (channel IN ('underwriter_ui','partner_api','direct')),
  CONSTRAINT application_rater_matches_program_fk FOREIGN KEY (program_version_id, rating_engine_version_id)
    REFERENCES program_version (id, rating_engine_version_id)
);

-- Existing table, plus source and one answer per question.
CREATE TABLE application_answer (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  application_id  bigint NOT NULL REFERENCES application (id),
  question_id     bigint NOT NULL REFERENCES application_question (id),
  answer_text     text,
  source          text   NOT NULL CHECK (source IN ('applicant','partner_api','preset','underwriter')),
  CONSTRAINT application_answer_once_uk UNIQUE (application_id, question_id)
);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- A definition is never edited once a published question set or an answer uses it.
CREATE FUNCTION application_question_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM application_answer WHERE question_id = OLD.id)
     OR EXISTS (SELECT 1 FROM program_version_question q
                JOIN program_version v ON v.id = q.program_version_id
                WHERE q.question_id = OLD.id AND v.status IN ('published','superseded')) THEN
    RAISE EXCEPTION 'question definition % (%) is in use and immutable; publish a new rater version to change its meaning',
      OLD.id, OLD.rating_engine_question_key
      USING ERRCODE = 'integrity_constraint_violation', CONSTRAINT = 'application_question_immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER application_question_immutable BEFORE UPDATE OR DELETE ON application_question
  FOR EACH ROW EXECUTE FUNCTION application_question_immutable();

-- A published program version only changes by closing its window or being superseded.
CREATE FUNCTION program_version_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IN ('published','superseded') AND (
       TG_OP = 'DELETE'
       OR (NEW.program_id, NEW.version_no, NEW.rating_engine_version_id, NEW.base_program_version_id, NEW.effective_from)
          IS DISTINCT FROM
          (OLD.program_id, OLD.version_no, OLD.rating_engine_version_id, OLD.base_program_version_id, OLD.effective_from)
       OR NEW.status NOT IN ('published','superseded')) THEN
    RAISE EXCEPTION 'program version % is published and immutable; restore it as a new draft instead', OLD.id
      USING ERRCODE = 'integrity_constraint_violation', CONSTRAINT = 'program_version_immutable';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER program_version_immutable BEFORE UPDATE OR DELETE ON program_version
  FOR EACH ROW EXECUTE FUNCTION program_version_immutable();

-- Question-set rows of a published version are frozen, and new rows are checked against
-- the definition: presets must be valid values, narrowing can't widen.
CREATE FUNCTION pvq_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_status text;
  d application_question%ROWTYPE;
  codes text[];
BEGIN
  SELECT status INTO v_status FROM program_version
   WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.program_version_id ELSE OLD.program_version_id END;
  IF v_status IN ('published','superseded') THEN
    RAISE EXCEPTION 'program version % is published; its questions are frozen. Change wording in a new draft version',
      CASE WHEN TG_OP = 'INSERT' THEN NEW.program_version_id ELSE OLD.program_version_id END
      USING ERRCODE = 'integrity_constraint_violation', CONSTRAINT = 'pvq_published_frozen';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;

  SELECT * INTO d FROM application_question WHERE id = NEW.question_id;
  codes := ARRAY(SELECT jsonb_array_elements(d.options) ->> 'code');

  IF NEW.mode = 'preset' AND d.answer_type = 'enum' AND NOT (NEW.preset_value = ANY (codes)) THEN
    RAISE EXCEPTION 'preset % = "%" is not an allowed value; allowed: %', d.rating_engine_question_key, NEW.preset_value, codes
      USING ERRCODE = 'check_violation', CONSTRAINT = 'pvq_preset_valid';
  END IF;
  IF NEW.allowed_options IS NOT NULL AND NOT (NEW.allowed_options <@ codes) THEN
    RAISE EXCEPTION 'allowed_options for % can only narrow the definition''s values %', d.rating_engine_question_key, codes
      USING ERRCODE = 'check_violation', CONSTRAINT = 'pvq_narrow_only';
  END IF;
  IF NEW.validation IS NOT NULL AND (
       (NEW.validation ? 'min' AND (NEW.validation->>'min')::numeric < COALESCE((d.validation->>'min')::numeric, '-infinity'))
    OR (NEW.validation ? 'max' AND (NEW.validation->>'max')::numeric > COALESCE((d.validation->>'max')::numeric, 'infinity'))) THEN
    RAISE EXCEPTION 'validation for % can only tighten the definition''s range %', d.rating_engine_question_key, d.validation
      USING ERRCODE = 'check_violation', CONSTRAINT = 'pvq_narrow_only';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER pvq_guard BEFORE INSERT OR UPDATE OR DELETE ON program_version_question
  FOR EACH ROW EXECUTE FUNCTION pvq_guard();

-- An answer's question must belong to the application's rater version.
CREATE FUNCTION application_answer_same_rater() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT rating_engine_version_id FROM application_question WHERE id = NEW.question_id)
     IS DISTINCT FROM
     (SELECT rating_engine_version_id FROM application WHERE id = NEW.application_id) THEN
    RAISE EXCEPTION 'question % belongs to a different rater version than application %', NEW.question_id, NEW.application_id
      USING ERRCODE = 'integrity_constraint_violation', CONSTRAINT = 'application_answer_same_rater';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER application_answer_same_rater BEFORE INSERT OR UPDATE ON application_answer
  FOR EACH ROW EXECUTE FUNCTION application_answer_same_rater();

-- ---------------------------------------------------------------------------
-- The question set a program version actually uses: partner overlays on the base.
-- ---------------------------------------------------------------------------
CREATE VIEW program_question_resolved AS
WITH base_of AS (
  SELECT id AS pv_id,
         COALESCE(base_program_version_id, id) AS base_id,
         base_program_version_id IS NOT NULL   AS is_partner
  FROM program_version
),
question_keys AS (
  -- every question of the base version, plus questions only the partner version adds
  SELECT bo.pv_id, q.question_id
  FROM base_of bo JOIN program_version_question q ON q.program_version_id = bo.base_id
  UNION
  SELECT program_version_id, question_id FROM program_version_question
)
SELECT
  k.pv_id                                        AS program_version_id,
  d.id                                           AS question_id,
  d.rating_engine_question_key                   AS key,
  d.answer_type,
  d.purpose,
  COALESCE(p.mode, b.mode)                       AS mode,
  COALESCE(p.preset_value, b.preset_value)       AS preset_value,
  COALESCE(p.required, b.required, false)        AS required,
  COALESCE(p.label, b.label, d.question_text)    AS label,
  COALESCE(p.option_labels, b.option_labels)     AS option_labels,
  COALESCE(p.allowed_options, b.allowed_options) AS allowed_options,
  COALESCE(p.validation, b.validation, d.validation) AS validation,
  COALESCE(p.display_order, b.display_order)     AS display_order
FROM question_keys k
JOIN base_of bo               ON bo.pv_id = k.pv_id
JOIN application_question d   ON d.id = k.question_id
LEFT JOIN program_version_question b
       ON b.program_version_id = bo.base_id AND b.question_id = k.question_id
LEFT JOIN program_version_question p
       ON bo.is_partner AND p.program_version_id = bo.pv_id AND p.question_id = k.question_id
WHERE COALESCE(p.mode, b.mode) <> 'omit';
