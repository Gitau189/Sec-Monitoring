"""
Simulates normal, everyday database activity as the 'analyst' and
'readonly' roles - small, occasional SELECT queries. This is your
baseline for comparison against the suspicious activity script.

Usage:
    python simulate_normal.py
"""

import os
import random
import time

import psycopg2

DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = os.environ.get("PGPORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "bigdata_security")


def run_as(user, password, query, params=None):
    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=user, password=password)
    cur = conn.cursor()
    cur.execute(query, params)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


if __name__ == "__main__":
    for _ in range(15):
        cid = random.randint(1, 1000)
        rows = run_as("analyst", "analyst_pw_change_me",
                       "SELECT * FROM transactions WHERE customer_id = %s LIMIT 10", (cid,))
        print(f"[normal] analyst looked up customer {cid}: {len(rows)} rows")
        time.sleep(random.uniform(0.5, 2))

    for _ in range(10):
        rows = run_as("readonly", "readonly_pw_change_me",
                       "SELECT * FROM customer_public LIMIT 20")
        print(f"[normal] readonly browsed customer_public: {len(rows)} rows")
        time.sleep(random.uniform(0.5, 2))
