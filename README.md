# Group 9 — Database Security Monitoring

**DSA 4030 Big Data Security — End-of-Semester Project**

> **Scenario:** A company suspects unauthorized access to its database. This
> project builds a monitored PostgreSQL environment — with pgAudit logging,
> role-based access control, and a Grafana dashboard — capable of detecting
> failed logins, privilege escalation attempts, and large/bulk data exports.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Setup](#setup)
  - [Method 1: Direct Install (Ubuntu / WSL2)](#method-1-direct-install-ubuntu--wsl2)
- [Roles & Access Control](#roles--access-control)
- [Security Testing](#security-testing)
- [Grafana Dashboard](#grafana-dashboard)
- [Repo Layout](#repo-layout)
- [Notes & Housekeeping](#notes--housekeeping)

---

## Architecture Overview

```
                     ┌─────────────────────┐
                     │   Faker-generated    │
                     │  dataset (120k rows) │
                     └──────────┬───────────┘
                                │
                                ▼
   ┌────────────────────────────────────────────────┐
   │                PostgreSQL 18                    │
   │  ┌───────────┐  ┌──────────────┐  ┌───────────┐ │
   │  │ customers │  │ transactions │  │  pgAudit  │ │
   │  └───────────┘  └──────────────┘  └─────┬─────┘ │
   │        RBAC: db_admin / analyst / readonly       │
   └────────────────────────┼─────────────────────────┘
                             │ writes
                             ▼
                 postgresql-18-main.log
                             │
              ┌──────────────┴───────────────┐
              ▼                               ▼
   scripts/log_parser.py          scripts/load_events_to_db.py
   (quick text-based alerts)      (loads events into Postgres)
                                             │
                                             ▼
                                  security_events table
                                             │
                                             ▼
                                    Grafana dashboard
                             (charts, tables, live monitoring)
```

**The core idea:** simulate normal activity and deliberate attacks against a
real, running database → verify pgAudit and RBAC actually catch/block them →
turn that evidence into both a written testing matrix and a live dashboard.

---

## Tech Stack

| Component | Purpose |
|---|---|
| **PostgreSQL 18** | The database under test |
| **pgAudit** | Detailed audit logging (auth, DDL, roles, reads/writes) |
| **Grafana** | Visualizes security events over time |
| **Python (Faker, psycopg2)** | Dataset generation + attack/normal-activity simulation |
| **Docker / Docker Compose** | Containerized setup path (method 2) |

---

## Setup

Two equivalent setup paths exist in this repo. Both produce an identical
environment — same schema, same roles, same pgAudit config — since Postgres
itself doesn't know or care whether it's containerized or installed directly.

| Path | When to use |
|---|---|
| **Docker**  | Default, recommended if Docker works on your machine |
| **Direct install** (below) | Fallback used when Docker Desktop had persistent startup issues |

### Method 1: Direct Install (Ubuntu / WSL2)

#### 1. Install Postgres + pgAudit

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib postgresql-18-pgaudit python3-pip python3-venv
```

#### 2. Enable pgAudit

Edit `/etc/postgresql/18/main/postgresql.conf` and set:

```ini
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write,ddl,role,read'
```

Restart Postgres to apply:

```bash
sudo service postgresql restart
```

#### 3. Create the database, extension, schema, and roles

```bash
sudo -u postgres psql
CREATE DATABASE bigdata_security;
\c bigdata_security
CREATE EXTENSION IF NOT EXISTS pgaudit;
-- then run the contents of postgres/init/02_schema.sql
-- then run the contents of postgres/init/03_roles.sql
```

#### 4. Set up Python and load the dataset

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

export PGHOST=localhost
export PGPORT=5432
export POSTGRES_DB=bigdata_security
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres

python3 data/generate_dataset.py --customers 20000 --transactions 100000
```

#### 5. Resuming work in a later session

Postgres doesn't start automatically after a reboot — start it manually
each time you pick the project back up:

```bash
sudo service postgresql start
cd Sec-Monitoring
source venv/bin/activate
```

Everything else (tables, roles, data, logs) persists on disk exactly as left.

---

## Roles & Access Control

| Role       | Attributes    | Access |
|------------|---------------|--------|
| `db_admin` | SUPERUSER     | Full control — used to test privilege-change alerts |
| `analyst`  | —             | `SELECT` on `customers` + `transactions` |
| `readonly` | —             | `SELECT` on `transactions` + masked `customer_public` view only (no raw PII) |

---

## Security Testing

**7 tests performed** — 1 above the required minimum of 6:

| # | Test | Result |
|---|------|--------|
| 1 | Brute-force failed login detection | ✅ Pass |
| 2 | Privilege escalation blocked | ✅ Pass |
| 3 | Bulk data export detection | ✅ Pass *(after config fix)* |
| 4 | PII access restriction | ✅ Pass |
| 5 | Audit logging survives restart | ✅ Pass |
| 6 | Normal vs. suspicious activity comparison | ✅ Pass |
| 7 | Role creation restricted to privileged users | ✅ Pass |

Full objective/procedure/expected/actual/evidence matrix:
**[`reports/tests_ubuntu.md`](reports/tests_ubuntu.md)**

Supporting screenshots and log excerpts: **`evidence_portfolio/`**

> **Key finding:** the initial pgAudit configuration (`write,ddl,role`) did
> not capture read-only bulk exports. This gap was identified during testing
> and corrected by adding `read` to `pgaudit.log` — after which bulk
> `SELECT` exports were fully captured. Documented as a hardening step in
> the final report's recommendations.

---

## Grafana Dashboard

Since pgAudit writes events to the Postgres **log file** as text (which
Grafana can't query directly), events are parsed and loaded into a
dedicated `security_events` table that Grafana queries live.

### Install (Ubuntu / WSL2)

```bash
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

Open **http://localhost:3000** — default login `admin` / `admin` (you'll be
prompted to set a new password on first login).

### Connect Grafana to Postgres

Add a **PostgreSQL** data source with:

| Field | Value |
|---|---|
| Host | `localhost:5432` |
| Database | `bigdata_security` |
| User / Password | your Postgres credentials |
| TLS/SSL Mode | `disable` *(local lab environment only)* |

### Create and populate the events table

```sql
CREATE TABLE IF NOT EXISTS security_events (
    event_id     SERIAL PRIMARY KEY,
    event_time   TIMESTAMP NOT NULL,
    event_type   TEXT NOT NULL,
    username     TEXT,
    detail       TEXT
);
GRANT SELECT ON security_events TO analyst, readonly;
```

Load (or refresh) events any time after running new tests/simulations:

```bash
python3 scripts/load_events_to_db.py /var/log/postgresql/postgresql-18-main.log
```

This clears and reloads the table on every run, so repeated runs never
produce duplicate rows — just refresh the Grafana dashboard page afterward
to see updated numbers.

### Dashboard panels

| Panel | Type | Shows |
|---|---|---|
| **Security Events Over Time** | Time series | Event counts grouped by type, over time |
| **Security Events by Type** | Bar / pie chart | Failed logins vs. privilege changes vs. bulk exports |
| **Recent Security Events** | Table | Timestamp, type, username, and raw log detail per event |

 Screenshot: `evidence_portfolio/screenshots_ubuntu/17_Grafana_Dashboard.PNG`

---

## Repo Layout

```
├── requirements.txt               Python dependencies
├── .env.example                     Template for DB credentials
│
├── postgres/init/                    Schema + role SQL (auto-run by Docker,
│                                       or run manually for direct install)
│   ├── 01_extensions.sql
│   ├── 02_schema.sql
│   └── 03_roles.sql
│
├── data/
│   └── generate_dataset.py            Faker-based 100k+ record generator
│
├── scripts/
│   ├── simulate_normal.py              Baseline "normal" activity
│   ├── simulate_suspicious.py          Attack simulation (3 scenarios)
│   ├── log_parser.py                    Quick text-based log alerting
│   └── load_events_to_db.py             Loads log events into Postgres
│                                          for Grafana
│
├── reports/
│   └── tests.md                          Full 7-test security matrix
│
└── evidence_portfolio/                     Screenshots, logs, terminal output
```

---

## Notes & Housekeeping

- `.env`, log files, generated CSVs, and `venv/` are gitignored — regenerate
  them locally rather than expecting them to be present in the repo.
- Default passwords in `postgres/init/03_roles.sql` (and the manual-install
  equivalent) should be changed before this is treated as anything beyond a
  lab environment.
- Both the Docker and direct-install paths are functionally equivalent —
  choose whichever works reliably on your machine.