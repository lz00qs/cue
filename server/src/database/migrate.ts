import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { Pool } from 'pg';

async function migrate() {
  if (!process.env.DATABASE_URL && !process.env.PGHOST) {
    throw new Error('DATABASE_URL or PostgreSQL PG* variables are required');
  }
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const sql = await readFile(
      join(process.cwd(), 'migrations', '001_initial.sql'),
      'utf8',
    );
    await pool.query(sql);
    process.stdout.write('Database migration complete\n');
  } finally {
    await pool.end();
  }
}

void migrate().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.stack : error}\n`);
  process.exitCode = 1;
});
