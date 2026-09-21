import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PoolClient, QueryResultRow } from 'pg';
import { Observable } from 'rxjs';

import { DatabaseService } from '../database/database.service';
import { CreateTaskDto, UpdateTaskDto } from './task.dto';

interface TaskRow extends QueryResultRow {
  id: string;
  title: string;
  note: string;
  priority: number;
  important: boolean;
  sort_order: string;
  due_at: Date | null;
  reminder: string | null;
  recurrence: string | null;
  group: string | null;
  completed_at: Date | null;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
  version: number;
  revision: string;
}

const columns = `id, title, note, priority, important, sort_order,
  due_at, reminder, recurrence, "group", completed_at, created_at, updated_at, deleted_at, version, revision`;

@Injectable()
export class TasksService {
  constructor(private readonly database: DatabaseService) {}

  watchRevisions(): Observable<number> {
    return this.database.taskChanges;
  }

  async list() {
    const result = await this.database.query<TaskRow>(
      `SELECT ${columns} FROM tasks WHERE deleted_at IS NULL
       ORDER BY sort_order ASC, created_at ASC`,
    );
    return result.rows.map(toTask);
  }

  async sync(since: number) {
    const result = await this.database.query<TaskRow>(
      `SELECT ${columns} FROM tasks WHERE revision > $1 ORDER BY revision ASC`,
      [since],
    );
    return {
      changes: result.rows.map(toTask),
      // Advance only through revisions included in this response. A concurrent
      // write after the SELECT must remain visible to the next sync request.
      latestRevision: result.rows.reduce(
        (latest, row) => Math.max(latest, Number(row.revision)),
        since,
      ),
    };
  }

  async create(input: CreateTaskDto) {
    return this.database.transaction(async (client) => {
      await this.lockTaskWrites(client);
      const now = new Date();
      const priority = input.priority ?? 2;
      const order =
        input.sortOrder ??
        Number(
          (
            await client.query<{ next_order: string }>(
              `SELECT COALESCE(MAX(sort_order), 0) + 1000 AS next_order
               FROM tasks WHERE deleted_at IS NULL`,
            )
          ).rows[0].next_order,
        );
      const result = await client.query<TaskRow>(
        `INSERT INTO tasks (
           id, title, note, priority, important, sort_order, due_at,
           reminder, recurrence, "group", created_at, updated_at, version, revision
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11, 1,
           nextval('task_revision_seq'))
         RETURNING ${columns}`,
        [
          randomUUID(),
          input.title.trim(),
          input.note?.trim() ?? '',
          priority,
          isImportant(priority),
          order,
          input.dueAt ?? null,
          input.reminder ?? null,
          input.recurrence ?? null,
          input.group ?? null,
          now,
        ],
      );
      await this.database.notifyTaskChanged(client, result.rows[0].revision);
      return toTask(result.rows[0]);
    });
  }

  async update(id: string, input: UpdateTaskDto) {
    return this.database.transaction(async (client) => {
      await this.lockTaskWrites(client);
      const existing = await this.findActive(client, id);
      if (existing.version !== input.version) {
        throw new ConflictException({
          message: 'Task was updated by another request',
          current: toTask(existing),
        });
      }

      const completedAt =
        input.completedAt === undefined
          ? existing.completed_at
          : input.completedAt;
      const priority = input.priority ?? existing.priority;
      const result = await client.query<TaskRow>(
        `UPDATE tasks SET
           title = $2, note = $3, priority = $4,
           important = $5, sort_order = $6, due_at = $7,
           reminder = $8, recurrence = $9, "group" = $10, completed_at = $11,
           updated_at = NOW(), version = version + 1,
           revision = nextval('task_revision_seq')
         WHERE id = $1 AND deleted_at IS NULL AND version = $12
         RETURNING ${columns}`,
        [
          id,
          input.title?.trim() ?? existing.title,
          input.note?.trim() ?? existing.note,
          priority,
          isImportant(priority),
          input.sortOrder ?? Number(existing.sort_order),
          input.dueAt === undefined ? existing.due_at : input.dueAt,
          input.reminder === undefined ? existing.reminder : input.reminder,
          input.recurrence === undefined ? existing.recurrence : input.recurrence,
          input.group === undefined ? existing.group : input.group,
          completedAt,
          input.version,
        ],
      );
      if (result.rowCount === 0) {
        throw new ConflictException('Task changed before the update completed');
      }
      await this.database.notifyTaskChanged(client, result.rows[0].revision);
      return toTask(result.rows[0]);
    });
  }

  async remove(id: string, version: number) {
    return this.database.transaction(async (client) => {
      await this.lockTaskWrites(client);
      const result = await client.query<TaskRow>(
        `UPDATE tasks SET deleted_at = NOW(), updated_at = NOW(),
           version = version + 1, revision = nextval('task_revision_seq')
         WHERE id = $1 AND deleted_at IS NULL AND version = $2
         RETURNING ${columns}`,
        [id, version],
      );
      if (result.rowCount === 0) {
        const exists = await client.query(
          'SELECT 1 FROM tasks WHERE id = $1 AND deleted_at IS NULL',
          [id],
        );
        if (exists.rowCount === 0) throw new NotFoundException('Task not found');
        throw new ConflictException('Task changed before it could be deleted');
      }
      await this.database.notifyTaskChanged(client, result.rows[0].revision);
      return toTask(result.rows[0]);
    });
  }

  private async lockTaskWrites(client: PoolClient) {
    // A sequence alone does not order commits. Serialize writers before they
    // allocate a revision so a sync cursor can never pass an uncommitted task.
    await client.query('SELECT pg_advisory_xact_lock(1987737485::bigint)');
  }

  private async findActive(client: PoolClient, id: string) {
    const result = await client.query<TaskRow>(
      `SELECT ${columns} FROM tasks WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    if (result.rowCount === 0) throw new NotFoundException('Task not found');
    return result.rows[0];
  }
}

function toTask(row: TaskRow) {
  return {
    id: row.id,
    title: row.title,
    note: row.note,
    priority: row.priority,
    important: isImportant(row.priority),
    sortOrder: Number(row.sort_order),
    dueAt: row.due_at?.toISOString() ?? null,
    reminder: row.reminder ?? null,
    recurrence: row.recurrence ?? null,
    group: row.group ?? null,
    completedAt: row.completed_at?.toISOString() ?? null,
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
    deletedAt: row.deleted_at?.toISOString() ?? null,
    version: row.version,
    revision: Number(row.revision),
  };
}

function isImportant(priority: number) {
  return priority === 0;
}
