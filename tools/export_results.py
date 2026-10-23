"""Export the field-test results from Snowflake to results/field_test.json.

Run before teardown:  python3 tools/export_results.py <connection>
Merge a later re-run:  python3 tools/export_results.py <connection> --merge --since 2026-10-22T16:00:00-07:00
  With --merge, workloads present in this export replace the same workloads in the existing file;
  everything else in the file is kept. --since limits the billing rows to the re-run.
Needs ACCOUNTADMIN (it reads SNOWFLAKE.ACCOUNT_USAGE).
"""
import argparse
import json
import subprocess
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("conn")
ap.add_argument("--merge", action="store_true")
ap.add_argument("--since", default=None, help="ISO timestamp; default: 7 days ago")
a = ap.parse_args()
OUT = Path(__file__).resolve().parent.parent / "results" / "field_test.json"
SINCE = f"'{a.since}'::TIMESTAMP_LTZ" if a.since else "DATEADD('day', -7, CURRENT_TIMESTAMP())"
WL = "SPLIT_PART(h.QUERY_TAG,':',3)||IFF(SPLIT_PART(h.QUERY_TAG,':',4)='','',':'||SPLIT_PART(h.QUERY_TAG,':',4))"

Q = {
    "results": "SELECT RUN, WORKLOAD, METRIC, VALUE, NOTE FROM AIFW.W.RESULTS WHERE RUN IN ('pilot','full') ORDER BY RUN, WORKLOAD, METRIC",
    "cost_by_workload": f"""SELECT IFF(r.QUERY_ID IS NOT NULL, 'w02:refresh_'||LOWER(r.REFRESH_ACTION)||'_'||LOWER(r.REFRESH_TRIGGER), {WL}) AS WORKLOAD,
        COALESCE(r.RUN, SPLIT_PART(h.QUERY_TAG,':',2)) AS RUN, h.FUNCTION_NAME, h.MODEL_NAME, ROUND(SUM(h.CREDITS),6) AS AI_CREDITS, COUNT(*) AS BILLING_ROWS
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
      LEFT JOIN AIFW.W.W02_REFRESHES r ON r.QUERY_ID = h.QUERY_ID
      WHERE (h.QUERY_TAG LIKE 'aifw:%' OR r.QUERY_ID IS NOT NULL) AND h.START_TIME >= {SINCE}
      GROUP BY 1,2,3,4 ORDER BY 2,1""",
    # Who each billing row is attributed to. USER_ID 0 is the system user (QUERY_HISTORY shows SYSTEM).
    "billing_user_attribution": f"""SELECT {WL} AS WORKLOAD, IFF(h.USER_ID = 0, 'system user (USER_ID 0)', 'the user who ran the script') AS BILLED_TO,
        COUNT(*) AS BILLING_ROWS, ROUND(SUM(h.CREDITS),6) AS AI_CREDITS
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
      WHERE h.QUERY_TAG LIKE 'aifw:%' AND h.START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP()) GROUP BY 1,2 ORDER BY 1,2""",
    "w02_refreshes": "SELECT RUN, REFRESH_TRIGGER, REFRESH_ACTION, INSERTED_ROWS, DATEDIFF('ms',REFRESH_START_TIME,REFRESH_END_TIME)/1000 AS SECONDS FROM AIFW.W.W02_REFRESHES ORDER BY RUN, REFRESH_START_TIME",
    "w02_misroutes": "SELECT TRUE_CATEGORY, CATEGORY, COUNT(*) N FROM AIFW.W.W02_TRIAGE WHERE ALT_CATEGORY='' GROUP BY 1,2 ORDER BY 1,3 DESC",
    "w02b_samples": "SELECT BODY, CATEGORY_BEFORE, CATEGORY_AFTER FROM AIFW.W.W02B_TICKETS WHERE TRUE_CATEGORY='safety' AND CATEGORY_BEFORE<>'safety' LIMIT 5",
    "w02b_new_errors": "SELECT TRUE_CATEGORY, CATEGORY_AFTER, COUNT(*) N FROM AIFW.W.W02B_TICKETS WHERE CATEGORY_AFTER<>TRUE_CATEGORY GROUP BY 1,2 ORDER BY 3 DESC",
    "w02c_errors": "SELECT TRUE_CATEGORY, CATEGORY_BARE, CATEGORY_DESCRIBED, BODY FROM AIFW.W.W02C_TICKETS WHERE CATEGORY_BARE<>TRUE_CATEGORY OR CATEGORY_DESCRIBED<>TRUE_CATEGORY ORDER BY 1, ID",
    "w05b_patterns": "SELECT REGEXP_REPLACE(LINE,'[0-9]+','#') PATTERN, CLASS_BEFORE, CLASS_AFTER, COUNT(*) N FROM AIFW.W.W05B_LOGS WHERE TRUE_CLASS='incident' GROUP BY 1,2,3 ORDER BY 1,2,3",
    "w05c_errors": "SELECT TRUE_CLASS, CLASS_W05, CLASS_W05B, LINE FROM AIFW.W.W05C_LOGS WHERE CLASS_W05<>TRUE_CLASS OR CLASS_W05B<>TRUE_CLASS ORDER BY 1, ID",
    "w04_samples": "SELECT NOTE_REDACTED FROM AIFW.W.W04_NOTES WHERE HAS_PII ORDER BY ID LIMIT 6",
    "w06_answers": "SELECT PRODUCT, TRUE_KEY, ROUND(TRUE_KEY_SHARE,2) SHARE, REVIEWS, MATCHED, ANSWER FROM AIFW.W.W06_SCORED ORDER BY PRODUCT",
    "w07_query_hits": "SELECT Q, WANT, LISTAGG(HIT_FAMILY, ', ') WITHIN GROUP (ORDER BY SIM DESC) TOP5 FROM AIFW.W.W07_QUERY_HITS GROUP BY QID,Q,WANT ORDER BY QID",
    "w08_samples": "SELECT FILE, OUTCOME, TRUE_SENTIMENT, SENTIMENT, ROUND(CHAR_SIMILARITY,3) SIM, TRANSCRIPT FROM AIFW.W.W08_SCORED ORDER BY FILE LIMIT 4",
    "w09_samples": "SELECT LANG, BODY, BODY_EN FROM AIFW.W.W09_TRANSLATED QUALIFY ROW_NUMBER() OVER (PARTITION BY LANG ORDER BY ID) <= 2 ORDER BY LANG",
    "w09_order_ref_misses": "SELECT LANG, BODY, BODY_EN, ORDER_REF FROM AIFW.W.W09_TRANSLATED WHERE ORDER_REF<>'' AND NOT CONTAINS(BODY_EN, ORDER_REF)",
    "w09_paired": "SELECT IFF(CAT_FROM_EN = TRUE_CATEGORY, 'right', 'wrong') AS TRANSLATED, IFF(CAT_FROM_ORIGINAL = TRUE_CATEGORY, 'right', 'wrong') AS ORIGINAL, COUNT(*) N FROM AIFW.W.W09_CLASSIFIED GROUP BY 1,2 ORDER BY 1,2",
    "w10_samples": "SELECT c.ID, c.BODY, c.REPLY_SMALL, c.REPLY_LARGE, j.PASS_SMALL, j.PASS_LARGE FROM AIFW.W.W10_COMPARE c JOIN AIFW.W.W10_JUDGED j USING (ID) ORDER BY (j.PASS_SMALL AND j.PASS_LARGE), c.ID LIMIT 5",
    "w01_samples": "SELECT FILE, R FROM AIFW.W.W01_INVOICES ORDER BY FILE LIMIT 3",
    "w03_false_positives": "SELECT STARS, BODY FROM AIFW.W.W03_REVIEWS WHERE FLAGGED AND NOT TRUE_CONTRADICTION ORDER BY ID LIMIT 10",
    "w03_fp_by_stars": "SELECT STARS, COUNT(*) N FROM AIFW.W.W03_REVIEWS WHERE FLAGGED AND NOT TRUE_CONTRADICTION GROUP BY 1 ORDER BY 1",
}

