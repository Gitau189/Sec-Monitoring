#!/usr/bin/env python3
"""
Generate the demo dataset for DSA4030 Group 9 (Database Security Monitoring).

Produces three CSV files in data/generated/ that are COPY-loaded into the
`company` schema (see README `make load`):

    customers.csv     120,000 rows  (PII: name, email, SSN, credit score)
    transactions.csv  200,000 rows  (financial records)
    employees.csv       2,000 rows

Total ~322,000 records — comfortably above the 100,000 minimum (Part B).

Standard library only, so no `pip install` is required. Deterministic via a
fixed seed so every teammate generates identical data.
"""
import csv
import os
import random
from datetime import datetime, timedelta

random.seed(4030)

OUT_DIR = os.path.join(os.path.dirname(__file__), "generated")
os.makedirs(OUT_DIR, exist_ok=True)

N_CUSTOMERS = 120_000
N_TRANSACTIONS = 200_000
N_EMPLOYEES = 2_000

FIRST = ["James", "Mary", "John", "Amina", "Wei", "Fatima", "Carlos", "Priya",
         "David", "Sofia", "Kwame", "Yuki", "Ahmed", "Grace", "Ivan", "Lena",
         "Omar", "Chen", "Nadia", "Diego"]
LAST = ["Smith", "Johnson", "Otieno", "Wang", "Garcia", "Khan", "Mueller",
        "Silva", "Kimani", "Tanaka", "Ali", "Brown", "Nguyen", "Dubois",
        "Okafor", "Rossi", "Haddad", "Kim", "Ivanov", "Mwangi"]
COUNTRIES = ["Kenya", "USA", "UK", "India", "Germany", "Nigeria", "Japan",
             "Brazil", "UAE", "France", "China", "South Africa"]
DEPTS = ["Engineering", "Finance", "Sales", "HR", "Security", "Operations"]
TITLES = ["Analyst", "Manager", "Engineer", "Director", "Associate", "Lead"]
TXN_TYPES = ["purchase", "refund", "transfer", "withdrawal"]
STATUSES = ["approved", "approved", "approved", "declined", "flagged"]
CURRENCIES = ["USD", "EUR", "KES", "GBP", "JPY"]

START = datetime(2023, 1, 1)


def rand_dt(days_back):
    return START + timedelta(
        seconds=random.randint(0, days_back * 86_400)
    )


def gen_customers(path):
    print(f"  customers   -> {N_CUSTOMERS:,} rows")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        for i in range(1, N_CUSTOMERS + 1):
            name = f"{random.choice(FIRST)} {random.choice(LAST)}"
            email = f"user{i}@example.com"
            phone = f"+{random.randint(1, 99)}{random.randint(10**8, 10**9 - 1)}"
            country = random.choice(COUNTRIES)
            ssn = f"{random.randint(100,999)}-{random.randint(10,99)}-{random.randint(1000,9999)}"
            score = random.randint(300, 850)
            created = rand_dt(900).isoformat()
            w.writerow([i, name, email, phone, country, ssn, score, created])


def gen_transactions(path):
    print(f"  transactions-> {N_TRANSACTIONS:,} rows")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        for i in range(1, N_TRANSACTIONS + 1):
            cust = random.randint(1, N_CUSTOMERS)
            amount = round(random.uniform(1, 10_000), 2)
            w.writerow([
                i, cust, amount, random.choice(CURRENCIES),
                random.choice(TXN_TYPES), random.choice(STATUSES),
                rand_dt(900).isoformat(),
            ])


def gen_employees(path):
    print(f"  employees   -> {N_EMPLOYEES:,} rows")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        for i in range(1, N_EMPLOYEES + 1):
            name = f"{random.choice(FIRST)} {random.choice(LAST)}"
            salary = round(random.uniform(30_000, 200_000), 2)
            hired = (START - timedelta(days=random.randint(0, 3650))).date().isoformat()
            w.writerow([
                i, name, random.choice(DEPTS), random.choice(TITLES),
                salary, hired,
            ])


def main():
    print("Generating dataset (seed=4030)...")
    gen_customers(os.path.join(OUT_DIR, "customers.csv"))
    gen_transactions(os.path.join(OUT_DIR, "transactions.csv"))
    gen_employees(os.path.join(OUT_DIR, "employees.csv"))
    total = N_CUSTOMERS + N_TRANSACTIONS + N_EMPLOYEES
    print(f"Done. {total:,} total records written to {OUT_DIR}")


if __name__ == "__main__":
    main()
