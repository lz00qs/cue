DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'tasks'
      AND column_name = 'status'
  ) THEN
    EXECUTE 'UPDATE tasks
      SET completed_at = COALESCE(completed_at, updated_at)
      WHERE status = ''done''';
  END IF;
END $$;

ALTER TABLE tasks DROP COLUMN IF EXISTS status;
