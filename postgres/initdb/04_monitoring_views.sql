-- =============================================================================
-- Monitoring views + report objects (Part E: "Produce security reports")
-- =============================================================================
-- These give both the postgres_exporter (Prometheus) and Grafana ready-made
-- security signals, and double as the SQL you run for written reports.

SET search_path TO company, public;

-- ---------------------------------------------------------------------------
-- 1. Live sessions (who is connected right now, from where)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW company.v_active_sessions AS
SELECT
    pid,
    usename        AS username,
    datname        AS database,
    client_addr    AS client_ip,
    application_name,
    backend_start,
    state,
    query
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- ---------------------------------------------------------------------------
-- 2. Privilege inventory: which login roles hold which group roles.
--    Diff this over time to spot privilege changes / escalation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW company.v_role_grants AS
SELECT
    m.rolname   AS member,
    g.rolname   AS granted_role,
    m.rolsuper  AS member_is_superuser,
    m.rolcanlogin AS member_can_login
FROM pg_auth_members am
JOIN pg_roles m ON m.oid = am.member
JOIN pg_roles g ON g.oid = am.roleid
ORDER BY m.rolname, g.rolname;

-- ---------------------------------------------------------------------------
-- 3. Superuser watch: any account with superuser is high-risk.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW company.v_superusers AS
SELECT rolname AS username, rolcanlogin AS can_login
FROM pg_roles
WHERE rolsuper;

-- ---------------------------------------------------------------------------
-- 4. Large-read detection via pg_stat_statements.
--    Surfaces the statements that returned the most rows == potential
--    bulk data export / exfiltration.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW company.v_large_reads AS
SELECT
    r.rolname                       AS username,
    s.calls,
    s.rows                          AS total_rows_returned,
    round(s.rows::numeric / NULLIF(s.calls,0), 1) AS avg_rows_per_call,
    left(s.query, 120)              AS query_sample
FROM pg_stat_statements s
JOIN pg_roles r ON r.oid = s.userid
WHERE s.query ILIKE 'select%' OR s.query ILIKE 'copy%'
ORDER BY s.rows DESC
LIMIT 50;

-- Expose the monitoring views to the exporter + analysts.
GRANT USAGE ON SCHEMA company TO exporter, app_analyst;
GRANT SELECT ON company.v_active_sessions,
                company.v_role_grants,
                company.v_superusers,
                company.v_large_reads
      TO exporter, app_analyst;
