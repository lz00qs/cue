import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Patch,
  Post,
  Res,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request, Response, CookieOptions } from 'express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import {
  LoginDto,
  RefreshDto,
  SetupDto,
  UpdateAccountDto,
} from './auth.dto';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { Public } from './public.decorator';

@ApiTags('auth')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  private setCookies(req: Request, res: Response, tokens: { accessToken: string; refreshToken: string }) {
    const isHttps = req.secure || this.isHttps(req.headers['x-forwarded-proto'] as string | undefined);
    
    const options: CookieOptions = {
      httpOnly: true,
      sameSite: 'lax',
      secure: isHttps,
      path: '/',
    };
    
    // Access token valid for a reasonable time (e.g. 1h, though JWT might be shorter, we just let cookie live long enough)
    res.cookie('cue_access_token', tokens.accessToken, { ...options, maxAge: 24 * 60 * 60 * 1000 });
    // Refresh token valid longer
    res.cookie('cue_refresh_token', tokens.refreshToken, { ...options, path: '/api/auth', maxAge: 30 * 24 * 60 * 60 * 1000 });
  }

  private clearCookies(res: Response) {
    const options: CookieOptions = { httpOnly: true, sameSite: 'lax', path: '/' };
    res.cookie('cue_access_token', '', { ...options, maxAge: 0 });
    res.cookie('cue_refresh_token', '', { ...options, path: '/api/auth', maxAge: 0 });
  }

  private isHttps(forwardedProto?: string): boolean {
    return (
      forwardedProto
        ?.split(',')
        .some((value) => value.trim().toLowerCase() === 'https') ?? false
    );
  }

  @Public()
  @Get('status')
  async status(@Headers('x-forwarded-proto') forwardedProto?: string) {
    const initialized = await this.auth.isInitialized();
    return {
      initialized,
      setupAvailable:
        !this.isHttps(forwardedProto) &&
        this.auth.isSetupAvailable(initialized),
    };
  }

  @Public()
  @Post('setup')
  async setup(
    @Body() input: SetupDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Headers('x-forwarded-proto') forwardedProto?: string,
  ) {
    if (this.isHttps(forwardedProto)) {
      throw new ForbiddenException('Admin setup is unavailable over HTTPS');
    }
    const result = await this.auth.setup(input.email, input.password);
    this.setCookies(req, res, result);
    return result;
  }

  @Public()
  @Post('login')
  async login(
    @Body() input: LoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.auth.login(input.email, input.password);
    this.setCookies(req, res, result);
    return result;
  }

  @Public()
  @Post('refresh')
  async refresh(
    @Body() input: RefreshDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const rToken = input.refreshToken || req.cookies?.['cue_refresh_token'];
    if (!rToken) {
      throw new ForbiddenException('No refresh token provided');
    }
    const result = await this.auth.refresh(rToken);
    this.setCookies(req, res, result);
    return result;
  }

  @Public()
  @Post('logout')
  async logout(
    @Body() input: RefreshDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.clearCookies(res);
    const rToken = input.refreshToken || req.cookies?.['cue_refresh_token'];
    if (rToken) {
      await this.auth.logout(rToken).catch(() => {});
    }
    return { success: true };
  }

  @Get('me')
  async me(@Req() req: Request): Promise<{ email: string }> {
    let token = req.headers.authorization?.substring(7);
    if (!token && req.cookies) {
      token = req.cookies['cue_access_token'];
    }
    if (!token) throw new ForbiddenException('No token');
    const payload = await this.auth.verifyAccess(token);
    return { email: payload.email };
  }

  @Patch('account')
  updateAccount(@Body() input: UpdateAccountDto) {
    return this.auth.updateAccount(
      input.currentPassword,
      input.email,
      input.newPassword,
    );
  }
}