new = {}
for k, q in Q.items():
    p = subprocess.run(["snow", "sql", "-c", a.conn, "--format", "json", "-q", "USE ROLE ACCOUNTADMIN; " + q],
                       capture_output=True, text=True)
    try:
        new[k] = json.loads(p.stdout)[1]
    except Exception:
        new[k] = None  # table not present in this run
    print(f"{k:26s}", len(new[k]) if isinstance(new[k], list) else "skipped (not in this run)")

if a.merge and OUT.exists():
    old = json.loads(OUT.read_text())
    redone = {r["WORKLOAD"] for r in (new["results"] or [])}
    redone_cost = {r["WORKLOAD"].split(":")[0] for r in (new["cost_by_workload"] or [])}
    old["results"] = [r for r in old["results"] if r["WORKLOAD"] not in redone] + (new["results"] or [])
    keep = [r for r in old.get("cost_by_workload", []) if r["WORKLOAD"].split(":")[0] not in redone_cost]
    old["cost_by_workload"] = keep + (new["cost_by_workload"] or [])
    if new["billing_user_attribution"]:  # always the full 7-day window: replace as a whole
        old["billing_user_attribution"] = new["billing_user_attribution"]
    for k, v in new.items():
        # An empty list means the table exists but this run did not fill it: keep the earlier rows.
        if k not in ("results", "cost_by_workload", "billing_user_attribution") and v:
            old[k] = v
    out = old
    print("merged; replaced workloads:", sorted(redone))
else:
    out = {k: v for k, v in new.items() if v is not None}
OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False, default=str))
print("->", OUT)
