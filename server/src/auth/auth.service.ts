import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { compare, hash } from 'bcryptjs';
import { randomUUID } from 'node:crypto';

import { DatabaseService } from '../database/database.service';

type TokenKind = 'access' | 'refresh';

interface CueTokenPayload {
  sub: 'single-user';
  email: string;
  kind: TokenKind;
  version: number;
  sessionId: string;
  refreshId?: string;
}

interface UserCredentials {
  id: string;
  email: string;
  password_hash: string;
  token_version: number;
  failed_login_attempts: number;
  last_failed_login_at: Date | null;
  login_locked_until: Date | null;
}

const loginWindowMs = 15 * 60 * 1000;
const maxFailedLogins = 5;

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly jwtSecret = process.env.CUE_JWT_SECRET ?? '';
  private readonly refreshSecret =
    process.env.CUE_REFRESH_SECRET ?? this.jwtSecret;
  private readonly allowSetup = process.env.CUE_ALLOW_SETUP === 'true';

  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
  ) {}

  async onModuleInit() {
    if (this.jwtSecret.length < 32) {
      throw new Error('CUE_JWT_SECRET must contain at least 32 characters');
    }
    if (
      this.refreshSecret.length < 32 ||
      this.refreshSecret === this.jwtSecret
    ) {
      throw new Error(
        'CUE_REFRESH_SECRET must be distinct and contain at least 32 characters',
      );
    }
  }

  isSetupAvailable(initialized: boolean) {
    return this.allowSetup && !initialized;
  }

  async isInitialized(): Promise<boolean> {
    const result = await this.db.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM users;',
    );
    return Number(result.rows[0]?.count ?? 0) > 0;
  }

  async setup(email: string, password: string) {
    if (!this.allowSetup) {
      throw new ForbiddenException('Admin setup is disabled');
    }
    const initialized = await this.isInitialized();
    if (initialized) {
      throw new ConflictException('Admin account has already been set up');
    }

    const cleanEmail = email.trim().toLowerCase();
    if (password.length < 8) {
      throw new ConflictException('Password must be at least 8 characters');
    }
    if (Buffer.byteLength(password, 'utf8') > 72) {
      throw new BadRequestException('Password must be at most 72 UTF-8 bytes');
    }

    const passwordHash = await hash(password, 12);
    const result = await this.db.query(
      `INSERT INTO users (id, email, password_hash, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())
       ON CONFLICT (id) DO NOTHING
       RETURNING id;`,
      ['admin', cleanEmail, passwordHash],
    );
    if (result.rowCount !== 1) {
      throw new ConflictException('Admin account has already been set up');
    }

    return this.issueTokens(cleanEmail, 0, 'admin');
  }

  async login(email: string, password: string) {
    const cleanEmail = email.trim().toLowerCase();
    const authenticated = await this.db.transaction(async (client) => {
      const result = await client.query<UserCredentials>(
        `SELECT id, email, password_hash, token_version,
                failed_login_attempts, last_failed_login_at, login_locked_until
         FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1 FOR UPDATE;`,
        [cleanEmail],
      );
      const user = result.rows[0];
      if (!user) return null;

      const now = new Date();
      if (user.login_locked_until && user.login_locked_until > now) return null;

      if (await compare(password, user.password_hash)) {
        await client.query(
          `UPDATE users SET failed_login_attempts = 0,
                  last_failed_login_at = NULL, login_locked_until = NULL
           WHERE id = $1;`,
          [user.id],
        );
        return { id: user.id, email: user.email, version: user.token_version };
      }

      const recentFailure =
        user.last_failed_login_at != null &&
        now.getTime() - user.last_failed_login_at.getTime() < loginWindowMs;
      const failures = recentFailure ? user.failed_login_attempts + 1 : 1;
      const lockedUntil =
        failures >= maxFailedLogins
          ? new Date(now.getTime() + loginWindowMs)
          : null;
      await client.query(
        `UPDATE users SET failed_login_attempts = $2,
                last_failed_login_at = $3, login_locked_until = $4
         WHERE id = $1;`,
        [user.id, failures, now, lockedUntil],
      );
      return null;
    });

    if (!authenticated) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.issueTokens(
      authenticated.email,
      authenticated.version,
      authenticated.id,
    );
  }

  async updateAccount(
    currentPassword: string,
    email?: string,
    newPassword?: string,
  ) {
    const result = await this.db.query<{
      id: string;
      email: string;
      password_hash: string;
      token_version: number;
    }>(
      'SELECT id, email, password_hash, token_version FROM users ORDER BY created_at ASC LIMIT 1;',
    );
    const user = result.rows[0];
    if (!user) {
      throw new UnauthorizedException('User no longer exists');
    }

    const validPassword = await compare(currentPassword, user.password_hash);
    if (!validPassword) {
      throw new ForbiddenException('Current password is incorrect');
    }

    const cleanEmail = email?.trim().toLowerCase();
    const emailChanged =
      cleanEmail != null && cleanEmail !== user.email.toLowerCase();
    const passwordChanged = newPassword != null && newPassword.length > 0;
    if (!emailChanged && !passwordChanged) {
      throw new BadRequestException('Enter a new email or password');
    }
    if (newPassword != null && newPassword.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }
    if (newPassword != null && Buffer.byteLength(newPassword, 'utf8') > 72) {
      throw new BadRequestException('Password must be at most 72 UTF-8 bytes');
    }

    const nextEmail = emailChanged ? cleanEmail! : user.email;
    const nextPasswordHash = passwordChanged
      ? await hash(newPassword!, 12)
      : user.password_hash;
    const updated = await this.db.query<{ token_version: number }>(
      `UPDATE users
       SET email = $1, password_hash = $2, updated_at = NOW(),
           token_version = token_version + 1,
           failed_login_attempts = 0, last_failed_login_at = NULL,
           login_locked_until = NULL
       WHERE id = $3 AND token_version = $4 RETURNING token_version;`,
      [nextEmail, nextPasswordHash, user.id, user.token_version],
    );
    if (updated.rowCount !== 1) {
      throw new ConflictException('Account changed before request completed');
    }
    await this.db.query('DELETE FROM auth_sessions WHERE user_id = $1;', [
      user.id,
    ]);

    // The login email is embedded in both token types. Returning a fresh pair
    // keeps this device signed in after an email change.
    return this.issueTokens(nextEmail, updated.rows[0].token_version, user.id);
  }

  async refresh(refreshToken: string) {
    let payload: CueTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<CueTokenPayload>(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    if (
      payload.sub !== 'single-user' ||
      payload.kind !== 'refresh' ||
      !payload.sessionId ||
      !payload.refreshId
    ) {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    const rotated = await this.db.transaction(async (client) => {
      const result = await client.query<{
        refresh_token_id: string;
        expires_at: Date;
        email: string;
        token_version: number;
      }>(
        `SELECT session.refresh_token_id, session.expires_at,
                users.email, users.token_version
         FROM auth_sessions AS session
         JOIN users ON users.id = session.user_id
         WHERE session.id = $1 FOR UPDATE OF session;`,
        [payload.sessionId],
      );
      const session = result.rows[0];
      if (
        !session ||
        session.refresh_token_id !== payload.refreshId ||
        session.expires_at <= new Date() ||
        session.email !== payload.email ||
        session.token_version !== payload.version
      ) {
        return null;
      }
      const nextRefreshId = randomUUID();
      const tokens = await this.signTokens(
        session.email,
        session.token_version,
        payload.sessionId,
        nextRefreshId,
      );
      await client.query(
        `UPDATE auth_sessions
         SET refresh_token_id = $2, expires_at = NOW() + INTERVAL '30 days'
         WHERE id = $1;`,
        [payload.sessionId, nextRefreshId],
      );
      return tokens;
    });
    if (!rotated) {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    return rotated;
  }

  async logout(refreshToken: string) {
    let payload: CueTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<CueTokenPayload>(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    if (
      payload.sub !== 'single-user' ||
      payload.kind !== 'refresh' ||
      !payload.sessionId ||
      !payload.refreshId
    ) {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    await this.db.query(
      'DELETE FROM auth_sessions WHERE id = $1 AND refresh_token_id = $2;',
      [payload.sessionId, payload.refreshId],
    );
  }

  async verifyAccess(accessToken: string) {
    let payload: CueTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<CueTokenPayload>(accessToken, {
        secret: this.jwtSecret,
      });
    } catch {
      throw new UnauthorizedException('Access token is invalid or expired');
    }
    if (
      payload.sub !== 'single-user' ||
      payload.kind !== 'access' ||
      !payload.sessionId
    ) {
      throw new UnauthorizedException('Access token is invalid or expired');
    }
    const result = await this.db.query<{ email: string; token_version: number }>(
      `SELECT users.email, users.token_version
       FROM auth_sessions AS session
       JOIN users ON users.id = session.user_id
       WHERE session.id = $1 AND session.expires_at > NOW();`,
      [payload.sessionId],
    );
    if (
      result.rows.length === 0 ||
      result.rows[0].email !== payload.email ||
      result.rows[0].token_version !== payload.version
    ) {
      throw new UnauthorizedException('Access token is invalid or expired');
    }
    return payload;
  }

  private async issueTokens(email: string, version: number, userId: string) {
    const sessionId = randomUUID();
    const refreshId = randomUUID();
    const tokens = await this.signTokens(email, version, sessionId, refreshId);
    await this.db.query('DELETE FROM auth_sessions WHERE expires_at <= NOW();');
    await this.db.query(
      `INSERT INTO auth_sessions (id, user_id, refresh_token_id, expires_at)
       VALUES ($1, $2, $3, NOW() + INTERVAL '30 days');`,
      [sessionId, userId, refreshId],
    );
    return tokens;
  }

  private async signTokens(
    email: string,
    version: number,
    sessionId: string,
    refreshId: string,
  ) {
    const base = { sub: 'single-user' as const, email, version, sessionId };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { ...base, kind: 'access' satisfies TokenKind },
        { secret: this.jwtSecret, expiresIn: '15m' },
      ),
      this.jwt.signAsync(
        { ...base, kind: 'refresh' satisfies TokenKind, refreshId },
        { secret: this.refreshSecret, expiresIn: '30d' },
      ),
    ]);
    return {
      accessToken,
      refreshToken,
      expiresIn: 900,
      user: { email },
    };
  }
}
