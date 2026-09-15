import { Controller, Get } from '@nestjs/common';
import { ApiExcludeEndpoint } from '@nestjs/swagger';

import { DatabaseService } from './database/database.service';
import { Public } from './auth/public.decorator';

@Controller('health')
export class HealthController {
  constructor(private readonly database: DatabaseService) {}

  @Public()
  @Get()
  @ApiExcludeEndpoint()
  async health() {
    await this.database.query('SELECT 1');
    return { status: 'ok' };
  }
}
