CREATE SEQUENCE IF NOT EXISTS task_revision_seq START 1;

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title VARCHAR(240) NOT NULL,
  note VARCHAR(5000) NOT NULL DEFAULT '',
  priority SMALLINT NOT NULL CHECK (priority BETWEEN 0 AND 3),
  important BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order DOUBLE PRECISION NOT NULL,
  due_at TIMESTAMPTZ,
  reminder VARCHAR(64),
  recurrence VARCHAR(64),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
  revision BIGINT NOT NULL DEFAULT nextval('task_revision_seq')
);

CREATE INDEX IF NOT EXISTS tasks_active_sort_idx
  ON tasks (sort_order, created_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS tasks_revision_idx ON tasks (revision);
CREATE INDEX IF NOT EXISTS tasks_due_at_idx
  ON tasks (due_at) WHERE deleted_at IS NULL;
