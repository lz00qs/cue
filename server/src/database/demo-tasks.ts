import { Pool, PoolClient } from 'pg';

const taskChangeChannel = 'cue_task_changes';
const taskWriteLock = 1987737485;
const maxTaskCount = 500;
const maxDateRangeDays = 365;
const batchPattern = /^[A-Za-z0-9][A-Za-z0-9_-]{0,47}$/;

const titleTemplates = [
  'Review project brief',
  'Prepare weekly update',
  'Check release checklist',
  'Organize research notes',
  'Follow up with supplier',
  'Plan design review',
  'Validate test results',
  'Update technical documentation',
  'Schedule team sync',
  'Refine implementation plan',
  'Inspect performance metrics',
  'Triage incoming feedback',
];

const groups: Array<string | null> = ['Work', 'Personal', 'Learning', null];
const priorityPool = [0, 1, 1, 2, 2, 2, 3, 3, 3, 3];

export interface DemoTaskOptions {
  batch: string;
  count: number;
  seed: number;
  days: number;
  referenceDate: Date;
}

export interface GeneratedDemoTask {
  id: string;
  title: string;
  note: string;
  priority: number;
  sortOrder: number;
  dueAt: Date | null;
  completedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  group: string | null;
}

interface QueryRow {
  revision: string;
}

interface CountRow {
  count: string;
}

function createRandom(seed: number) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function randomInt(random: () => number, minimum: number, maximum: number) {
  return Math.floor(random() * (maximum - minimum + 1)) + minimum;
}

function addLocalDays(date: Date, days: number) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function startOfLocalDay(date: Date) {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}

export function generateDemoTasks(options: DemoTaskOptions) {
  validateOptions(options);
  const random = createRandom(options.seed);
  const referenceDay = startOfLocalDay(options.referenceDate);
  const tasks: GeneratedDemoTask[] = [];

  for (let index = 0; index < options.count; index += 1) {
    const createdDaysAgo = randomInt(random, 0, Math.min(options.days, 30));
    const createdAt = addLocalDays(
      options.referenceDate,
      -createdDaysAgo,
    );
    const priority = priorityPool[randomInt(random, 0, priorityPool.length - 1)];
    const hasDueDate = random() >= 0.15;
    let dueAt: Date | null = null;
    if (hasDueDate) {
      dueAt = addLocalDays(
        referenceDay,
        randomInt(random, -options.days, options.days),
      );
      dueAt.setHours(
        randomInt(random, 8, 20),
        [0, 15, 30, 45][randomInt(random, 0, 3)],
        0,
        0,
      );
    }

    const isCompleted = random() < 0.2;
    const completedAt = isCompleted
      ? addLocalDays(options.referenceDate, -randomInt(random, 0, createdDaysAgo))
      : null;
    const number = String(index + 1).padStart(3, '0');
    const template = titleTemplates[randomInt(random, 0, titleTemplates.length - 1)];
    const group = groups[randomInt(random, 0, groups.length - 1)];

    tasks.push({
      id: `demo:${options.batch}:${number}`,
      title: `${template} #${number}`,
      note: `Generated demo data (batch: ${options.batch})`,
      priority,
      sortOrder: (index + 1) * 1000,
      dueAt,
      completedAt,
      createdAt,
      updatedAt: completedAt ?? createdAt,
      group,
    });
  }

  return tasks;
}

function validateOptions(options: DemoTaskOptions) {
  if (!batchPattern.test(options.batch)) {
    throw new Error(
      'Batch must start with a letter or number and contain only letters, numbers, _ or - (max 48 characters)',
    );
  }
  if (!Number.isInteger(options.count) || options.count < 1 || options.count > maxTaskCount) {
    throw new Error(`Count must be an integer between 1 and ${maxTaskCount}`);
  }
  if (!Number.isInteger(options.seed) || options.seed < 0 || options.seed > 0xffffffff) {
    throw new Error('Seed must be an integer between 0 and 4294967295');
  }
  if (!Number.isInteger(options.days) || options.days < 1 || options.days > maxDateRangeDays) {
    throw new Error(`Days must be an integer between 1 and ${maxDateRangeDays}`);
  }
  if (Number.isNaN(options.referenceDate.getTime())) {
    throw new Error('Reference date must be a valid ISO-8601 date');
  }
}

