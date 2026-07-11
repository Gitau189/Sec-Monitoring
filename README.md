# Database Security Monitoring — DSA 4030 Group 9

> **Scenario:** A company suspects unauthorized database access. We were hired as
> a cybersecurity consulting team to **audit the database, monitor failed logins
> and privilege changes, detect large data exports, and produce security reports.**

This repository is a complete, self-contained monitoring lab built with
open-source software. One command brings up a monitored PostgreSQL database and
a full observability stack (Prometheus + Loki + Grafana) that turns database
activity into dashboards, alerts, and evidence.

---

## 1. Architecture

```
                         ┌──────────────────────────────────────────┐
                         │                 Grafana                  │
                         │   Dashboard: "Database Security Monitoring"│
                         │   (failed logins, privilege changes,      │
                         │    exports, sessions, alerts)             │
                         └───────────────▲───────────────▲──────────┘
                                         │ metrics       │ logs
                              ┌──────────┴───┐      ┌─────┴───────┐
                              │  Prometheus  │      │    Loki     │
                              │ + alert rules│      │ (log store) │
                              └──────▲───────┘      └─────▲───────┘
                                     │ scrape             │ push
                         ┌───────────┴──────┐       ┌─────┴────────┐
                         │ postgres_exporter│       │   Promtail   │
                         │ (custom security │       │ (tails + tags│
                         │     queries)     │       │  DB logs)    │
                         └───────────▲──────┘       └─────▲────────┘
                                     │ SQL                │ reads log files
                         ┌───────────┴────────────────────┴──────────┐
                         │        PostgreSQL 16 + pgAudit             │
                         │  company DB · RBAC roles · 322k records    │
                         │  audit log -> /var/log/postgresql/*.log    │
                         └────────────────────────────────────────────┘
```

**Two complementary signal paths:**

| Path | Tooling | Answers |
|------|---------|---------|
| **Metrics** | postgres_exporter → Prometheus | *How many* superusers / grants / rows-read / sessions? Trigger alerts. |
| **Logs** | pgAudit → Promtail → Loki | *Exactly what happened* — the audited SQL statement, the failed username, the GRANT. |

This maps directly to the assignment: metrics power the **at-a-glance dashboards
and alerting**, while the audit log is the **forensic evidence trail**.

---

## 2. Tech stack (all open-source — Part A)

| Component | Image / Tool | Role in the project |
|-----------|-------------|---------------------|
| **Data source** | CSV (Python-generated) | 322,000 records of customers, transactions, employees |
| **Storage** | PostgreSQL 16 | The database under investigation |
| **Security tool** | **pgAudit** | Database auditing engine (role, DDL, read, write) |
| **Security tool** | SCRAM-SHA-256 + RBAC | Authentication + least-privilege access control |
| **Metrics** | postgres_exporter | Exposes security metrics to Prometheus |
| **Metrics store** | Prometheus | Time-series + alert rules |
| **Logging** | Loki + Promtail | Collects, classifies and stores DB logs |
| **Dashboards** | Grafana | Single pane of glass + alerting |
| **Orchestration** | Docker Compose | One-command environment |

---

## 3. Prerequisites

- **Docker** + **Docker Compose v2** (`docker compose version`)
- **Python 3.9+** (only the standard library is used — no `pip install`)
- ~2 GB free disk, ports `3000, 3100, 5432, 9090, 9187` free
  - If you already run a local PostgreSQL on **5432**, set `POSTGRES_PORT=5433`
    in `.env` (see step 1).

---

## 4. Quick start (5 commands)

```bash
# 1. Configure environment (copy the template; edit if a port clashes)
cp .env.example .env

# 2. Generate the dataset (322,000 records → data/generated/*.csv)
make data

# 3. Build + start the whole stack
make up

# 4. Load the data into PostgreSQL
make load

# 5. Run the six security tests to generate evidence
make tests
```

Then open **Grafana → http://localhost:3000** (login `admin` / `admin`) and open
the **"Database Security Monitoring — Group 9"** dashboard.

> Don't have `make`? Every target is a thin wrapper — see [section 8](#8-command-reference)
> for the raw `docker` / `docker compose` equivalents.

---

## 5. Where to look (URLs & credentials)

| Service | URL | Login |
|---------|-----|-------|
| **Grafana** (dashboards) | http://localhost:3000 | `admin` / `admin` |
| **Prometheus** (metrics + alerts) | http://localhost:9090 | — |
| Prometheus alerts | http://localhost:9090/alerts | — |
| postgres_exporter (raw metrics) | http://localhost:9187/metrics | — |
| Loki (queried via Grafana → Explore) | http://localhost:3100 | — |

