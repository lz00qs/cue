import {
  ConflictException,
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { compare, hash } from 'bcryptjs';

import { DatabaseService } from '../database/database.service';

type TokenKind = 'access' | 'refresh';

interface CueTokenPayload {
  sub: 'single-user';
  email: string;
  kind: TokenKind;
}

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly jwtSecret = process.env.CUE_JWT_SECRET ?? '';
  private readonly refreshSecret =
    process.env.CUE_REFRESH_SECRET ?? this.jwtSecret;

  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
  ) {}

  async onModuleInit() {
    if (this.jwtSecret.length < 32) {
      throw new Error('CUE_JWT_SECRET must contain at least 32 characters');
    }

    // Optional backward-compatibility migration: if environment credentials exist
    // and database is empty, seed the admin account once.
    try {
      const initialized = await this.isInitialized();
      if (!initialized) {
        const envEmail = process.env.CUE_ADMIN_EMAIL?.trim().toLowerCase();
        let envHash = process.env.CUE_ADMIN_PASSWORD_HASH?.trim();
        const envPassword = process.env.CUE_ADMIN_PASSWORD;

        if (envEmail && !envHash && envPassword && envPassword.length >= 8) {
          envHash = await hash(envPassword, 12);
        }

        if (envEmail && envHash) {
          await this.db.query(
            `INSERT INTO users (id, email, password_hash, created_at, updated_at)
             VALUES ($1, $2, $3, NOW(), NOW())
             ON CONFLICT (id) DO NOTHING;`,
            ['admin', envEmail, envHash],
          );
        }
      }
    } catch {
      // Database might not be ready yet if migrations are still running.
    }
  }

  async isInitialized(): Promise<boolean> {
    const result = await this.db.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM users;',
    );
    return Number(result.rows[0]?.count ?? 0) > 0;
  }

  async setup(email: string, password: string) {
    const initialized = await this.isInitialized();
    if (initialized) {
      throw new ConflictException('Admin account has already been set up');
    }

    const cleanEmail = email.trim().toLowerCase();
    if (password.length < 8) {
      throw new ConflictException('Password must be at least 8 characters');
    }

    const passwordHash = await hash(password, 12);
    await this.db.query(
      `INSERT INTO users (id, email, password_hash, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW());`,
      ['admin', cleanEmail, passwordHash],
    );

    return this.issueTokens(cleanEmail);
  }

  async login(email: string, password: string) {
    const cleanEmail = email.trim().toLowerCase();
    const result = await this.db.query<{
      id: string;
      email: string;
      password_hash: string;
    }>(
      'SELECT id, email, password_hash FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1;',
      [cleanEmail],
    );

    const user = result.rows[0];
    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const validPassword = await compare(password, user.password_hash);
    if (!validPassword) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.issueTokens(user.email);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwt.verifyAsync<CueTokenPayload>(refreshToken, {
        secret: this.refreshSecret,
      });
      if (payload.sub !== 'single-user' || payload.kind !== 'refresh') {
        throw new Error('Wrong token type');
      }

      const result = await this.db.query<{ email: string }>(
        'SELECT email FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1;',
        [payload.email],
      );
      if (result.rows.length === 0) {
        throw new UnauthorizedException('User no longer exists');
      }

      return this.issueTokens(result.rows[0].email);
    } catch {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
  }

  async verifyAccess(accessToken: string) {
    try {
      const payload = await this.jwt.verifyAsync<CueTokenPayload>(accessToken, {
        secret: this.jwtSecret,
      });
      if (payload.sub !== 'single-user' || payload.kind !== 'access') {
        throw new Error('Wrong token type');
      }
      return payload;
    } catch {
      throw new UnauthorizedException('Access token is invalid or expired');
    }
  }

  private async issueTokens(email: string) {
    const base = { sub: 'single-user' as const, email };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { ...base, kind: 'access' satisfies TokenKind },
        { secret: this.jwtSecret, expiresIn: '15m' },
      ),
      this.jwt.signAsync(
        { ...base, kind: 'refresh' satisfies TokenKind },
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
