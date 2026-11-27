-- Example data: one rater, a base program and two partner programs.
-- Partners and wording are invented for the demo. The same data drives index.html.

-- Rater 100 predates the input declaration (no manifest). Rater 101 declares its inputs,
-- and its manifest is generated from that declaration.
INSERT INTO rating_engine_version (id, effective_date, endpoint_url, manifest) VALUES
(100, '2026-01-01', 'arn:aws:lambda:us-east-1:000000000000:function:rater:100', NULL),
(101, '2026-10-01', 'arn:aws:lambda:us-east-1:000000000000:function:rater:101', '{
  "inputs": [
    {"key": "industry",          "type": "enum",    "required": true,
     "values": ["restaurant","pest_control","retail","contractor","professional_services","other"]},
    {"key": "annual_revenue",    "type": "money",   "required": true,  "min": 0, "max": 100000000},
    {"key": "employee_count",    "type": "integer", "required": true,  "min": 1, "max": 5000},
    {"key": "building_ownership","type": "enum",    "required": true,  "values": ["own","lease"]},
    {"key": "prior_claims_3yr",  "type": "integer", "required": true,  "min": 0, "max": 50},
    {"key": "liquor_sales_pct",  "type": "decimal", "required": false, "min": 0, "max": 100}
  ],
  "tables": [
    {"name": "class_factor",    "dims": ["industry"]},
    {"name": "headcount_factor","dims": ["employee_count"]}
  ]
}');

-- Rater 100's legacy rows (typed here only so the demo schema accepts them).
INSERT INTO application_question (id, rating_engine_version_id, rating_engine_question_key, question_text, answer_type, options, validation, purpose) VALUES
(1001, 100, 'industry',       'Industry',            'text',    NULL, NULL, 'rating_input'),
(1002, 100, 'employee_count', 'Number of employees', 'text',    NULL, NULL, 'rating_input');

-- Rater 101's definitions: carried forward from 100 plus the manifest. Rating inputs come
-- from the manifest; underwriting and informational questions were added by Ops.
INSERT INTO application_question (id, rating_engine_version_id, rating_engine_question_key, question_text, answer_type, options, validation, purpose, carried_from_question_id) VALUES
(2001, 101, 'industry', 'What industry is your business in?', 'enum',
 '[{"code":"restaurant","label":"Restaurant or bar"},{"code":"pest_control","label":"Pest control"},{"code":"retail","label":"Retail"},{"code":"contractor","label":"Contractor"},{"code":"professional_services","label":"Professional services"},{"code":"other","label":"Other"}]',
 NULL, 'rating_input', 1001),
(2002, 101, 'annual_revenue', 'What was your gross revenue last year?', 'money', NULL, '{"min":0,"max":100000000}', 'rating_input', NULL),
(2003, 101, 'employee_count', 'How many employees do you have?', 'integer', NULL, '{"min":1,"max":5000}', 'rating_input', 1002),
(2004, 101, 'building_ownership', 'Do you own or lease your building?', 'enum',
 '[{"code":"own","label":"Own"},{"code":"lease","label":"Lease"}]', NULL, 'rating_input', NULL),
(2005, 101, 'prior_claims_3yr', 'How many insurance claims have you filed in the last 3 years?', 'integer', NULL, '{"min":0,"max":50}', 'rating_input', NULL),
(2006, 101, 'liquor_sales_pct', 'What percentage of your sales comes from alcohol?', 'decimal', NULL, '{"min":0,"max":100}', 'rating_input', NULL),
(2007, 101, 'prior_claims_description', 'Briefly describe any claims in the last 3 years.', 'text', NULL, NULL, 'underwriting', NULL),
(2008, 101, 'how_did_you_hear', 'How did you hear about us?', 'enum',
 '[{"code":"search","label":"Search engine"},{"code":"referral","label":"Referral"},{"code":"partner","label":"A partner"},{"code":"other","label":"Other"}]', NULL, 'informational', NULL),
(2009, 101, 'hood_suppression', 'Do your cooking areas have a hood fire-suppression system?', 'boolean', NULL, NULL, 'underwriting', NULL);

