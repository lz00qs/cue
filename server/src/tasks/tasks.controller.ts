import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  MessageEvent,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Sse,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { interval, Observable, takeUntil, timer } from 'rxjs';

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

  @Sse('sync/events')
  @Header('Cache-Control', 'no-cache, no-transform')
  @Header('X-Accel-Buffering', 'no')
  events(): Observable<MessageEvent> {
    return new Observable<MessageEvent>((subscriber) => {
      // Subscribe before sending ready, so the initial client sync cannot
      // race a task commit that would otherwise be missed by this stream.
      const changes = this.tasks.watchRevisions().subscribe({
        next: (revision) => subscriber.next({
          type: 'change',
          data: { revision },
        }),
        error: (error) => subscriber.error(error),
      });
      const heartbeat = interval(15000).subscribe(() => subscriber.next({
        type: 'heartbeat',
        data: {},
      }));
      subscriber.next({ type: 'ready', data: {} });
      return () => {
        changes.unsubscribe();
        heartbeat.unsubscribe();
      };
    }).pipe(takeUntil(timer(10 * 60 * 1000)));
  }
}
