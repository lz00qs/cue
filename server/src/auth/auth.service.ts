import {
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { compare, hash } from 'bcryptjs';

type TokenKind = 'access' | 'refresh';

interface CueTokenPayload {
  sub: 'single-user';
  email: string;
  kind: TokenKind;
}

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly email = process.env.CUE_ADMIN_EMAIL ?? 'admin@cue.local';
  private passwordHash = process.env.CUE_ADMIN_PASSWORD_HASH ?? '';
  private readonly jwtSecret = process.env.CUE_JWT_SECRET ?? '';
  private readonly refreshSecret =
    process.env.CUE_REFRESH_SECRET ?? this.jwtSecret;

  constructor(private readonly jwt: JwtService) {}

  async onModuleInit() {
    if (this.jwtSecret.length < 32) {
      throw new Error('CUE_JWT_SECRET must contain at least 32 characters');
    }
    if (!this.passwordHash) {
      const password = process.env.CUE_ADMIN_PASSWORD;
      if (!password || password.length < 8) {
        throw new Error(
          'Set CUE_ADMIN_PASSWORD_HASH or CUE_ADMIN_PASSWORD (minimum 8 characters)',
        );
      }
      this.passwordHash = await hash(password, 12);
    }
  }

  async login(email: string, password: string) {
    const validEmail = email.trim().toLowerCase() === this.email.toLowerCase();
    const validPassword = await compare(password, this.passwordHash);
    if (!validEmail || !validPassword) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.issueTokens();
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwt.verifyAsync<CueTokenPayload>(refreshToken, {
        secret: this.refreshSecret,
      });
      if (payload.sub !== 'single-user' || payload.kind !== 'refresh') {
        throw new Error('Wrong token type');
      }
      return this.issueTokens();
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

  private async issueTokens() {
    const base = { sub: 'single-user' as const, email: this.email };
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
      user: { email: this.email },
    };
  }
}