function hashBatch(batch: string) {
  let hash = 2166136261;
  for (const character of batch) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function readOption(args: string[], name: string) {
  const index = args.indexOf(name);
  if (index === -1) return undefined;
  const value = args[index + 1];
  if (value == null || value.startsWith('--')) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parseInteger(value: string | undefined, fallback: number, name: string) {
  if (value == null) return fallback;
  if (!/^\d+$/.test(value)) throw new Error(`${name} must be an integer`);
  return Number(value);
}

function requireBatch(args: string[]) {
  const batch = readOption(args, '--batch');
  if (!batch) throw new Error('--batch is required');
  if (!batchPattern.test(batch)) {
    throw new Error(
      'Batch must start with a letter or number and contain only letters, numbers, _ or - (max 48 characters)',
    );
  }
  return batch;
}

function ensureDemoDataAllowed() {
  if (process.env.NODE_ENV === 'production' && process.env.CUE_ALLOW_DEMO_DATA !== 'true') {
    throw new Error(
      'Demo data commands are disabled in production. Set CUE_ALLOW_DEMO_DATA=true for this command only.',
    );
  }
}

async function withTransaction<T>(
  pool: Pool,
  work: (client: PoolClient) => Promise<T>,
) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function seed(pool: Pool, args: string[]) {
  const batch = requireBatch(args);
  const options: DemoTaskOptions = {
    batch,
    count: parseInteger(readOption(args, '--count'), 40, '--count'),
    seed: parseInteger(readOption(args, '--seed'), hashBatch(batch), '--seed'),
    days: parseInteger(readOption(args, '--days'), 30, '--days'),
    referenceDate: new Date(readOption(args, '--reference-date') ?? Date.now()),
  };
  const tasks = generateDemoTasks(options);

  await withTransaction(pool, async (client) => {
    await client.query(`SELECT pg_advisory_xact_lock(${taskWriteLock}::bigint)`);
    const prefix = `demo:${batch}:`;
    const existing = await client.query<CountRow>(
      'SELECT COUNT(*) AS count FROM tasks WHERE left(id, length($1)) = $1',
      [prefix],
    );
    if (Number(existing.rows[0].count) > 0) {
      throw new Error(
        `Demo batch "${batch}" already exists, including deleted tombstones. Choose a new batch name.`,
      );
    }

    const orderResult = await client.query<{ next_order: string }>(
      `SELECT COALESCE(MAX(sort_order), 0) + 1000 AS next_order
       FROM tasks WHERE deleted_at IS NULL`,
    );
    const firstOrder = Number(orderResult.rows[0].next_order);
    let latestRevision = 0;

    for (const [index, task] of tasks.entries()) {
      const result = await client.query<QueryRow>(
        `INSERT INTO tasks (
           id, title, note, priority, important, sort_order, due_at,
           reminder, recurrence, "group", completed_at, created_at, updated_at,
           version, revision
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7,
           NULL, NULL, $8, $9, $10, $11, 1, nextval('task_revision_seq')
         )
         RETURNING revision`,
        [
          task.id,
          task.title,
          task.note,
          task.priority,
          task.priority === 0,
          firstOrder + index * 1000,
          task.dueAt,
          task.group,
          task.completedAt,
          task.createdAt,
          task.updatedAt,
        ],
      );
      latestRevision = Math.max(latestRevision, Number(result.rows[0].revision));
    }

    await client.query('SELECT pg_notify($1, $2)', [
      taskChangeChannel,
      String(latestRevision),
    ]);
  });

  process.stdout.write(
    `Created ${tasks.length} demo tasks in batch "${batch}" (seed ${options.seed}).\n`,
  );
}

async function clear(pool: Pool, args: string[]) {
  const clearAll = args.includes('--all');
  const batchArgument = readOption(args, '--batch');
  if (clearAll === Boolean(batchArgument)) {
    throw new Error('Specify exactly one of --batch <name> or --all');
  }
  const batch = batchArgument ? requireBatch(args) : null;

  const removed = await withTransaction(pool, async (client) => {
    await client.query(`SELECT pg_advisory_xact_lock(${taskWriteLock}::bigint)`);
    const values: unknown[] = [];
    const condition = batch
      ? 'left(id, length($1)) = $1'
      : `id LIKE 'demo:%'`;
    if (batch) values.push(`demo:${batch}:`);
    const result = await client.query<QueryRow>(
      `UPDATE tasks
       SET deleted_at = NOW(), updated_at = NOW(), version = version + 1,
           revision = nextval('task_revision_seq')
       WHERE deleted_at IS NULL AND ${condition}
       RETURNING revision`,
      values,
    );
    const latestRevision = result.rows.reduce(
      (latest, row) => Math.max(latest, Number(row.revision)),
      0,
    );
    if (latestRevision > 0) {
      await client.query('SELECT pg_notify($1, $2)', [
        taskChangeChannel,
        String(latestRevision),
      ]);
    }
    return result.rowCount ?? 0;
  });

  process.stdout.write(
    `Removed ${removed} active demo tasks${batch ? ` from batch "${batch}"` : ''}.\n`,
  );
}

async function main() {
  ensureDemoDataAllowed();
  if (!process.env.DATABASE_URL && !process.env.PGHOST) {
    throw new Error('DATABASE_URL or PostgreSQL PG* variables are required');
  }
  const command = process.argv[2];
  const args = process.argv.slice(3);
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    if (command === 'seed') {
      await seed(pool, args);
    } else if (command === 'clear') {
      await clear(pool, args);
    } else {
      throw new Error('Expected command: seed or clear');
    }
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  void main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : error}\n`);
    process.exitCode = 1;
  });
}
