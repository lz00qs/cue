INSERT INTO tasks (
  id, title, note, priority, important, sort_order, due_at,
  completed_at, created_at, updated_at, version, revision
)
VALUES
  ('pcb-review', 'Review PCB layout', 'Check routing, clearances, and the power plane before handoff.', 0, TRUE, 1000, CURRENT_DATE + TIME '10:30', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('thermal-simulation', 'Run thermal simulation', 'Compare the revised enclosure against the baseline model.', 1, TRUE, 2000, CURRENT_DATE + TIME '14:00', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('sprint-report', 'Draft sprint report', 'Summarize decisions, risks, and next actions.', 2, FALSE, 3000, CURRENT_DATE + TIME '17:00', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('lab-calibration', 'Book lab calibration', 'Coordinate the chamber slot with operations.', 3, FALSE, 4000, CURRENT_DATE + INTERVAL '3 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('requirements', 'Finalize requirements', 'Approved for the current build.', 2, FALSE, 5000, CURRENT_DATE + TIME '09:00', CURRENT_DATE + TIME '09:15', NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('signal-drift', 'Analyze signal drift', '', 2, FALSE, 6000, CURRENT_DATE + INTERVAL '2 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('firmware-sync', 'Sync firmware branch', '', 3, FALSE, 7000, CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE - INTERVAL '2 days', NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('design-handoff', 'Prepare design handoff', '', 2, FALSE, 8000, CURRENT_DATE + INTERVAL '11 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('october-roadmap', 'Plan next month roadmap', '', 2, FALSE, 9000, CURRENT_DATE + INTERVAL '17 days', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('email-supplier', 'Email component supplier', '', 3, FALSE, 10000, CURRENT_DATE + INTERVAL '1 day', NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('archive-notes', 'Archive old notes', '', 3, FALSE, 11000, NULL, NULL, NOW(), NOW(), 1, nextval('task_revision_seq')),
  ('report-templates', 'Browse report templates', '', 3, FALSE, 12000, NULL, NULL, NOW(), NOW(), 1, nextval('task_revision_seq'))
ON CONFLICT (id) DO NOTHING;
