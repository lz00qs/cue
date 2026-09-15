import assert from 'node:assert/strict';

const baseUrl = process.env.CUE_TEST_URL;
const email = process.env.CUE_TEST_EMAIL;
const password = process.env.CUE_TEST_PASSWORD;
const phase = process.env.CUE_TEST_PHASE;
const title = 'Cue persistence verification marker';

assert.ok(baseUrl && email && password);
assert.ok(phase === 'create' || phase === 'verify');

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

if (phase === 'create') {
  const response = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ title, priority: 3, dueAt: null }),
  });
  assert.equal(response.status, 201);
  process.stdout.write('Persistence marker created\n');
} else {
  const response = await fetch(`${baseUrl}/api/tasks`, { headers });
  assert.equal(response.status, 200);
  const tasks = await response.json();
  const markers = tasks.filter((task) => task.title === title);
  assert.ok(markers.length > 0, 'marker must survive the API restart');
  for (const marker of markers) {
    const deleted = await fetch(`${baseUrl}/api/tasks/${marker.id}`, {
      method: 'DELETE',
      headers,
      body: JSON.stringify({ version: marker.version }),
    });
    assert.equal(deleted.status, 200);
  }
  process.stdout.write('Persistence marker verified and cleaned up\n');
}