INSERT INTO partner (id, name) VALUES
(1, 'Acme Restaurant Group'),
(2, 'Shieldline Pest Partners');

INSERT INTO program (id, name, partner_id, base_program_id) VALUES
(1, 'InsureNext Direct',  NULL, NULL),
(2, 'Acme Restaurants',   1,    1),
(3, 'Shieldline Pest Pros', 2,  1);

-- Versions start as drafts, get their question rows, then publish (bottom of the file).
-- Base v6 ran on rater 100 until 101 took over; v7 pins 101.
INSERT INTO program_version (id, program_id, version_no, status, rating_engine_version_id, base_program_version_id, effective_from, effective_to) VALUES
(60, 1, 6, 'draft', 100, NULL, '2026-01-01', '2026-10-01'),
(70, 1, 7, 'draft', 101, NULL, '2026-10-01', NULL),
(73, 2, 3, 'draft', 101, 70,   '2026-10-15', NULL),
(82, 3, 2, 'draft', 101, 70,   '2026-11-01', NULL);

-- Base v6 (rater 100)
INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, required, display_order) VALUES
(600, 60, 1001, 100, 'ask', true, 1),
(601, 60, 1002, 100, 'ask', true, 2);

-- Base v7: the full set.
INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, required, label, display_order) VALUES
(700, 70, 2001, 101, 'ask', true,  NULL, 1),
(701, 70, 2002, 101, 'ask', true,  NULL, 2),
(702, 70, 2003, 101, 'ask', true,  NULL, 3),
(703, 70, 2004, 101, 'ask', true,  NULL, 4),
(704, 70, 2005, 101, 'ask', true,  NULL, 5),
(705, 70, 2006, 101, 'ask', false, NULL, 6),
(706, 70, 2007, 101, 'ask', false, NULL, 7),
(707, 70, 2008, 101, 'ask', false, NULL, 8);

-- Acme Restaurants v3: only its differences from base v7.
INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, preset_value, required, label, option_labels, display_order) VALUES
(730, 73, 2001, 101, 'preset', 'restaurant', NULL, NULL, NULL, NULL),
(731, 73, 2003, 101, 'ask',    NULL, NULL, 'How many people work at your restaurant, including part-time staff?', NULL, NULL),
(732, 73, 2004, 101, 'ask',    NULL, NULL, NULL, '{"own":"We own the building","lease":"We lease our space"}', NULL),
(733, 73, 2006, 101, 'ask',    NULL, true, 'Roughly what share of your sales is beer, wine and spirits?', NULL, NULL),
(734, 73, 2008, 101, 'omit',   NULL, NULL, NULL, NULL, NULL),
(735, 73, 2009, 101, 'ask',    NULL, true, NULL, NULL, 7);

-- Shieldline Pest Pros v2: only its differences from base v7.
INSERT INTO program_version_question (id, program_version_id, question_id, rating_engine_version_id, mode, preset_value, required, label, validation, display_order) VALUES
(820, 82, 2001, 101, 'preset', 'pest_control', NULL, NULL, NULL, NULL),
(821, 82, 2002, 101, 'ask',    NULL, NULL, 'Annual revenue (this program covers businesses up to $5M)', '{"min":0,"max":5000000}', NULL),
(822, 82, 2003, 101, 'ask',    NULL, NULL, 'Total headcount, full and part-time', NULL, NULL),
(823, 82, 2006, 101, 'omit',   NULL, NULL, NULL, NULL, NULL),
(824, 82, 2008, 101, 'omit',   NULL, NULL, NULL, NULL, NULL);

-- Publish. From here on, the versions and their question rows are frozen.
UPDATE program_version SET status = 'superseded' WHERE id = 60;
UPDATE program_version SET status = 'published'  WHERE id IN (70, 73, 82);

-- One application under Acme Restaurants, with a preset and two answers.
INSERT INTO application (id, program_version_id, rating_engine_version_id, channel) VALUES
(5001, 73, 101, 'partner_api');
INSERT INTO application_answer (application_id, question_id, answer_text, source) VALUES
(5001, 2001, 'restaurant', 'preset'),
(5001, 2003, '14',         'partner_api'),
(5001, 2004, 'lease',      'partner_api');
