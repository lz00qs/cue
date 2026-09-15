import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';

import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { DatabaseService } from './database/database.service';
import { HealthController } from './health.controller';
import { TasksController } from './tasks/tasks.controller';
import { TasksService } from './tasks/tasks.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    JwtModule.register({ global: true }),
  ],
  controllers: [AuthController, HealthController, TasksController],
  providers: [AuthService, DatabaseService, JwtAuthGuard, TasksService],
})
export class AppModule {}
