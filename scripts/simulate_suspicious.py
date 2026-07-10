"""
Simulates the three suspicious behaviors Group 9 needs to detect:
  1. Failed logins (brute force attempt)
  2. Privilege escalation attempt
  3. Large / bulk data export

Run this AFTER simulate_normal.py so your logs show a clear baseline
followed by an anomaly - good evidence for the testing matrix.

Usage:
    python simulate_suspicious.py
"""

import os
import psycopg2

DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = os.environ.get("PGPORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "bigdata_security")


def failed_login_attempts(n=8):
    print(f"\n--- simulating {n} failed login attempts (brute force) ---")
    for i in range(n):
        try:
            psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
                              user="readonly", password="WRONG_PASSWORD")
        except psycopg2.OperationalError as e:
            print(f"  attempt {i+1}: failed as expected ({str(e).strip()})")


def privilege_escalation_attempt():
    print("\n--- simulating privilege escalation attempt (analyst trying to self-grant) ---")
    try:
        conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
                                 user="analyst", password="analyst_pw_change_me")
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("ALTER ROLE analyst SUPERUSER;")
        print("  WARNING: escalation succeeded - this should NOT happen with correct RBAC")
    except psycopg2.errors.InsufficientPrivilege as e:
        print(f"  blocked as expected: {str(e).strip()}")
    except Exception as e:
        print(f"  blocked/error: {str(e).strip()}")


def large_data_export():
    print("\n--- simulating large/bulk data export (readonly pulling entire table) ---")
    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
                             user="readonly", password="readonly_pw_change_me")
    cur = conn.cursor()
    cur.execute("SELECT * FROM transactions;")  # no LIMIT - grabs everything
    rows = cur.fetchall()
    print(f"  exported {len(rows)} rows in a single query (far above the ~10-20 row normal pattern)")
    cur.close()
    conn.close()


if __name__ == "__main__":
    failed_login_attempts()
    privilege_escalation_attempt()
    large_data_export()
    print("\nDone. Check postgres/logs/postgresql.log and pgAudit output for the evidence trail.")
