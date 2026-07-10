# Group 9 – Database Security Monitoring

DSA 4030 Big Data Security end-of-semester project.
Scenario: a company suspects unauthorized database access. This repo builds a
Postgres environment with pgAudit logging, RBAC, and detection scripts for
failed logins, privilege changes, and large data exports.

## Quick start

```bash
cp .env.example .env          # edit if you want different creds
docker compose up -d --build  # starts Postgres (with pgAudit) + Grafana
```

Postgres is on `localhost:5432`, Grafana on `localhost:3000` (login: admin/admin).

Wait ~10s for the healthcheck, then load the dataset:

```bash
pip install -r requirements.txt
python data/generate_dataset.py --customers 20000 --transactions 100000
```

## Generate evidence

```bash
python scripts/simulate_normal.py       # baseline activity
python scripts/simulate_suspicious.py   # failed logins, priv escalation, bulk export
python scripts/log_parser.py postgres/logs/postgresql.log   # flags the anomalies
```

Take screenshots of terminal output + Grafana dashboards as you go and drop
them in `evidence/screenshots/` - don't leave this to the last day.

## Roles

| Role     | Access                                              |
|----------|------------------------------------------------------|
| db_admin | full control (superuser) - used to test priv changes |
| analyst  | SELECT on customers + transactions                    |
| readonly | SELECT on transactions + masked customer_public view  |

## Repo layout

```
docker-compose.yml       Postgres (pgAudit) + Grafana
Dockerfile                extends postgres:16 with pgaudit
postgres/init/            schema + roles, runs automatically on first boot
data/generate_dataset.py  Faker-based 100k+ record dataset generator
scripts/                  normal-activity, attack-simulation, log-parser
tests/                    security testing matrix (6 required tests)
evidence/                 screenshots, logs, terminal output
report/                   exec summary, architecture diagram, risk table
```

## Notes

- `.env`, logs, and generated CSVs are gitignored - don't commit them.
- Change the passwords in `postgres/init/03_roles.sql` before anyone treats
  this as anything other than a lab environment.
