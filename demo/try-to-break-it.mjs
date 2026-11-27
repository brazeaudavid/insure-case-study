// Loads schema.sql and seed.sql into an in-memory Postgres (PGlite), shows that two
// partners can word the same question differently, then tries each write the design
// forbids and prints how Postgres refuses it.
//
//   npm install
//   node try-to-break-it.mjs
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { btree_gist } from '@electric-sql/pglite/contrib/btree_gist';

const here = (f) => new URL(f, import.meta.url);
const db = new PGlite({ extensions: { btree_gist } });
await db.exec(await readFile(here('schema.sql'), 'utf8'));
await db.exec(await readFile(here('seed.sql'), 'utf8'));

const bold = (s) => `\x1b[1m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;
const red = (s) => `\x1b[31m${s}\x1b[0m`;

console.log(bold('\nOne definition, three wordings (view program_question_resolved)\n'));
const { rows } = await db.query(`
  SELECT p.name AS program, r.key, r.question_id, r.mode, COALESCE(r.preset_value, '') AS preset, r.label
  FROM program_question_resolved r
  JOIN program_version pv ON pv.id = r.program_version_id
  JOIN program p ON p.id = pv.program_id
  WHERE pv.id IN (70, 73, 82) AND r.key IN ('employee_count', 'industry')
  ORDER BY r.key, pv.id`);
console.table(rows);

// Each attempt runs in its own transaction and is rolled back, so they don't affect each other.
const attempts = [
  ['A second definition of employee_count on rater 101',
   `INSERT INTO application_question (id, rating_engine_version_id, rating_engine_question_key, question_text, answer_type, purpose)
    VALUES (2099, 101, 'employee_count', 'How many kids do you have?', 'integer', 'rating_input')`],
  ['Change what employee_count means after it has been answered',
   `UPDATE application_question SET answer_type = 'text' WHERE id = 2003`],
  ['Reword a question on the published Acme version in place',
   `UPDATE program_version_question SET label = 'Headcount?' WHERE id = 731`],
  ['Add a question to the published Shieldline version',
   `INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode)
    VALUES (899, 82, 2009, 101, 'ask')`],
  ['A rater-101 draft that borrows a rater-100 question',
   `INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id)
      VALUES (74, 2, NULL, 'draft', 101, 70);
    INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode)
      VALUES (740, 74, 1002, 101, 'ask')`],
  ['Preset industry to a value the rater does not know',
   `INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id)
      VALUES (74, 2, NULL, 'draft', 101, 70);
    INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, preset_value)
      VALUES (740, 74, 2001, 101, 'preset', 'food_truck')`],
  ['Preset a question without saying what the answer is',
   `INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id)
      VALUES (74, 2, NULL, 'draft', 101, 70);
    INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode)
      VALUES (740, 74, 2001, 101, 'preset')`],
  ['Widen a range beyond what the rater accepts',
   `INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id)
      VALUES (74, 2, NULL, 'draft', 101, 70);
    INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, validation)
      VALUES (740, 74, 2003, 101, 'ask', '{"max": 100000}')`],
  ['An application whose rater differs from its program version\'s rater',
   `INSERT INTO application (id, program_version_id, rating_engine_version_id, channel) VALUES (5002, 73, 100, 'partner_api')`],
  ['Answer a rater-100 question on a rater-101 application',
   `INSERT INTO application_answer (application_id, question_id, answer_text, source) VALUES (5001, 1002, '14', 'partner_api')`],
  ['Store a second answer to the same question',
   `INSERT INTO application_answer (application_id, question_id, answer_text, source) VALUES (5001, 2003, '15', 'partner_api')`],
  ['Publish a second base version that overlaps v7 in time',
   `INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, effective_from)
    VALUES (71, 1, 8, 'published', 101, '2026-11-01')`],
];

console.log(bold('Trying to break it\n'));
let refused = 0;
for (const [what, sql] of attempts) {
  try {
    await db.exec(`BEGIN; ${sql}`);
    console.log(`${red('ALLOWED')}  ${what}`);
  } catch (e) {
    refused++;
    console.log(`${green('REFUSED')}  ${what}\n         ${e.constraint ?? e.code}: ${e.message}`);
  } finally {
    await db.exec('ROLLBACK');
  }
}
console.log(`\n${refused} of ${attempts.length} refused by the database.\n`);

console.log(bold('The way it is allowed: reword through a new version\n'));
await db.exec(`
  BEGIN;
  -- Draft v4 copies v3's rows, then changes the wording.
  INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id, effective_from)
    VALUES (74, 2, 4, 'draft', 101, 70, '2026-12-01');
  INSERT INTO program_version_question
    (id, program_version_id, question_id, rating_engine_version_id, mode, preset_value, required, label, option_labels, allowed_options, validation, display_order)
    SELECT id + 10, 74, question_id, rating_engine_version_id, mode, preset_value, required, label, option_labels, allowed_options, validation, display_order
    FROM program_version_question WHERE program_version_id = 73;
  UPDATE program_version_question SET label = 'How many people are on your payroll, including part-time?' WHERE id = 741;
  -- Publish: close v3's window, then publish v4.
  UPDATE program_version SET effective_to = '2026-12-01', status = 'superseded' WHERE id = 73;
  UPDATE program_version SET status = 'published' WHERE id = 74;
`);
const reworded = await db.query(`
  SELECT pv.version_no AS version, pv.status, r.label
  FROM program_question_resolved r JOIN program_version pv ON pv.id = r.program_version_id
  WHERE pv.program_id = 2 AND r.key = 'employee_count' ORDER BY pv.version_no`);
console.table(reworded.rows);
console.log('Application 5001 stays on v3 and keeps the wording it was answered under.\n');
await db.exec('ROLLBACK');
process.exitCode = refused === attempts.length ? 0 : 1;
