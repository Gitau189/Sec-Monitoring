-- =============================================================================
-- Role-Based Access Control (RBAC) for the "company" database
-- =============================================================================
-- Models a realistic org so that privilege changes and least-privilege
-- violations are observable. Passwords are demo-only (see .env / README).

-- ---- Application roles (NOLOGIN group roles = privilege buckets) ----
CREATE ROLE app_read      NOLOGIN;   -- SELECT only
CREATE ROLE app_write     NOLOGIN;   -- SELECT + INSERT/UPDATE/DELETE
CREATE ROLE app_analyst   NOLOGIN;   -- read + run reports
CREATE ROLE app_admin     NOLOGIN;   -- full control (schema owner)

-- ---- Login roles (real users the app / people connect as) ----
-- NOTE: passwords are intentionally simple for the classroom demo.
CREATE ROLE svc_app       LOGIN PASSWORD 'app_service_pw'   IN ROLE app_write;
CREATE ROLE analyst_jane  LOGIN PASSWORD 'analyst_pw'       IN ROLE app_analyst;
CREATE ROLE report_bot    LOGIN PASSWORD 'report_pw'        IN ROLE app_read;
CREATE ROLE dba_mike      LOGIN PASSWORD 'dba_pw'           IN ROLE app_admin;

-- A deliberately low-privilege account used in the "privilege escalation" test.
CREATE ROLE intern_bob    LOGIN PASSWORD 'intern_pw'        IN ROLE app_read;

-- Read-only monitoring account for the Prometheus postgres_exporter.
-- pg_monitor grants access to stats views without exposing table data.
CREATE ROLE exporter      LOGIN PASSWORD 'exporter_pw';
GRANT pg_monitor TO exporter;
