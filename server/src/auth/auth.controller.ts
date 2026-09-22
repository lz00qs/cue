import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { LoginDto, RefreshDto, SetupDto } from './auth.dto';
import { AuthService } from './auth.service';
import { Public } from './public.decorator';

@ApiTags('auth')
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
}
