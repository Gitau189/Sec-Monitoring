# Part E — Recommendations

> Starter write-up for the report team. Fill in screenshots/evidence from your
> own `make tests` run. Everything below is grounded in what this environment
> actually demonstrates.

## 1. Vulnerabilities identified

| # | Vulnerability | How it was found | Risk |
|---|---------------|------------------|------|
| V1 | **Privilege escalation is possible** — an admin/superuser can grant `SUPERUSER` to a low-privilege account (`intern_bob`) | Test 3 | Critical — a compromised admin account can hand full control to any user |
| V2 | **Bulk export of sensitive PII is unrestricted** — `report_bot` exported all 120k customer rows including SSNs | Test 4 | High — mass data exfiltration of regulated data |
| V3 | **Weak / shared demo passwords** — short, guessable credentials; no lockout after repeated failures | Test 2 (8 failed logins, no throttling) | High — brute-force / credential stuffing |
| V4 | **Sensitive columns stored in plaintext** — `ssn`, `credit_score` are readable by anyone with `SELECT` | Schema review | High — no defence-in-depth if a read account leaks |
| V5 | **No network encryption enforced** — `sslmode=disable` between services | Config review | Medium — traffic sniffable on a shared network |

## 2. Controls that worked (evidence the monitoring is effective)

- **Auditing (pgAudit)** captured every `GRANT`, `ALTER ROLE`, and large `SELECT`
  with the full statement text — a complete forensic trail (Test 1, 3, 4).
- **Failed-login monitoring** surfaced all 8 brute-force attempts in Grafana
  within seconds (Test 2).
- **RBAC / least privilege** correctly blocked the read-only `report_bot` from
  deleting data — `permission denied` (Test 5).
- **SCRAM-SHA-256** confirmed no plaintext passwords are stored (Test 6).
- **Alerting** — `NewSuperuserDetected` and `LargeDataExport` fired automatically.

## 3. Remaining risks

- **Detective, not preventive.** The stack *detects* a large export or escalation
  after it happens; it does not *block* it. An attacker acting fast can still
  exfiltrate before an analyst reacts.
- **No alert delivery.** Alerts fire in Prometheus/Grafana but aren't yet routed
  to email/Slack/PagerDuty, so out-of-hours incidents may be missed.
- **Log integrity.** Audit logs sit on the same host as the database; an attacker
  with host access could tamper with them. Logs are not shipped to immutable,
  off-host storage.
- **Insider threat.** A legitimate admin (`dba_mike`) is still fully trusted and
  can disable auditing.

## 4. Recommended improvements

**Preventive**
1. **Restrict `SUPERUSER` grants** and require change-control; alert *and* auto-revoke
   unexpected superusers.
2. **Column-level encryption / masking** for `ssn` (e.g. `pgcrypto`), and revoke
   direct `SELECT` on raw PII — expose masked views instead.
3. **Rate-limit / lock out** repeated failed logins (e.g. `pg_hba` + fail2ban on
   the log, or an application-layer gateway).
4. **Enforce TLS** (`sslmode=require`) between all services and rotate to strong,
   unique credentials managed by a secrets store.
5. **Row limits / export approval** — cap rows per query for reporting roles and
   require sign-off for bulk exports.

**Detective / operational**
6. **Route alerts** via Alertmanager to email/Slack.
7. **Ship logs off-host** to immutable storage (WORM / append-only) for tamper
   resistance.
8. **Baseline + anomaly detection** on rows-read per user rather than a fixed
   threshold, to catch slow-and-low exfiltration.
9. **Regular access reviews** — diff `v_role_grants` on a schedule to catch
   privilege creep.
10. **Backup & recovery** — add scheduled `pg_dump` + tested restores (the one
    control from the rubric's example list not yet implemented here).
