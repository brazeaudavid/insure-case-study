// Interactive SQL shell over the demo database (schema.sql + seed.sql in an in-memory PGlite).
//   node repl.mjs
// End each statement with ";". Type \q to quit, \reset to reload a fresh database.
// Nothing is saved: every run starts from the seed.
import { readFile } from 'node:fs/promises';
import readline from 'node:readline';
import { PGlite } from '@electric-sql/pglite';
import { btree_gist } from '@electric-sql/pglite/contrib/btree_gist';

const here = (f) => new URL(f, import.meta.url);
async function fresh() {
  const db = new PGlite({ extensions: { btree_gist } });
  await db.exec(await readFile(here('schema.sql'), 'utf8'));
  await db.exec(await readFile(here('seed.sql'), 'utf8'));
  return db;
}

let db = await fresh();
console.log('Demo database loaded (schema.sql + seed.sql). End statements with ";". \\q quits, \\reset reloads.');
console.log('Try: SELECT * FROM program_question_resolved WHERE program_version_id = 73;\n');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: 'demo=> ' });
let buf = '';
let queue = Promise.resolve();   // run lines strictly in order, even when input is pasted or piped

async function handle(line) {
  const t = line.trim();
  if (!buf && t === '\\q') { rl.close(); return; }
  if (!buf && t === '\\reset') { db = await fresh(); console.log('Reloaded.'); return rl.prompt(); }
  buf += line + '\n';
  if (!t.endsWith(';')) { rl.setPrompt('demo-> '); return rl.prompt(); }
  const sql = buf; buf = '';
  try {
    for (const r of await db.exec(sql)) {
      if (r.fields.length) console.table(r.rows);
      else console.log(`OK${r.affectedRows != null ? ` (${r.affectedRows} rows)` : ''}`);
    }
  } catch (e) {
    console.log(`\x1b[31mERROR\x1b[0m ${e.constraint ? e.constraint + ': ' : ''}${e.message}`);
  }
  rl.setPrompt('demo=> ');
  rl.prompt();
}

rl.prompt();
rl.on('line', (line) => { queue = queue.then(() => handle(line)); });
rl.on('close', () => queue.then(() => process.exit(0)));
