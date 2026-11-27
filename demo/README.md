# Demo: partner programs, questions and the partner contract

The build artifact for the case study. It brings two parts of the design to life, using one rater version (101) with a base program and two partner programs.

## The walkthrough page (`index.html`)

Open the published link, or open `index.html` in a browser. No server or install is needed.

1. **Same question, different wording.** Switch between programs. The form wording changes, and the rows behind it show which wording comes from the partner and which from the base version. The rater payload keeps the same keys and codes.
2. **The partner contract.** The program's JSON Schema is generated from the same rows. Send the clean, junk or incomplete sample, or edit the request yourself. Junk comes back as one `422` response with every field error. A valid request shows the answer rows that would be stored, presets included.

The page logic mirrors `schema.sql` and `seed.sql`: question-set resolution (partner overlays on the base), answer validation, schema generation.

## The database (`schema.sql`, `seed.sql`, `try-to-break-it.mjs`)

The question part of the data model, with its real constraints: composite FKs that keep everything on one rater version, immutability triggers, narrow-only checks, the no-overlap exclusion constraint, and the `program_question_resolved` view.

```
npm install
node try-to-break-it.mjs
```

This runs on PGlite, which is Postgres compiled to WebAssembly, so you don't need a Postgres server or Docker. The script prints the same question in all three programs, tries 12 writes the design forbids and shows each one refused, then rewords a question the allowed way (a new program version) and shows that the old version keeps its wording.

To run your own SQL against the same database, use `npm run sql` (`node repl.mjs`). End each statement with `;`. `\reset` reloads a fresh copy, and `\q` quits. Nothing is saved between runs.

To load the files into a real Postgres instead: `psql -f schema.sql -f seed.sql` (it needs `btree_gist`).

The partners, wording and data are invented.
