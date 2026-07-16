"""
Parses the Postgres/pgAudit log file for security events (failed logins,
privilege changes, bulk exports) and inserts them as rows into the
security_events table, so Grafana can chart them over time.

Usage:
    python3 load_events_to_db.py /var/log/postgresql/postgresql-18-main.log
"""

import os
import re
import sys
from datetime import datetime

import psycopg2

DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = os.environ.get("PGPORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "bigdata_security")
DB_USER = os.environ.get("POSTGRES_USER", "postgres")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "postgres")

# Postgres log lines start with a timestamp like:
# 2026-07-15 20:34:57.337 EAT [4533] ...
TIMESTAMP_RE = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+ \w+ \[\d+\]")

FAILED_LOGIN_RE = re.compile(r"password authentication failed for user \"(\w+)\"")
PRIV_CHANGE_RE = re.compile(r"ERROR:\s*permission denied to (alter role|create role)")
PRIV_STATEMENT_RE = re.compile(r"STATEMENT:\s*(ALTER ROLE .*|CREATE ROLE .*)", re.IGNORECASE)
BULK_EXPORT_RE = re.compile(r"AUDIT:.*READ,SELECT,,,SELECT \* FROM transactions")

USER_RE = re.compile(r"\[\d+\]\s+(\w+)@")


def parse_timestamp(line):
    m = TIMESTAMP_RE.match(line)
    if not m:
        return None
    return datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")


def extract_user(line):
    m = USER_RE.search(line)
    return m.group(1) if m else None


def analyze(path):
    events = []
    with open(path, "r", errors="ignore") as f:
        for line in f:
            ts = parse_timestamp(line)
            if not ts:
                continue

            m = FAILED_LOGIN_RE.search(line)
            if m:
                events.append((ts, "failed_login", m.group(1), line.strip()))
                continue

            if PRIV_CHANGE_RE.search(line):
                user = extract_user(line)
                events.append((ts, "privilege_change_blocked", user, line.strip()))
                continue

            if BULK_EXPORT_RE.search(line):
                user = extract_user(line)
                events.append((ts, "bulk_export", user, line.strip()))
                continue

    return events


def load(events):
    if not events:
        print("No events found to load.")
        return

    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
                             user=DB_USER, password=DB_PASSWORD)
    cur = conn.cursor()
    cur.executemany(
        """INSERT INTO security_events (event_time, event_type, username, detail)
           VALUES (%s, %s, %s, %s)""",
        events,
    )
    conn.commit()
    cur.close()
    conn.close()
    print(f"Inserted {len(events)} security events into security_events table.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 load_events_to_db.py <path-to-postgresql.log>")
        sys.exit(1)

    events = analyze(sys.argv[1])
    print(f"Found {len(events)} events in log:")
    counts = {}
    for _, etype, _, _ in events:
        counts[etype] = counts.get(etype, 0) + 1
    for etype, count in counts.items():
        print(f"  {etype}: {count}")

    load(events)