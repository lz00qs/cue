import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const { generateDemoTasks } = require('../dist/database/demo-tasks.js');

const options = {
  batch: 'ui-test-01',
  count: 100,
  seed: 20260923,
  days: 30,
  referenceDate: new Date('2026-09-23T12:00:00+08:00'),
};

test('demo task generation is deterministic and batch-scoped', () => {
  const first = generateDemoTasks(options);
  const second = generateDemoTasks(options);

  assert.deepEqual(first, second);
  assert.equal(first.length, options.count);
  assert.equal(new Set(first.map((task) => task.id)).size, options.count);
  assert.ok(first.every((task) => task.id.startsWith('demo:ui-test-01:')));
  assert.ok(first.every((task) => task.note.includes('batch: ui-test-01')));
});

test('demo tasks cover supported priorities and bounded relative dates', () => {
  const tasks = generateDemoTasks(options);
  const priorities = new Set(tasks.map((task) => task.priority));
  assert.deepEqual([...priorities].sort(), [0, 1, 2, 3]);

  const minimum = new Date(options.referenceDate);
  minimum.setHours(0, 0, 0, 0);
  minimum.setDate(minimum.getDate() - options.days);
  const maximum = new Date(options.referenceDate);
  maximum.setHours(23, 59, 59, 999);
  maximum.setDate(maximum.getDate() + options.days);

  const dated = tasks.filter((task) => task.dueAt != null);
  assert.ok(dated.length > 0);
  assert.ok(dated.every((task) => task.dueAt >= minimum && task.dueAt <= maximum));
  assert.ok(tasks.some((task) => task.dueAt == null));
  assert.ok(tasks.some((task) => task.completedAt != null));
  assert.ok(
    tasks.every(
      (task) => task.completedAt == null || task.completedAt >= task.createdAt,
    ),
  );
});

test('demo task generation rejects unsafe batch names', () => {
  assert.throws(
    () => generateDemoTasks({ ...options, batch: 'bad:%' }),
    /Batch must start/,
  );
});
