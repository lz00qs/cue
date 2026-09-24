import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
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
  setup(
    @Body() input: SetupDto,
    @Headers('x-forwarded-proto') forwardedProto?: string,
  ) {
    if (this.isHttps(forwardedProto)) {
      throw new ForbiddenException('Admin setup is unavailable over HTTPS');
    }
    return this.auth.setup(input.email, input.password);
  }

  @Public()
  @Post('login')
  login(@Body() input: LoginDto) {
    return this.auth.login(input.email, input.password);
  }

  @Public()
  @Post('refresh')
  refresh(@Body() input: RefreshDto) {
    return this.auth.refresh(input.refreshToken);
  }

  @Public()
  @Post('logout')
  logout(@Body() input: RefreshDto) {
    return this.auth.logout(input.refreshToken);
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