### Database accounts (demo passwords — **not for production**)

| Role | Password | Privilege | Purpose |
|------|----------|-----------|---------|
| `postgres` | `postgres` | superuser | bootstrap / admin |
| `dba_mike` | `dba_pw` | `app_admin` | database administrator |
| `svc_app` | `app_service_pw` | `app_write` | application service account |
| `analyst_jane` | `analyst_pw` | `app_analyst` | runs reports |
| `report_bot` | `report_pw` | `app_read` (read-only) | reporting bot |
| `intern_bob` | `intern_pw` | `app_read` (low-priv) | escalation-test subject |
| `exporter` | `exporter_pw` | `pg_monitor` | Prometheus monitoring |

---

## 6. Mapping to the assignment rubric

### Part A — Environment setup ✅
Docker Compose builds a data source (CSV), storage (PostgreSQL), security tools
(pgAudit, RBAC, SCRAM) and logging (pgAudit → Promtail → Loki). See `docker-compose.yml`.

### Part B — Dataset ✅
`data/generate_data.py` generates **322,000 records** (min. 100,000 required):
120k customers (with PII/SSN), 200k transactions, 2k employees. Deterministic
(`seed=4030`) so everyone gets identical data.

### Part C — Security controls ✅
| Control | Where |
|---------|-------|
| Authentication | `pg_hba.conf` → SCRAM-SHA-256 |
| Role-based access control | `initdb/02_roles.sql`, `03_schema.sql` |
| Integrity / auditing | `pgAudit` in `postgresql.conf` |
| Logging | `logging_collector`, `log_connections`, Promtail/Loki |
| Monitoring | Prometheus metrics + Grafana + alert rules |
| Data-export detection | `pg_stat_statements` + `v_large_reads` view |

