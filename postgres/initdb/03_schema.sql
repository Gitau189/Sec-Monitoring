-- =============================================================================
-- Business schema: a small "company" with sensitive customer + financial data
-- =============================================================================
-- Data is loaded separately (see data/generate_data.py + `make load`) so the
-- image stays small and the dataset can be regenerated.

CREATE SCHEMA IF NOT EXISTS company AUTHORIZATION app_admin;
SET search_path TO company, public;

-- ---- Customers: contains PII (the crown jewels an attacker would export) ----
CREATE TABLE company.customers (
    customer_id   BIGINT PRIMARY KEY,
    full_name     TEXT        NOT NULL,
    email         TEXT        NOT NULL,
    phone         TEXT,
    country       TEXT,
    ssn           TEXT,               -- sensitive: national ID / tax number
    credit_score  INT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Transactions: financial records tied to customers ----
CREATE TABLE company.transactions (
    txn_id        BIGINT PRIMARY KEY,
    customer_id   BIGINT      NOT NULL REFERENCES company.customers(customer_id),
    amount        NUMERIC(12,2) NOT NULL,
    currency      TEXT        NOT NULL DEFAULT 'USD',
    txn_type      TEXT        NOT NULL,     -- purchase / refund / transfer
    status        TEXT        NOT NULL,     -- approved / declined / flagged
    txn_time      TIMESTAMPTZ NOT NULL
);

-- ---- Employees: internal staff directory ----
CREATE TABLE company.employees (
    employee_id   BIGINT PRIMARY KEY,
    full_name     TEXT NOT NULL,
    department    TEXT,
    role_title    TEXT,
    salary        NUMERIC(10,2),
    hired_at      DATE
);

CREATE INDEX idx_txn_customer ON company.transactions(customer_id);
CREATE INDEX idx_txn_time     ON company.transactions(txn_time);
CREATE INDEX idx_cust_country ON company.customers(country);

-- ---- Apply least-privilege grants to the RBAC roles ----
GRANT USAGE ON SCHEMA company TO app_read, app_write, app_analyst;

GRANT SELECT ON ALL TABLES IN SCHEMA company TO app_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA company TO app_write;
GRANT SELECT ON ALL TABLES IN SCHEMA company TO app_analyst;

-- New tables created later by app_admin inherit the same grants.
ALTER DEFAULT PRIVILEGES IN SCHEMA company
    GRANT SELECT ON TABLES TO app_read, app_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA company
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_write;
