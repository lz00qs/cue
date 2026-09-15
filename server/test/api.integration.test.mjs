import assert from 'node:assert/strict';
import test from 'node:test';

const baseUrl = process.env.CUE_TEST_URL;
const email = process.env.CUE_TEST_EMAIL;
const password = process.env.CUE_TEST_PASSWORD;

test('login, task CRUD and tombstone sync', { skip: !baseUrl }, async () => {
  const login = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  assert.equal(login.status, 201);
  const tokens = await login.json();
  assert.ok(tokens.accessToken);
  assert.ok(tokens.refreshToken);

  const refreshedResponse = await fetch(`${baseUrl}/api/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refreshToken: tokens.refreshToken }),
  });
  assert.equal(refreshedResponse.status, 201);
  const refreshed = await refreshedResponse.json();
  assert.ok(refreshed.accessToken);

  const headers = {
    authorization: `Bearer ${refreshed.accessToken}`,
    'content-type': 'application/json',
  };

  const unauthorized = await fetch(`${baseUrl}/api/tasks`);
  assert.equal(unauthorized.status, 401);

  const createdResponse = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ title: `Integration ${Date.now()}`, priority: 1 }),
  });
  assert.equal(createdResponse.status, 201);
  const created = await createdResponse.json();
  assert.equal(created.version, 1);

  const updatedResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ version: created.version, status: 'doing' }),
  });
  assert.equal(updatedResponse.status, 200);
  const updated = await updatedResponse.json();
  assert.equal(updated.status, 'doing');
  assert.equal(updated.version, 2);

  const deletedResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'DELETE',
    headers,
    body: JSON.stringify({ version: updated.version }),
  });
  assert.equal(deletedResponse.status, 200);
  const deleted = await deletedResponse.json();
  assert.ok(deleted.deletedAt);

  const syncResponse = await fetch(
    `${baseUrl}/api/sync?since=${created.revision - 1}`,
    { headers },
  );
  assert.equal(syncResponse.status, 200);
  const sync = await syncResponse.json();
  const tombstone = sync.changes.find((task) => task.id === created.id);
  assert.ok(tombstone.deletedAt);
  assert.ok(sync.latestRevision >= tombstone.revision);
});
