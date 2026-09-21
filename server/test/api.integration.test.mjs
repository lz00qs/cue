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
  assert.equal(created.completedAt, null);
  assert.equal('status' in created, false);

  const completedAt = new Date().toISOString();
  const updatedResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ version: created.version, completedAt }),
  });
  assert.equal(updatedResponse.status, 200);
  const updated = await updatedResponse.json();
  assert.equal(updated.completedAt, completedAt);
  assert.equal('status' in updated, false);
  assert.equal(updated.version, 2);

  const reopenedResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ version: updated.version, completedAt: null }),
  });
  assert.equal(reopenedResponse.status, 200);
  const reopened = await reopenedResponse.json();
  assert.equal(reopened.completedAt, null);
  assert.equal(reopened.version, 3);

  const deletedResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'DELETE',
    headers,
    body: JSON.stringify({ version: reopened.version }),
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

test('SSE announces a committed task revision', { skip: !baseUrl }, async () => {
  const login = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  assert.equal(login.status, 201);
  const { accessToken } = await login.json();
  const headers = {
    authorization: `Bearer ${accessToken}`,
    'content-type': 'application/json',
  };
  const denied = await fetch(`${baseUrl}/api/sync/events`);
  assert.equal(denied.status, 401);

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 10000);
  let created;
  try {
    const response = await fetch(`${baseUrl}/api/sync/events`, {
      headers,
      signal: abort.signal,
    });
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type') ?? '', /text\/event-stream/);
    const reader = response.body.getReader();

    const createdResponse = await fetch(`${baseUrl}/api/tasks`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ title: `SSE ${Date.now()}`, priority: 2 }),
    });
    assert.equal(createdResponse.status, 201);
    created = await createdResponse.json();

    const decoder = new TextDecoder();
    let buffer = '';
    let announced;
    while (announced == null) {
      const { value, done } = await reader.read();
      assert.equal(done, false, 'SSE stream closed before the task event');
      buffer += decoder.decode(value, { stream: true });
      const frames = buffer.split(/\r?\n\r?\n/);
      buffer = frames.pop();
      for (const frame of frames) {
        if (!frame.includes('event: change')) continue;
        const data = frame.split(/\r?\n/).find((line) => line.startsWith('data:'));
        if (data) announced = JSON.parse(data.slice(5).trim()).revision;
      }
    }
    assert.equal(announced, created.revision);
  } finally {
    abort.abort();
    clearTimeout(timeout);
    if (created) {
      await fetch(`${baseUrl}/api/tasks/${created.id}`, {
        method: 'DELETE',
        headers,
        body: JSON.stringify({ version: created.version }),
      });
    }
  }
});
