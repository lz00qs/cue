UPDATE tasks
SET important = (priority = 0)
WHERE important IS DISTINCT FROM (priority = 0);
