import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
require('reflect-metadata');
const { TasksService } = require('../dist/tasks/tasks.service.js');

const now = new Date('2026-09-16T10:00:00Z');

function row(revision, overrides = {}) {
  return {
    id: 'task-1',
    title: 'Task',
    note: '',
    status: 'todo',
    priority: 2,
    important: false,
    sort_order: '1000',
    due_at: null,
    completed_at: null,
    created_at: now,
    updated_at: now,
    deleted_at: null,
    version: 1,
    revision: String(revision),
    ...overrides,
  };
}

test('sync cursor advances only through changes in the response', async () => {
  const queries = [];
  let rows = [row(7)];
  const service = new TasksService({
    query: async (sql) => {
      queries.push(sql);
      return { rows };
    },
  });

  const first = await service.sync(5);
  assert.equal(first.latestRevision, 7);
  assert.equal(first.changes[0].revision, 7);

  rows = [];
  const second = await service.sync(7);
  assert.equal(second.latestRevision, 7);
  assert.equal(queries.length, 2, 'sync must not query a later max revision');
});

test('each task write locks before allocating a revision', async () => {
  for (const operation of ['create', 'update', 'remove']) {
    const statements = [];
    const client = {
      query: async (sql) => {
        statements.push(sql);
        if (sql.includes('next_order')) return { rows: [{ next_order: '1000' }] };
        if (sql.includes('SELECT id, title')) return { rows: [row(1)], rowCount: 1 };
        return { rows: [row(2)], rowCount: 1 };
      },
    };
    const service = new TasksService({
      transaction: async (work) => work(client),
      notifyTaskChanged: async (_client, revision) => {
        statements.push(`NOTIFY ${revision}`);
      },
    });

    if (operation === 'create') await service.create({ title: 'Task' });
    if (operation === 'update') await service.update('task-1', { version: 1 });
    if (operation === 'remove') await service.remove('task-1', 1);

    assert.match(statements[0], /pg_advisory_xact_lock/);
    assert.ok(statements.some((sql) => sql.includes("nextval('task_revision_seq')")));
    assert.equal(statements.at(-1), 'NOTIFY 2');
  }
});
