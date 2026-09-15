import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateTaskDto, DeleteTaskDto, UpdateTaskDto } from './task.dto';
import { TasksService } from './tasks.service';

@ApiTags('tasks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class TasksController {
  constructor(private readonly tasks: TasksService) {}

  @Get('tasks')
  list() {
    return this.tasks.list();
  }

  @Post('tasks')
  create(@Body() input: CreateTaskDto) {
    return this.tasks.create(input);
  }

  @Patch('tasks/:id')
  update(@Param('id') id: string, @Body() input: UpdateTaskDto) {
    return this.tasks.update(id, input);
  }

  @Delete('tasks/:id')
  remove(@Param('id') id: string, @Body() input: DeleteTaskDto) {
    return this.tasks.remove(id, input.version);
  }

  @Get('sync')
  sync(@Query('since', new ParseIntPipe({ optional: true })) since = 0) {
    return this.tasks.sync(Math.max(0, since));
  }
}