### Part D — Security testing ✅
Six automated tests in `tests/security_tests.sh` (see [section 7](#7-security-tests-part-d)).

### Part E — Recommendations ✅
See [`docs/RECOMMENDATIONS.md`](docs/RECOMMENDATIONS.md) — vulnerabilities found,
remaining risks, and improvements.

---

## 7. Security tests (Part D)

Run all with `make tests`, or one at a time: `./tests/security_tests.sh 3`.
Each test prints its **Objective / Procedure / Expected / Actual**, and the
activity becomes visible **evidence** in Grafana, Prometheus and the audit log.

| # | Test | Required task addressed | Evidence to screenshot |
|---|------|------------------------|------------------------|
| 1 | pgAudit is enabled | *Configure database auditing* | `SHOW pgaudit.log` output + audit lines in log |
| 2 | Failed-login brute-force (8 attempts) | *Monitor failed logins* | Grafana "Failed login events" panel |
| 3 | Privilege escalation (`GRANT` + `SUPERUSER`) | *Monitor privilege changes* | "Privilege change events" panel; `NewSuperuserDetected` alert |
| 4 | Bulk export of 120k customer rows (incl. SSN) | *Detect large data exports* | "Rows returned per user" panel; `v_large_reads` view |
| 5 | RBAC: read-only account tries to `DELETE` | *(least-privilege control)* | `permission denied` error |
| 6 | Passwords use SCRAM-SHA-256 | *(auth control)* | `pg_authid` hash prefixes |

> ⚠️ **Test 3 makes `intern_bob` a superuser.** Always undo it afterwards:
> ```bash
> make revert
> ```

### Reading the evidence in Grafana
1. Open the **Database Security Monitoring** dashboard for the live overview.
2. For raw audit lines: **Explore → Loki** and query, e.g.
   - Failed logins: `{job="postgresql", category="failed_login"}`
   - Privilege changes: `{job="postgresql", category="privilege_change"}`
   - Large reads: `{job="postgresql", category="audit_read"}`
3. For the written report, run the SQL views directly:
   ```bash
   make psql
   SELECT * FROM company.v_superusers;
   SELECT * FROM company.v_role_grants;
   SELECT * FROM company.v_large_reads;
   SELECT * FROM company.v_active_sessions;
   ```

---

## 8. Command reference

| `make` target | What it does | Raw equivalent |
|---------------|--------------|----------------|
| `make data` | Generate the dataset | `python3 data/generate_data.py` |
| `make up` | Build + start stack | `docker compose up -d --build` |
| `make load` | Load CSVs into Postgres | `docker exec -i -e PGPASSWORD=postgres sm_postgres psql -U postgres -d company < data/load_data.sql` |
| `make tests` | Run all 6 security tests | `./tests/security_tests.sh all` |
| `make revert` | Undo test-3 escalation | `./tests/security_tests.sh revert` |
| `make logs` | Tail the audit log | `docker exec sm_postgres tail -f /var/log/postgresql/postgresql.log` |
| `make psql` | psql shell (superuser) | `docker exec -it -e PGPASSWORD=postgres sm_postgres psql -U postgres -d company` |
| `make status` | Container status | `docker compose ps` |
| `make down` | Stop (keep data) | `docker compose down` |
| `make nuke` | Stop + delete all volumes | `docker compose down -v` |

---

## 9. Repository layout

```
Sec-Monitoring/
├── docker-compose.yml         # the whole stack
├── Makefile                   # one-command operations
├── .env.example               # config template (copy to .env)
├── postgres/
│   ├── Dockerfile             # PostgreSQL 16 + pgAudit
│   ├── postgresql.conf        # auditing + logging config
│   ├── pg_hba.conf            # SCRAM authentication
│   └── initdb/                # runs once on first boot:
│       ├── 01_extensions.sql  #   pgaudit, pg_stat_statements
│       ├── 02_roles.sql       #   RBAC roles + login accounts
│       ├── 03_schema.sql      #   company schema + grants
│       └── 04_monitoring_views.sql  # security report views
├── data/
│   ├── generate_data.py       # 322k-record generator (stdlib only)
│   └── load_data.sql          # COPY loader
├── postgres_exporter/queries.yaml   # custom security metrics
├── prometheus/
│   ├── prometheus.yml         # scrape config
│   └── alerts.yml             # 5 security alert rules
├── loki/loki-config.yml
├── promtail/promtail-config.yml     # log parsing + security tagging
├── grafana/
│   ├── provisioning/          # auto-wired datasources + dashboard loader
│   └── dashboards/db-security.json  # the Security dashboard
├── tests/security_tests.sh    # the 6 security tests (Part D)
└── docs/RECOMMENDATIONS.md     # Part E write-up
```

---

## 10. How it works (for the write-up / presentation)

**Auditing.** `postgresql.conf` sets `shared_preload_libraries = 'pgaudit,...'`
and `pgaudit.log = 'role, ddl, write, read'`. Every qualifying statement is
written to `/var/log/postgresql/postgresql.log` as an `AUDIT:` line including the
user, object and full SQL text.

**Failed logins.** `log_connections = on` makes PostgreSQL log every
authentication attempt, including `FATAL: password authentication failed`.

**Log classification.** Promtail tails the log file and, using the regex pipeline
in `promtail-config.yml`, tags each line with a `category` label
(`failed_login`, `privilege_change`, `audit_read`, `audit_write`, `audit_ddl`)
before pushing to Loki — so Grafana can filter instantly.

**Metrics & alerting.** postgres_exporter runs the SQL in `queries.yaml` (e.g.
count superusers, count role grants, rows returned per user) and exposes them to
Prometheus, which evaluates `alerts.yml` — firing `NewSuperuserDetected`,
`LargeDataExport`, etc.

**Reports.** The `company.v_*` views (superusers, role grants, large reads, active
sessions) are ready-made SQL for the security report, and are also charted in
Grafana.

---

## 11. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `bind: address already in use` on 5432 | You have a local Postgres. Set `POSTGRES_PORT=5433` in `.env`, then `make up`. |
| `Cannot connect to the Docker daemon` | Start Docker Desktop / `sudo systemctl start docker`. |
| Grafana panels empty | Give it ~30s after `make up`; ensure `make load` ran; check `make status`. |
| No failed-login logs in Loki | They appear a few seconds after the attempt; check `category` label exists via Grafana Explore. |
| `password authentication failed` on `make psql` | Expected for wrong creds — the Makefile injects the right password automatically. |
| Start completely fresh | `make nuke && make up && make load` |

---

## 12. Team responsibilities

| Area | Owner | Files |
|------|-------|-------|
| **Infrastructure / DevOps** | *(this setup)* | `docker-compose.yml`, `Makefile`, `postgres/`, Prometheus/Loki/Grafana configs, README |
| Dataset | | `data/` |
| Security controls & tests | | `tests/`, `initdb/` |
| Report & recommendations | | `docs/RECOMMENDATIONS.md` |

---

*DSA 4030 — Big Data Security · Group 9 · Database Security Monitoring*
