import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { QueryResultRow } from 'pg';

import { DatabaseService } from '../database/database.service';
import { CreateTaskDto, UpdateTaskDto } from './task.dto';

interface TaskRow extends QueryResultRow {
  id: string;
  title: string;
  note: string;
  status: 'todo' | 'doing' | 'done';
  priority: number;
  important: boolean;
  sort_order: string;
  due_at: Date | null;
  completed_at: Date | null;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
  version: number;
  revision: string;
}

const columns = `id, title, note, status, priority, important, sort_order,
  due_at, completed_at, created_at, updated_at, deleted_at, version, revision`;

@Injectable()
export class TasksService {
  constructor(private readonly database: DatabaseService) {}

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
    const latest = await this.database.query<{ revision: string }>(
      `SELECT COALESCE(MAX(revision), 0)::text AS revision FROM tasks`,
    );
    return {
      changes: result.rows.map(toTask),
      latestRevision: Number(latest.rows[0].revision),
    };
  }

  async create(input: CreateTaskDto) {
    const now = new Date();
    const status = input.status ?? 'todo';
    const completedAt = status === 'done' ? now : null;
    const order =
      input.sortOrder ??
      Number(
        (
          await this.database.query<{ next_order: string }>(
            `SELECT COALESCE(MAX(sort_order), 0) + 1000 AS next_order
             FROM tasks WHERE deleted_at IS NULL`,
          )
        ).rows[0].next_order,
      );
    const result = await this.database.query<TaskRow>(
      `INSERT INTO tasks (
         id, title, note, status, priority, important, sort_order, due_at,
         completed_at, created_at, updated_at, version, revision
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $10, 1,
         nextval('task_revision_seq'))
       RETURNING ${columns}`,
      [
        randomUUID(),
        input.title.trim(),
        input.note?.trim() ?? '',
        status,
        input.priority ?? 2,
        input.important ?? false,
        order,
        input.dueAt ?? null,
        completedAt,
        now,
      ],
    );
    return toTask(result.rows[0]);
  }

  async update(id: string, input: UpdateTaskDto) {
    const existing = await this.findActive(id);
    if (existing.version !== input.version) {
      throw new ConflictException({
        message: 'Task was updated by another request',
        current: toTask(existing),
      });
    }

    const nextStatus = input.status ?? existing.status;
    const completedAt =
      nextStatus === 'done'
        ? existing.completed_at ?? new Date()
        : input.status
          ? null
          : existing.completed_at;
    const result = await this.database.query<TaskRow>(
      `UPDATE tasks SET
         title = $2, note = $3, status = $4, priority = $5,
         important = $6, sort_order = $7, due_at = $8, completed_at = $9,
         updated_at = NOW(), version = version + 1,
         revision = nextval('task_revision_seq')
       WHERE id = $1 AND deleted_at IS NULL AND version = $10
       RETURNING ${columns}`,
      [
        id,
        input.title?.trim() ?? existing.title,
        input.note?.trim() ?? existing.note,
        nextStatus,
        input.priority ?? existing.priority,
        input.important ?? existing.important,
        input.sortOrder ?? Number(existing.sort_order),
        input.dueAt === undefined ? existing.due_at : input.dueAt,
        completedAt,
        input.version,
      ],
    );
    if (result.rowCount === 0) {
      throw new ConflictException('Task changed before the update completed');
    }
    return toTask(result.rows[0]);
  }

  async remove(id: string, version: number) {
    const result = await this.database.query<TaskRow>(
      `UPDATE tasks SET deleted_at = NOW(), updated_at = NOW(),
         version = version + 1, revision = nextval('task_revision_seq')
       WHERE id = $1 AND deleted_at IS NULL AND version = $2
       RETURNING ${columns}`,
      [id, version],
    );
    if (result.rowCount === 0) {
      const exists = await this.database.query(
        'SELECT 1 FROM tasks WHERE id = $1 AND deleted_at IS NULL',
        [id],
      );
      if (exists.rowCount === 0) throw new NotFoundException('Task not found');
      throw new ConflictException('Task changed before it could be deleted');
    }
    return toTask(result.rows[0]);
  }

  private async findActive(id: string) {
    const result = await this.database.query<TaskRow>(
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
    status: row.status,
    priority: row.priority,
    important: row.important,
    sortOrder: Number(row.sort_order),
    dueAt: row.due_at?.toISOString() ?? null,
    completedAt: row.completed_at?.toISOString() ?? null,
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
    deletedAt: row.deleted_at?.toISOString() ?? null,
    version: row.version,
    revision: Number(row.revision),
  };
}
