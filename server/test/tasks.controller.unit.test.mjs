import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
require('reflect-metadata');
const { Subject } = require('rxjs');
const { TasksController } = require('../dist/tasks/tasks.controller.js');

test('SSE subscribes before ready and broadcasts new revisions', () => {
  const changes = new Subject();
  const controller = new TasksController({
    watchRevisions: () => changes.asObservable(),
  });
  const messages = [];
  const subscription = controller.events().subscribe((message) => {
    messages.push(message);
  });

  changes.next(9);
  assert.deepEqual(messages, [
    { type: 'ready', data: {} },
    { type: 'change', data: { revision: 9 } },
  ]);
  subscription.unsubscribe();
  assert.equal(changes.observed, false);
});
