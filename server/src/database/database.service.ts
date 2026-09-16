import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Pool, PoolClient, QueryResultRow } from 'pg';
import { Subject } from 'rxjs';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private static readonly taskChannel = 'cue_task_changes';
  private readonly pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: Number(process.env.DB_POOL_SIZE ?? 10),
  });
  private readonly taskChangeSubject = new Subject<number>();
  readonly taskChanges = this.taskChangeSubject.asObservable();
  private listener?: PoolClient;
  private reconnectTimer?: NodeJS.Timeout;
  private closing = false;

  async onModuleInit() {
    await this.connectListener();
  }

  private async connectListener() {
    if (this.closing || this.listener) return;
    let client: PoolClient | undefined;
    try {
      client = await this.pool.connect();
      client.on('notification', (message) => {
        if (message.channel !== DatabaseService.taskChannel) return;
        const revision = Number(message.payload);
        if (Number.isSafeInteger(revision) && revision > 0) {
          this.taskChangeSubject.next(revision);
        }
      });
      await client.query(`LISTEN ${DatabaseService.taskChannel}`);
      if (this.closing) {
        client.removeAllListeners('notification');
        client.release();
        return;
      }
      this.listener = client;
      client.on('error', () => this.listenerDisconnected(client!));
      client.on('end', () => this.listenerDisconnected(client!));
    } catch {
      client?.removeAllListeners('notification');
      client?.release(true);
      this.scheduleReconnect();
    }
  }

  private listenerDisconnected(client: PoolClient) {
    if (this.listener !== client) return;
    this.listener = undefined;
    client.removeAllListeners('notification');
    client.removeAllListeners('error');
    client.removeAllListeners('end');
    client.release(true);
    this.scheduleReconnect();
  }

  private scheduleReconnect() {
    if (this.closing || this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined;
      void this.connectListener();
    }, 2000);
  }

  async notifyTaskChanged(client: PoolClient, revision: string) {
    await client.query('SELECT pg_notify($1, $2)', [
      DatabaseService.taskChannel,
      revision,
    ]);
  }

  query<T extends QueryResultRow>(text: string, values: unknown[] = []) {
    return this.pool.query<T>(text, values);
  }

  async transaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await work(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy() {
    this.closing = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    const listener = this.listener;
    this.listener = undefined;
    listener?.removeAllListeners('notification');
    listener?.removeAllListeners('error');
    listener?.removeAllListeners('end');
    listener?.release(true);
    this.taskChangeSubject.complete();
    await this.pool.end();
  }
}
