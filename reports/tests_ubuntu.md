# Security Testing Matrix — Group 9: Database Security Monitoring

7 tests were performed against the live Postgres + pgAudit environment. Each test simulates a
real, executable action against the database — not a hypothetical — and
checks whether the configured security controls (RBAC, pgAudit logging)
correctly detected or blocked it.

Screenshots referenced below are stored in `evidence_portfolio/screenshots_ubuntu`.

---

## Test 1: Brute-force failed login detection

- **Objective:** Verify that repeated failed login attempts are captured in
  the audit log, as evidence of a possible brute-force attack.
- **Procedure:** Ran `scripts/simulate_suspicious.py`'s failed-login function,
  attempting to connect as `readonly` with an incorrect password 8 times.
- **Expected result:** Each failed attempt should generate a `FATAL: password
  authentication failed` log entry, including timestamp and username.
- **Actual result:** All 8 attempts (34 cumulative across the full testing
  session) were logged with timestamp, matched `pg_hba.conf` rule, and the
  target username (`readonly`).
- **Evidence:** 
---
`test1_failed_logins.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/06_test1_failed_logins.PNG)
---
`test1_failed_logins_log.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/07_test1_failedlogins_logs.PNG)
---

## Test 2: Privilege escalation blocked

- **Objective:** Verify that a non-superuser role cannot grant itself
  elevated privileges.
- **Procedure:** As the `analyst` role, ran `ALTER ROLE analyst SUPERUSER;`.
- **Expected result:** The statement should be denied, since `analyst` lacks
  the SUPERUSER attribute required to modify it.
- **Actual result:** Denied with `ERROR: permission denied to alter role` /
  `DETAIL: Only roles with the SUPERUSER attribute may change the SUPERUSER
  attribute.` The exact statement was captured in the log.
- **Evidence:** 
---
`test2_privilege_escalation_blocked.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/08_test2_privilege_escalation_blocked.PNG)
---
`test2_privilege_escalation_blocked_log.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/09_test2_privilege_escalation_blocked_log.PNG)
---

## Test 3: Bulk/large data export detection

- **Objective:** Verify that an unusually large, unbounded data export is
  captured by the audit log.
- **Procedure:** As the `readonly` role, ran `SELECT * FROM transactions;`
  (no `WHERE`, no `LIMIT`) against a table of 100,000 rows.
- **Expected result:** pgAudit should log the full read statement, since
  `pgaudit.log` includes `read`.
- **Actual result:** pgAudit recorded the exact statement:
  `AUDIT: SESSION,1,1,READ,SELECT,,,SELECT * FROM transactions,<not logged>`.
  Note: this required adding `read` to the `pgaudit.log` setting — the
  initial configuration (`write,ddl,role`) did not capture read-only
  queries. This gap was identified during testing and corrected (see
  Recommendations in the final report).
- **Evidence:** 
---
`test3_bulk_export_detected.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/10_test3_bulk_export_detected.PNG)
---
`test3_bulk_export_detected_log.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/11_test3_bulk_export_detected_log.PNG)
---

## Test 4: PII access restriction (RBAC enforcement)

- **Objective:** Verify that the `readonly` role cannot access raw
  personally identifiable information (email, phone, national ID) in the
  `customers` table, and is limited to the masked `customer_public` view.
- **Procedure:** As `readonly`, ran `SELECT * FROM customers;` directly.
- **Expected result:** Should be denied, since `readonly` was only granted
  `SELECT` on `customer_public` (a view excluding sensitive columns), not on
  the raw `customers` table.
- **Actual result:** Denied with `ERROR: permission denied for table
  customers`.
- **Evidence:**
--- 
`test4_pii_access_denied.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/12_test4_pii_access_denied.PNG)
---
`test4_pii_access_denied_log.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/13_test4_pii_access_denied_log.PNG)
---

## Test 5: Audit logging persists across a database restart

- **Objective:** Verify that pgAudit remains active after a Postgres
  restart, rather than requiring manual re-enabling.
- **Procedure:** Ran `sudo service postgresql restart`, then inspected the
  log for confirmation that pgAudit reloaded.
- **Expected result:** The log should show `pgaudit extension initialized`
  again after the restart, with no manual intervention required.
- **Actual result:** Confirmed — `pgaudit extension initialized` appeared
  immediately after the restart, before the "ready to accept connections"
  message.
