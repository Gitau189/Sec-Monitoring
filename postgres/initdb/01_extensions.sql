-- Runs once, on first cluster init (postgres official-image entrypoint).
-- Enable the auditing + stats extensions declared in postgresql.conf.

CREATE EXTENSION IF NOT EXISTS pgaudit;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Confirm in the init log that pgAudit loaded.
DO $$
BEGIN
    RAISE NOTICE 'pgAudit and pg_stat_statements extensions created.';
END $$;
