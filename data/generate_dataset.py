"""
Generates synthetic customers + transactions data (100,000+ records)
and loads it into Postgres. Also writes CSVs locally as a fallback /
for the evidence portfolio (these are gitignored - don't commit them).

Usage:
    pip install faker psycopg2-binary
    python generate_dataset.py --customers 20000 --transactions 100000
"""

import argparse
import csv
import os
import random

from faker import Faker
import psycopg2

fake = Faker()

DB_PARAMS = dict(
    host=os.environ.get("PGHOST", "localhost"),
    port=os.environ.get("PGPORT", "5432"),
    dbname=os.environ.get("POSTGRES_DB", "bigdata_security"),
    user=os.environ.get("POSTGRES_USER", "postgres"),
    password=os.environ.get("POSTGRES_PASSWORD", "changeme"),
)


def generate_customers(n):
    rows = []
    for i in range(1, n + 1):
        rows.append((
            i,
            fake.name(),
            fake.email(),
            fake.phone_number(),
            fake.ssn(),
            fake.date_time_between(start_date="-3y", end_date="now"),
        ))
    return rows


def generate_transactions(n, customer_count):
    rows = []
    for i in range(1, n + 1):
        rows.append((
            i,
            random.randint(1, customer_count),
            round(random.uniform(2, 2500), 2),
            fake.company(),
            f"{random.randint(0,9999):04d}",
            fake.date_time_between(start_date="-1y", end_date="now"),
        ))
    return rows


def write_csv(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows -> {path}")


def load_to_postgres(customers, transactions):
    conn = psycopg2.connect(**DB_PARAMS)
    cur = conn.cursor()

    cur.executemany(
        """INSERT INTO customers (customer_id, full_name, email, phone, national_id, created_at)
           VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT (customer_id) DO NOTHING""",
        customers,
    )
    cur.executemany(
        """INSERT INTO transactions (transaction_id, customer_id, amount, merchant, card_last4, transaction_date)
           VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT (transaction_id) DO NOTHING""",
        transactions,
    )

    # keep the SERIAL sequences in sync after manual-id inserts
    cur.execute("SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers))")
    cur.execute("SELECT setval('transactions_transaction_id_seq', (SELECT MAX(transaction_id) FROM transactions))")

    conn.commit()
    cur.close()
    conn.close()
    print(f"loaded {len(customers)} customers and {len(transactions)} transactions into Postgres")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--customers", type=int, default=20000)
    parser.add_argument("--transactions", type=int, default=100000)
    parser.add_argument("--csv-only", action="store_true", help="skip DB load, just write CSVs")
    args = parser.parse_args()

    customers = generate_customers(args.customers)
    transactions = generate_transactions(args.transactions, args.customers)

    write_csv("data/customers.csv",
              ["customer_id", "full_name", "email", "phone", "national_id", "created_at"],
              customers)
    write_csv("data/transactions.csv",
              ["transaction_id", "customer_id", "amount", "merchant", "card_last4", "transaction_date"],
              transactions)

    if not args.csv_only:
        load_to_postgres(customers, transactions)
