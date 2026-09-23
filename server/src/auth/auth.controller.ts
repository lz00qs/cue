import {
  Body,
  Controller,
  Get,
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

  @Public()
  @Get('status')
  async status() {
    const initialized = await this.auth.isInitialized();
    return { initialized };
  }

  @Public()
  @Post('setup')
  setup(@Body() input: SetupDto) {
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

  @Patch('account')
  updateAccount(@Body() input: UpdateAccountDto) {
    return this.auth.updateAccount(
      input.currentPassword,
      input.email,
      input.newPassword,
    );
  }
}
