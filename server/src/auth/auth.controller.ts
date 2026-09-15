import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { LoginDto, RefreshDto } from './auth.dto';
import { AuthService } from './auth.service';
import { Public } from './public.decorator';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

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
