-- Three privilege tiers, matching the Group 9 scenario:
--   db_admin  : full control, can grant/revoke (used to test privilege-change alerts)
--   analyst   : read-only on everything, used for normal reporting queries
--   readonly  : read-only on a restricted view only (no direct table access)

CREATE ROLE db_admin WITH LOGIN PASSWORD 'admin_pw_change_me' SUPERUSER;

CREATE ROLE analyst WITH LOGIN PASSWORD 'analyst_pw_change_me';
GRANT CONNECT ON DATABASE bigdata_security TO analyst;
GRANT USAGE ON SCHEMA public TO analyst;
GRANT SELECT ON customers, transactions TO analyst;

CREATE ROLE readonly WITH LOGIN PASSWORD 'readonly_pw_change_me';
GRANT CONNECT ON DATABASE bigdata_security TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;

-- readonly only gets a masked view, not the raw customer PII table
CREATE VIEW customer_public AS
    SELECT customer_id, full_name, created_at FROM customers;
GRANT SELECT ON customer_public TO readonly;
GRANT SELECT ON transactions TO readonly;
