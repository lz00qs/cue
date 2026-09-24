import { hash } from 'bcryptjs';
import { Pool } from 'pg';

async function resetPassword() {
  const args = process.argv.slice(2).filter((arg) => !arg.startsWith('-'));
  const newPassword = args[0];
  const newEmail = args[1];

  if (
    !newPassword ||
    newPassword.length < 8 ||
    Buffer.byteLength(newPassword, 'utf8') > 72
  ) {
    process.stderr.write(
      'Usage: npm run reset-password -- <new-password> [new-email]\n' +
      'Password must be 8 or more characters and at most 72 UTF-8 bytes.\n',
    );
    process.exitCode = 1;
    return;
  }

  if (!process.env.DATABASE_URL && !process.env.PGHOST) {
    throw new Error('DATABASE_URL or PostgreSQL PG* variables are required');
  }

  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const existing = await pool.query<{ id: string; email: string }>(
      'SELECT id, email FROM users ORDER BY created_at ASC LIMIT 1;',
    );

    const passwordHash = await hash(newPassword, 12);

    if (existing.rows.length === 0) {
      const email = (newEmail || 'admin@cue.local').trim().toLowerCase();
      await pool.query(
        `INSERT INTO users (id, email, password_hash, created_at, updated_at)
         VALUES ($1, $2, $3, NOW(), NOW());`,
        ['admin', email, passwordHash],
      );
      process.stdout.write(`Created administrator account with email: ${email}\n`);
    } else {
      const user = existing.rows[0];
      const email = newEmail ? newEmail.trim().toLowerCase() : user.email;
      await pool.query(
        `UPDATE users SET password_hash = $1, email = $2, updated_at = NOW(),
                token_version = token_version + 1,
                failed_login_attempts = 0, last_failed_login_at = NULL,
                login_locked_until = NULL
         WHERE id = $3;`,
        [passwordHash, email, user.id],
      );
      await pool.query('DELETE FROM auth_sessions WHERE user_id = $1;', [user.id]);
      process.stdout.write(`Password successfully updated for administrator: ${email}\n`);
    }
  } finally {
    await pool.end();
  }
}

void resetPassword().catch((err: unknown) => {
  process.stderr.write(`${err instanceof Error ? err.stack : err}\n`);
  process.exitCode = 1;
});
