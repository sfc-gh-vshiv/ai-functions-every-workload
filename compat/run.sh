#!/usr/bin/env bash
# Compatibility tests: does an AI Function work inside each Snowflake object type?
# Each file is small (5-8 rows) and costs a fraction of an AI Credit.
#
#   compat/run.sh <connection>
#
# Uses SYSADMIN, plus ACCOUNTADMIN for 04_task, 05_alert and 99_cleanup. Results print to the terminal.
# 06_mv.sql is expected to FAIL: materialized views reject non-deterministic functions.
# Wait about 2 minutes after 04/05 so the task and alert run once before 45/10 check them.
set -uo pipefail
CONN="${1:?usage: compat/run.sh <connection>}"
cd "$(dirname "$0")"
for f in 00_setup 01_dmf 02_masking 03a_sv_dimension 03b_sv_metric 04_task 05_alert 06_mv 07_search 08_copy 09_udf; do
  echo; echo "== $f"; snow sql -c "$CONN" -f "$f.sql" || echo "-- $f returned an error (expected only for 06_mv)"
done
echo; echo "Waiting 120 s for the task and the alert to run..."; sleep 120
for f in 45_check_task_alert 10_verify; do echo; echo "== $f"; snow sql -c "$CONN" -f "$f.sql"; done
echo; echo "Clean up with: snow sql -c $CONN -f compat/99_cleanup.sql"
