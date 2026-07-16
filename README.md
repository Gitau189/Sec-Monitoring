# Group 9 – Database Security Monitoring

DSA 4030 Big Data Security end-of-semester project.
Scenario: a company suspects unauthorized database access. This repo builds a
Postgres environment with pgAudit logging, RBAC, and detection scripts for
failed logins, privilege changes, and large data exports.

## Setup — Direct install (Ubuntu/WSL2)

Used as a fallback on machines where Docker Desktop had persistent startup
issues. Produces an environment functionally identical to the Docker setup —
same schema, same roles, same pgAudit config — since Postgres itself doesn't
know or care whether it's containerized or installed directly.

### Install Postgres + pgAudit

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib postgresql-18-pgaudit python3-pip python3-venv
```

### Enable pgAudit

Edit `/etc/postgresql/18/main/postgresql.conf` and add/set:
```
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write,ddl,role,read'
```

Restart Postgres for the change to take effect:
```bash
sudo service postgresql restart
```

### Create the database, extension, schema, and roles

```bash
sudo -u postgres psql
CREATE DATABASE bigdata_security;
\c bigdata_security
CREATE EXTENSION IF NOT EXISTS pgaudit;
-- then run the contents of postgres/init/02_schema.sql
-- then run the contents of postgres/init/03_roles.sql
```

### Set up Python and load the dataset

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export PGHOST=localhost PGPORT=5432 POSTGRES_DB=bigdata_security POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres
python3 data/generate_dataset.py --customers 20000 --transactions 100000
```

### Resuming work later

Postgres doesn't start automatically after a reboot/shutdown — start it
manually each session:
```bash
sudo service postgresql start
cd Sec-Monitoring
source venv/bin/activate
```

Everything else (tables, roles, data, logs) persists on disk exactly as left.

## Roles

| Role     | Access                                                       |
|----------|---------------------------------------------------------------|
| db_admin | Full control (superuser) — used to test privilege-change alerts |
| analyst  | SELECT on `customers` + `transactions`                          |
| readonly | SELECT on `transactions` + masked `customer_public` view only   |

## Security testing summary

7 tests performed (1 above the required minimum): brute-force login detection,
privilege escalation blocking, bulk data export detection, PII access
restriction, audit-log persistence across restarts, a quantified
normal-vs-suspicious activity comparison, and role-creation restriction.
Full matrix in `reports/tests.md`; supporting screenshots/log excerpts
in `evidence_portfolio/`.

Key finding: the initial pgAudit configuration (`write,ddl,role`) did not
capture read-only bulk exports. Identified during testing and fixed by adding
`read` to `pgaudit.log` — after which bulk `SELECT` exports were fully
captured. Documented as a hardening step in the final report's recommendations.

