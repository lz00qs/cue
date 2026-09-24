import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
require('reflect-metadata');
const { compare, hash } = require('bcryptjs');

test('AuthService unit test suite', async (t) => {
  // We can test after build dist is generated, or test dynamic logic
  let AuthService;
  let AuthController;
  try {
    const authModule = await import('../dist/auth/auth.service.js');
    AuthService = authModule.AuthService;
    const controllerModule = await import('../dist/auth/auth.controller.js');
    AuthController = controllerModule.AuthController;
  } catch {
    // If not built yet, skip or load directly if possible
  }

  await t.test('setup status is unavailable through the HTTPS entry', { skip: !AuthController }, async () => {
    const controller = new AuthController({
      isInitialized: async () => false,
      isSetupAvailable: () => true,
    });
    assert.deepEqual(await controller.status('https'), {
      initialized: false,
      setupAvailable: false,
    });
    assert.deepEqual(await controller.status('http'), {
      initialized: false,
      setupAvailable: true,
    });
    assert.deepEqual(await controller.status('http, HTTPS'), {
      initialized: false,
      setupAvailable: false,
    });
    assert.throws(
      () => controller.setup({ email: 'admin@cue.local', password: 'password-123' }, 'https'),
      /Admin setup is unavailable over HTTPS/,
    );
  });

  await t.test('isInitialized returns false when users table is empty', { skip: !AuthService }, async () => {
    const mockDb = {
      query: async (sql) => {
        if (sql.includes('COUNT(*)')) {
          return { rows: [{ count: '0' }] };
        }
        return { rows: [] };
      },
    };
    const mockJwt = {
      signAsync: async () => 'test-token',
    };
    const service = new AuthService(mockDb, mockJwt);
    assert.equal(await service.isInitialized(), false);
  });

  await t.test('isInitialized returns true when user exists', { skip: !AuthService }, async () => {
    const mockDb = {
      query: async (sql) => {
        if (sql.includes('COUNT(*)')) {
          return { rows: [{ count: '1' }] };
        }
        return { rows: [] };
      },
    };
    const mockJwt = {
      signAsync: async () => 'test-token',
    };
    const service = new AuthService(mockDb, mockJwt);
    assert.equal(await service.isInitialized(), true);
  });

  await t.test('setup hashes password, inserts user, and issues tokens', { skip: !AuthService }, async () => {
    const previousAllowSetup = process.env.CUE_ALLOW_SETUP;
    process.env.CUE_ALLOW_SETUP = 'true';
    try {
      let inserted;
      const mockDb = {
        query: async (sql, params) => {
          if (sql.includes('COUNT(*)')) {
            return { rows: [{ count: inserted ? '1' : '0' }] };
          }
          if (sql.includes('INSERT INTO users')) {
            inserted = { id: params[0], email: params[1], passwordHash: params[2] };
            return { rows: [{ id: 'admin' }], rowCount: 1 };
          }
          return { rows: [] };
        },
      };
      const mockJwt = {
        signAsync: async (payload) => `signed-${payload.kind}-${payload.email}`,
      };
      const service = new AuthService(mockDb, mockJwt);

      const result = await service.setup('Admin@Cue.local', 'Secret-Password-123');
      assert.equal(result.user.email, 'admin@cue.local');
      assert.ok(result.accessToken.includes('access'));
      assert.ok(result.refreshToken.includes('refresh'));
      assert.equal(inserted.email, 'admin@cue.local');
      assert.ok(await compare('Secret-Password-123', inserted.passwordHash));

      // Trying to setup again should fail
      await assert.rejects(
        () => service.setup('another@cue.local', 'Another-Password-123'),
        /Admin account has already been set up/,
      );
    } finally {
      if (previousAllowSetup === undefined) delete process.env.CUE_ALLOW_SETUP;
      else process.env.CUE_ALLOW_SETUP = previousAllowSetup;
    }
  });

  await t.test('setup is disabled by default even with an empty database', { skip: !AuthService }, async () => {
    const previousAllowSetup = process.env.CUE_ALLOW_SETUP;
    delete process.env.CUE_ALLOW_SETUP;
    try {
      let queries = 0;
      const service = new AuthService({
        query: async () => {
          queries++;
          return { rows: [{ count: '0' }] };
        },
      }, { signAsync: async () => 'test-token' });
      assert.equal(service.isSetupAvailable(false), false);
      await assert.rejects(
        () => service.setup('admin@cue.local', 'Secret-Password-123'),
        /Admin setup is disabled/,
      );
      assert.equal(queries, 0);
    } finally {
      if (previousAllowSetup === undefined) delete process.env.CUE_ALLOW_SETUP;
      else process.env.CUE_ALLOW_SETUP = previousAllowSetup;
    }
  });

  await t.test('a concurrent setup cannot receive tokens after losing the insert', { skip: !AuthService }, async () => {
    const previousAllowSetup = process.env.CUE_ALLOW_SETUP;
    process.env.CUE_ALLOW_SETUP = 'true';
    try {
      let tokensIssued = 0;
      const service = new AuthService({
        query: async (sql) => sql.includes('COUNT(*)')
          ? { rows: [{ count: '0' }] }
          : { rows: [], rowCount: 0 },
      }, {
        signAsync: async () => {
          tokensIssued++;
          return 'test-token';
        },
      });
      assert.equal(service.isSetupAvailable(false), true);
      assert.equal(service.isSetupAvailable(true), false);
      await assert.rejects(
        () => service.setup('admin@cue.local', 'Secret-Password-123'),
        /Admin account has already been set up/,
      );
      assert.equal(tokensIssued, 0);
    } finally {
      if (previousAllowSetup === undefined) delete process.env.CUE_ALLOW_SETUP;
      else process.env.CUE_ALLOW_SETUP = previousAllowSetup;
    }
  });

  await t.test('login verifies password from database', { skip: !AuthService }, async () => {
    const passwordHash = await hash('ValidPassword123', 10);
    const mockDb = {
      query: async (sql, params) => {
        if (sql.includes('SELECT id, email, password_hash FROM users')) {
          if (params[0].toLowerCase() === 'admin@cue.local') {
            return {
              rows: [{ id: 'admin', email: 'admin@cue.local', password_hash: passwordHash }],
            };
          }
        }
        return { rows: [] };
      },
    };
    const mockJwt = {
      signAsync: async (payload) => `token-${payload.kind}`,
    };
    const service = new AuthService(mockDb, mockJwt);

    // Valid login
    const result = await service.login('ADMIN@CUE.LOCAL', 'ValidPassword123');
    assert.equal(result.user.email, 'admin@cue.local');

    // Invalid password
    await assert.rejects(
      () => service.login('admin@cue.local', 'WrongPassword!'),
      /Invalid email or password/,
    );

    // Unknown user
    await assert.rejects(
      () => service.login('unknown@cue.local', 'ValidPassword123'),
      /Invalid email or password/,
    );
  });

  await t.test('updateAccount verifies the current password and replaces credentials', { skip: !AuthService }, async () => {
    const passwordHash = await hash('CurrentPassword123', 10);
    let updated;
    const mockDb = {
      query: async (sql, params) => {
        if (sql.includes('ORDER BY created_at')) {
          return {
            rows: [{
              id: 'admin',
              email: 'admin@cue.local',
              password_hash: passwordHash,
            }],
          };
        }
        if (sql.includes('UPDATE users')) {
          updated = {
            email: params[0],
            passwordHash: params[1],
            id: params[2],
          };
        }
        return { rows: [] };
      },
    };
    const mockJwt = {
      signAsync: async (payload) => `token-${payload.kind}-${payload.email}`,
    };
    const service = new AuthService(mockDb, mockJwt);

    const result = await service.updateAccount(
      'CurrentPassword123',
      'NEW@Cue.Local',
      'ReplacementPassword123',
    );
    assert.equal(result.user.email, 'new@cue.local');
    assert.equal(updated.email, 'new@cue.local');
    assert.equal(updated.id, 'admin');
    assert.ok(await compare('ReplacementPassword123', updated.passwordHash));
    assert.match(result.refreshToken, /new@cue\.local/);

    await assert.rejects(
      () => service.updateAccount('WrongPassword123', 'other@cue.local'),
      /Current password is incorrect/,
    );
  });
});