- **Evidence:** 
---
`test5_audit_survives_restart.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/14_test5_audit_survives_restart.PNG)
---

## Test 6: Normal vs. suspicious activity — quantified comparison

- **Objective:** Establish a quantifiable, structural distinction between
  normal and suspicious database activity, beyond a visual comparison.
- **Procedure:** Ran `scripts/simulate_normal.py` (scoped queries with
  `WHERE`/`LIMIT`, 2-20 rows returned) followed by
  `scripts/simulate_suspicious.py` (unbounded full-table query). Counted
  occurrences of failed logins and bulk-export patterns in the log via
  `grep`.
- **Expected result:** Suspicious activity should be structurally
  distinguishable from normal activity — specifically, larger row counts,
  missing `WHERE`/`LIMIT` clauses, and correlation with other anomalies
  (failed logins, privilege attempts) in the same time window.
- **Actual result:** Normal activity generated 0 failed logins and only
  small, scoped queries. Suspicious activity generated 34 logged failed
  login attempts and exactly 1 unbounded full-table query returning
  100,000 rows — a clean signal with no false positives from legitimate
  traffic. This demonstrates a detection rule such as "flag any query
  without WHERE/LIMIT returning >1000 rows" or "flag >5 failed logins in
  under 1 minute" would be effective here.
- **Evidence:** 
---
`test6_normal_vs_suspicious_comparison.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/15_test6_normal_vs_suspicious_comparison.PNG)
---

## Test 7: Role creation restricted to privileged users

- **Objective:** Verify that ordinary roles (not just superusers) cannot
  create new database roles — a potential backdoor-account vector if left
  unrestricted.
- **Procedure:** As `analyst`, ran `CREATE ROLE test_intruder WITH LOGIN
  PASSWORD 'x';`.
- **Expected result:** Should be denied, since `analyst` lacks the
  CREATEROLE attribute.
- **Actual result:** Denied with `ERROR: permission denied to create role`
  / `DETAIL: Only roles with the CREATEROLE attribute may create roles.`
- **Evidence:** 
---
`test7_role_creation_denied.png`
![alt text](../evidence_portfolio/screenshots_ubuntu/16_test7_role_creation_denied.PNG)

---

## Summary

| # | Test | Result |
|---|------|--------|
| 1 | Brute-force login detection | Pass |
| 2 | Privilege escalation blocked | Pass |
| 3 | Bulk data export detection | Pass (after config fix) |
| 4 | PII access restriction | Pass |
| 5 | Audit logging survives restart | Pass |
| 6 | Normal vs. suspicious comparison | Pass |
| 7 | Role creation restriction | Pass |

All 7 tests passed. One configuration gap was discovered and corrected
during testing (Test 3), demonstrating the value of active security testing
over static configuration review alone.
---

## Supplementary Evidence: Grafana Dashboard

While each test above is independently backed by terminal output and raw
log excerpts, a Grafana dashboard was also built to provide a live,
visual view of the same security events — closer to how a real security
operations team would monitor a production database on an ongoing basis,
rather than reviewing raw log files after the fact.

- **Objective:** Provide a consolidated, at-a-glance view of security
  events (failed logins, blocked privilege changes, bulk exports) that
  updates as new tests are run, rather than requiring manual log review.
- **Procedure:** pgAudit/Postgres log events were parsed by
  `scripts/load_events_to_db.py` and loaded into a dedicated
  `security_events` table, which Grafana queries directly via a PostgreSQL
  data source.
- **Expected result:** The dashboard should reflect the same event counts
  already confirmed in Tests 1, 2, 3, and 6 above (34 failed logins, 3
  blocked privilege changes, 1 bulk export).
- **Actual result:** The dashboard's three panels correctly displayed:
  - **Security Events Over Time** — a time series showing when each event
    type occurred, with the failed-login burst and the single bulk-export
    spike clearly visible
  - **Security Events by Type** — a summary chart confirming 34 failed
    logins, 3 blocked privilege changes, and 1 bulk export, matching the
    counts obtained independently via `grep` in Test 6
  - **Recent Security Events** — a detailed table listing each event's
    timestamp, type, username, and raw log detail, allowing drill-down
    into any specific event
- **Evidence:** `evidence_portfolio/screenshots_ubuntu/17_Grafana_Dashboard.png`

This confirms the security event data is consistent across three
independent views — raw log file, `grep`-based counts, and the Grafana
dashboard — with no discrepancies.

```
http://localhost:3000/public-dashboards/89e304baa6c949f8bcf3dfde190604d0
```
```
http://localhost:3000/dashboard/snapshot/teZID91zDCFivTcP0RhuNhkJdCnFS2nC
```