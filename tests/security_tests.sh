#!/usr/bin/env bash
# =============================================================================
# Part D — Security Tests (evidence generator)
# =============================================================================
# Runs the six required security tests against the running stack. Each test
# prints its Objective / Procedure / Expected result, executes it, and the
# resulting activity shows up in Grafana, Prometheus and the postgres logs.
#
# Usage:   ./tests/security_tests.sh          # run all tests
#          ./tests/security_tests.sh 3        # run only test 3
#
# Requires the stack to be up (make up) and data loaded (make load).
# =============================================================================
set -uo pipefail

PGCONTAINER="sm_postgres"
DB="${POSTGRES_DB:-company}"
HOST="127.0.0.1"

# psql helper: run a query as an arbitrary role via the container.
run_as() {  # run_as <user> <password> <sql>
  docker exec -e PGPASSWORD="$2" "$PGCONTAINER" \
    psql -h "$HOST" -U "$1" -d "$DB" -c "$3" 2>&1
}
# psql as the bootstrap superuser (SCRAM password required over the socket).
run_admin() {
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" "$PGCONTAINER" \
    psql -U "${POSTGRES_USER:-postgres}" -d "$DB" -c "$1" 2>&1
}

hr() { printf '=%.0s' {1..75}; echo; }
title() { hr; echo "TEST $1: $2"; hr; }

# -----------------------------------------------------------------------------
test1() {  # Auditing is active
  title 1 "Verify database auditing (pgAudit) is enabled"
  echo "Objective : Confirm pgAudit is loaded and logging."
  echo "Procedure : Check shared_preload_libraries and pgaudit.log settings."
  echo "Expected  : pgaudit present; pgaudit.log includes role,ddl,write,read."
  echo "--- Actual ---"
  run_admin "SHOW shared_preload_libraries;"
  run_admin "SHOW pgaudit.log;"
  echo "Evidence  : audit lines appear in logs -> docker exec $PGCONTAINER tail /var/log/postgresql/postgresql.log"
}

# -----------------------------------------------------------------------------
test2() {  # Failed login monitoring
  title 2 "Monitor failed logins (brute-force simulation)"
  echo "Objective : Detect authentication failures."
  echo "Procedure : Attempt 8 logins with a wrong password for 'intern_bob'."
  echo "Expected  : 8x 'password authentication failed' in logs -> Loki/Grafana."
  echo "--- Actual ---"
  for i in $(seq 1 8); do
    run_as "intern_bob" "WRONG_PASSWORD_$i" "SELECT 1;" | grep -i "fail\|authentication" | head -1
  done
  echo "Evidence  : Grafana 'Failed login events' panel; category=failed_login in Loki."
}

# -----------------------------------------------------------------------------
test3() {  # Privilege change monitoring
  title 3 "Monitor privilege changes (GRANT / role escalation)"
  echo "Objective : Detect unauthorized privilege grants."
  echo "Procedure : Grant app_admin to the low-priv intern, then make a superuser."
  echo "Expected  : ROLE audit entries; sm_role_grants_total & sm_superusers_total rise."
  echo "--- Actual ---"
  run_admin "GRANT app_admin TO intern_bob;"
  run_admin "ALTER ROLE intern_bob SUPERUSER;"
  echo "Current superusers:"
  run_admin "SELECT rolname FROM pg_roles WHERE rolsuper;"
  echo "Evidence  : Grafana 'Privilege change events' panel; NewSuperuserDetected alert fires."
  echo ">> Remember to revert:  ./tests/security_tests.sh revert"
}

# -----------------------------------------------------------------------------
test4() {  # Large data export detection
  title 4 "Detect large data export / exfiltration"
  echo "Objective : Detect bulk reads of sensitive data."
  echo "Procedure : report_bot dumps the entire customers table (PII incl. SSN)."
  echo "Expected  : Large rows_returned spike; READ audit entries; LargeDataExport alert."
  echo "--- Actual ---"
  run_as "report_bot" "report_pw" "\copy (SELECT customer_id, full_name, ssn, credit_score FROM company.customers) TO '/tmp/export.csv' CSV"
  echo "Exported row count:"
  docker exec "$PGCONTAINER" sh -c "wc -l /tmp/export.csv" 2>&1
  echo "Evidence  : Grafana 'Rows returned per user' panel; v_large_reads view."
}

# -----------------------------------------------------------------------------
test5() {  # RBAC / least-privilege enforcement
  title 5 "Verify Role-Based Access Control (least privilege)"
  echo "Objective : Confirm read-only accounts cannot modify data."
  echo "Procedure : report_bot (app_read) tries to DELETE from customers."
  echo "Expected  : 'permission denied for table customers'."
  echo "--- Actual ---"
  run_as "report_bot" "report_pw" "DELETE FROM company.customers WHERE customer_id = 1;"
  echo "Evidence  : permission-denied error in output + logs."
}

# -----------------------------------------------------------------------------
test6() {  # Encryption in transit / auth method
  title 6 "Verify authentication uses SCRAM (no plaintext passwords)"
  echo "Objective : Confirm passwords are stored/exchanged with scram-sha-256."
  echo "Procedure : Inspect pg_authid password hashes and pg_hba auth method."
  echo "Expected  : password hashes begin with 'SCRAM-SHA-256\$'."
  echo "--- Actual ---"
  run_admin "SELECT rolname, left(rolpassword, 13) AS pw_prefix FROM pg_authid WHERE rolcanlogin AND rolpassword IS NOT NULL;"
  echo "Evidence  : SCRAM-SHA-256 prefix confirms hashed credentials."
}

# -----------------------------------------------------------------------------
revert() {  # undo the privilege changes from test 3
  title R "Revert test-3 privilege changes"
  run_admin "ALTER ROLE intern_bob NOSUPERUSER;"
  run_admin "REVOKE app_admin FROM intern_bob;"
  echo "Reverted. Superusers now:"
  run_admin "SELECT rolname FROM pg_roles WHERE rolsuper;"
}

# -----------------------------------------------------------------------------
case "${1:-all}" in
  1) test1 ;; 2) test2 ;; 3) test3 ;; 4) test4 ;; 5) test5 ;; 6) test6 ;;
  revert) revert ;;
  all)
    test1; echo; test2; echo; test3; echo; test4; echo; test5; echo; test6
    echo; echo "All tests done. Open Grafana (http://localhost:3000) to view evidence."
    echo "Reminder: run './tests/security_tests.sh revert' to undo test 3." ;;
  *) echo "Usage: $0 [1-6|all|revert]"; exit 1 ;;
esac
