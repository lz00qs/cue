CREATE SEQUENCE IF NOT EXISTS task_revision_seq START 1;

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title VARCHAR(240) NOT NULL,
  note VARCHAR(5000) NOT NULL DEFAULT '',
  status VARCHAR(16) NOT NULL CHECK (status IN ('todo', 'doing', 'done')),
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

INSERT INTO tasks (
  id, title, note, status, priority, important, sort_order, due_at,
  completed_at, created_at, updated_at, version, revision
)
VALUES
  ('pcb-review', 'Review PCB layout', 'Check routing, clearances, and the power plane before handoff.', 'todo', 0, TRUE, 1000, CURRENT_DATE + TIME '10:30', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('thermal-simulation', 'Run thermal simulation', 'Compare the revised enclosure against the baseline model.', 'doing', 1, TRUE, 2000, CURRENT_DATE + TIME '14:00', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('sprint-report', 'Draft sprint report', 'Summarize decisions, risks, and next actions.', 'todo', 2, FALSE, 3000, CURRENT_DATE + TIME '17:00', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('lab-calibration', 'Book lab calibration', 'Coordinate the chamber slot with operations.', 'todo', 3, FALSE, 4000, CURRENT_DATE + INTERVAL '3 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('requirements', 'Finalize requirements', 'Approved for the current build.', 'done', 2, TRUE, 5000, CURRENT_DATE + TIME '09:00', CURRENT_DATE + TIME '09:15', NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('signal-drift', 'Analyze signal drift', '', 'doing', 2, TRUE, 6000, CURRENT_DATE + INTERVAL '2 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('firmware-sync', 'Sync firmware branch', '', 'done', 3, FALSE, 7000, CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE - INTERVAL '2 days', NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('design-handoff', 'Prepare design handoff', '', 'todo', 2, TRUE, 8000, CURRENT_DATE + INTERVAL '11 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('october-roadmap', 'Plan next month roadmap', '', 'todo', 2, TRUE, 9000, CURRENT_DATE + INTERVAL '17 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('email-supplier', 'Email component supplier', '', 'todo', 3, FALSE, 10000, CURRENT_DATE + INTERVAL '1 day', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('archive-notes', 'Archive old notes', '', 'todo', 3, FALSE, 11000, NULL, NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('report-templates', 'Browse report templates', '', 'todo', 3, FALSE, 12000, NULL, NULL, NOW(), NOW(), 1, nextval('task_revision_seq'))
ON CONFLICT (id) DO NOTHING;
