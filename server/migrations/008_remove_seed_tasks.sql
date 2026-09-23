WITH removed AS (
  UPDATE tasks
  SET deleted_at = NOW(),
      updated_at = NOW(),
      version = version + 1,
      revision = nextval('task_revision_seq')
  WHERE id = ANY (ARRAY[
    'pcb-review',
    'thermal-simulation',
    'sprint-report',
    'lab-calibration',
    'requirements',
    'signal-drift',
    'firmware-sync',
    'design-handoff',
    'october-roadmap',
    'email-supplier',
    'archive-notes',
    'report-templates'
  ])
    AND deleted_at IS NULL
  RETURNING revision
)
SELECT pg_notify('cue_task_changes', MAX(revision)::text)
FROM removed
HAVING COUNT(*) > 0;
