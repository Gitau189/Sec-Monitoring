"""
Parses the Postgres log file and flags:
  - bursts of failed logins from the same user (possible brute force)
  - GRANT / ALTER ROLE statements (privilege changes)
  - SELECT statements against `transactions` with no LIMIT (possible bulk export)

Usage:
    python log_parser.py ../postgres/logs/postgresql.log
"""

import re
import sys
from collections import defaultdict

FAILED_LOGIN_RE = re.compile(r"password authentication failed for user \"(\w+)\"")
PRIV_CHANGE_RE = re.compile(r"statement:\s*(GRANT|REVOKE|ALTER ROLE).*", re.IGNORECASE)
BULK_SELECT_RE = re.compile(r"statement:\s*SELECT \* FROM transactions;?\s*$", re.IGNORECASE)

FAILED_LOGIN_THRESHOLD = 3


def analyze(path):
    failed_counts = defaultdict(int)
    findings = []

    with open(path, "r", errors="ignore") as f:
        for line in f:
            m = FAILED_LOGIN_RE.search(line)
            if m:
                user = m.group(1)
                failed_counts[user] += 1
                if failed_counts[user] == FAILED_LOGIN_THRESHOLD:
                    findings.append(f"[ALERT] {failed_counts[user]}+ failed logins for user '{user}' - possible brute force")

            m = PRIV_CHANGE_RE.search(line)
            if m:
                findings.append(f"[ALERT] Privilege change detected: {line.strip()}")

            if BULK_SELECT_RE.search(line):
                findings.append(f"[ALERT] Bulk/unbounded export detected: {line.strip()}")

    print(f"Analyzed {path}")
    print(f"Failed login counts by user: {dict(failed_counts)}\n")
    if findings:
        print(f"{len(findings)} finding(s):")
        for f_ in findings:
            print(" ", f_)
    else:
        print("No suspicious patterns matched.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python log_parser.py <path-to-postgresql.log>")
        sys.exit(1)
    analyze(sys.argv[1])
