#!/usr/bin/env bash
# Run the ten workloads at pilot or full size against one Snowflake CLI connection.
#
#   tools/run_all.sh <connection> pilot   # 200 rows per table, 10 PDFs, 4 calls
#   tools/run_all.sh <connection> full    # 10,000 rows per table, 200 PDFs, 40 calls
#   tools/run_all.sh <connection> full w02 w05   # only some workloads
#
# Run from the repo root, after sql/00_setup.sql, sql/01_guardrails.sql and sql/02_data.sql.
# Every statement is tagged aifw:<run>:<workload>, so sql/meter.sql can report the cost per workload.
set -euo pipefail

CONN="${1:?usage: tools/run_all.sh <connection> pilot|full [workload ...]}"
RUN="${2:?usage: tools/run_all.sh <connection> pilot|full [workload ...]}"
shift 2
ONLY=("$@")

case "$RUN" in
  pilot) N=200;   N_NEW=20;  N_PDF=10;  N_CALLS=4;  K9=50;  K10=20 ;;
  full)  N=10000; N_NEW=200; N_PDF=200; N_CALLS=40; K9=500; K10=300 ;;
  *) echo "run must be pilot or full" >&2; exit 2 ;;
esac

ACCOUNT=$(snow sql -c "$CONN" --format json -q "SELECT CURRENT_ACCOUNT_NAME() AS A" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['A'])")
echo "Connection '$CONN' -> account $ACCOUNT. Run: $RUN (n=$N)."
if [[ "${AIFW_YES:-}" != "1" ]]; then
  read -r -p "This spends AI Credits in account $ACCOUNT. Type the account name to continue: " REPLY
  [[ "$REPLY" == "$ACCOUNT" ]] || { echo "Stopped."; exit 1; }
fi

run() {  # run <workload> <file> [-D var=value ...]
  local w="$1" f="$2"; shift 2
  if (( ${#ONLY[@]} )) && [[ ! " ${ONLY[*]} " == *" $w "* ]]; then return; fi
  echo; echo "== $w ($RUN) $(date +%H:%M:%S)"
  snow sql -c "$CONN" -f "sql/$f" -D "run=$RUN" "$@"
}

run w01 w01_invoices.sql              -D "n=$N_PDF"
run w02 w02_triage_dt.sql             -D "n=$N" -D "n_new=$N_NEW"
run w03 w03_review_contradictions.sql -D "n=$N"
run w04 w04_redact_once.sql           -D "n=$N"
run w05 w05_log_triage.sql            -D "n=$N"
run w06 w06_top_complaint.sql         -D "n=$N"
run w07 w07_semantic_search.sql       -D "n=$N"
run w08 w08_calls.sql                 -D "n=$N_CALLS"
run w09 w09_translate_route.sql       -D "n=$N" -D "k=$K9"
run w10 w10_reply_drafts.sql          -D "n=$N" -D "k=$K10"

echo; echo "Done. Billing rows lag behind real time. Later, run:"
echo "  snow sql -c $CONN -f sql/meter.sql -D run=$RUN"
