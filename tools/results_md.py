"""Write RESULTS.md from results/field_test.json (made by tools/export_results.py).

Usage: python3 tools/results_md.py
Sections whose data is missing (for example, follow-ups you did not run) are left out.
"""
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = json.loads((ROOT / "results" / "field_test.json").read_text())
USD_PER_CREDIT = 2.00  # global cross-region routing; check your own contract rate

M = defaultdict(dict)
for r in D.get("results", []):
    if r["RUN"] == "full":
        M[r["WORKLOAD"]][r["METRIC"]] = float(r["VALUE"]) if r["VALUE"] is not None else None

COST = defaultdict(float)
for r in D.get("cost_by_workload", []):
    if r["RUN"] == "full":
        COST[r["WORKLOAD"]] += float(r["AI_CREDITS"])
PILOT = sum(float(r["AI_CREDITS"]) for r in D.get("cost_by_workload", []) if r["RUN"] == "pilot")
SPENT = sum(float(r["AI_CREDITS"]) for r in D.get("billing_user_attribution", []))  # every billed row, incl. replaced runs


def cr(*prefixes):
    return sum(v for k, v in COST.items() if any(k == p or k.startswith(p + ":") for p in prefixes))


def has(w, *metrics):
    return w in M and all(m in M[w] and M[w][m] is not None for m in metrics)


def pct(x):
    return f"{100 * x:.1f}%"


def money(c):
    v = c * USD_PER_CREDIT
    return f"${v:,.2f}" if v >= 0.10 else f"${v:.4f}"


def credits(c):
    return f"{c:.2f}" if c >= 0.1 else f"{c:.4f}"


w = M
# (id, workload, function, volume, how varied the synthetic input is, quality, credits, unit cost)
rows = []
if has("w01", "all_four_correct"):
    rows.append(("w01", "Accounts payable", "AI_EXTRACT", "200 invoice PDFs",
                 "3 layouts, 8 vendors, born-digital PDFs",
                 f"all 4 fields right on {pct(w['w01']['all_four_correct'])} of PDFs", cr("w01"), f"{money(cr('w01') / 200)} per PDF"))
if has("w02", "accuracy", "safety_recall"):
    rows.append(("w02", "Support triage", "AI_CLASSIFY in a dynamic table", "10,000 + 200 tickets",
                 "6 templates per category",
                 f"accuracy {pct(w['w02']['accuracy'])}; safety recall {pct(w['w02']['safety_recall'])}", cr("w02"), f"{money(cr('w02') / 10.2)} per 1,000"))
if has("w03", "recall", "precision"):
    rows.append(("w03", "Review data quality", "AI_FILTER", "10,000 reviews",
                 "194 distinct texts; contradictions are full flips",
                 f"recall {pct(w['w03']['recall'])}, precision {pct(w['w03']['precision'])}", cr("w03"), f"{money(cr('w03') / 10)} per 1,000"))
if has("w04", "planted_values", "value_leak_rate"):
    rows.append(("w04", "CRM notes PII", "AI_REDACT + masking policy", "10,000 notes",
                 "5 PII templates, US formats",
                 f"0 of {int(w['w04']['planted_values']):,} planted values found verbatim" if w['w04']['value_leak_rate'] == 0
                 else f"verbatim leak rate {pct(w['w04']['value_leak_rate'])}", cr("w04"), f"{money(cr('w04') / 10)} per 1,000"))
if has("w05", "incident_recall", "incident_precision"):
    rows.append(("w05", "Log triage", "AI_CLASSIFY", "10,000 log lines",
                 "6 incident templates",
                 f"incident recall {pct(w['w05']['incident_recall'])}, precision {pct(w['w05']['incident_precision'])}", cr("w05"), f"{money(cr('w05') / 10)} per 1,000"))
if has("w06", "top_complaint_accuracy"):
    rows.append(("w06", "Top complaint", "AI_AGG", "10,000 reviews, 50 products",
                 "top complaint is ~65% of reviews",
                 f"right complaint for {pct(w['w06']['top_complaint_accuracy'])} of products", cr("w06"), f"{money(cr('w06') / 50)} per product"))
if has("w07", "precision_at_5", "keyword_precision_at_5"):
    rows.append(("w07", "Catalog search", "AI_EMBED + vector similarity", "10,000 products, 60 queries",
                 "no family-specific word shared; 9 of 60 share only generic words",
                 f"precision@5 {w['w07']['precision_at_5']:.2f}; keyword search on the same queries {w['w07']['keyword_precision_at_5']:.2f}",
                 cr("w07"), f"{money(cr('w07') / 10)} per 1,000 products"))
if has("w08", "avg_char_similarity", "sentiment_accuracy"):
    rows.append(("w08", "Call center", "AI_TRANSCRIBE + AI_SENTIMENT", f"40 calls, {w['w08']['audio_seconds'] / 60:.1f} min",
                 "4 scripts, synthetic (text-to-speech) voices",
                 f"transcript similarity {w['w08']['avg_char_similarity']:.3f}; sentiment matched {pct(w['w08']['sentiment_accuracy'])}",
                 cr("w08"), f"{money(cr('w08') / (w['w08']['audio_seconds'] / 3600))} per audio hour, both functions"))
if has("w09", "order_ref_preserved", "accuracy_translated"):
    rows.append(("w09", "Global support", "AI_TRANSLATE + AI_CLASSIFY", "10,000 tickets, 5 languages",
                 "6 templates per language",
                 f"order numbers kept {pct(w['w09']['order_ref_preserved'])}; routing {pct(w['w09']['accuracy_translated'])} (500 rows)",
                 cr("w09"), f"{money(cr('w09') / 10)} per 1,000, incl. 500 routed twice"))
if has("w10", "pass_rate_small"):
    rows.append(("w10", "Reply drafts", "AI_COMPLETE + AI_FILTER", "10,000 drafts (llama3.1-8b)",
                 "36 ticket templates",
                 f"rubric pass, 300 rows: 8b {pct(w['w10']['pass_rate_small'])}, 70b {pct(w['w10']['pass_rate_large'])}",
                 cr("w10"), f"{money(COST.get('w10:small', 0) / 10)} per 1,000 8b drafts"))

main_total = sum(r[6] for r in rows)
L = ["# Results\n"]
L.append("Measured on one Snowflake account (AWS US West 2, cross-region routing ANY_REGION), October 22, 2026. "
         f"USD uses ${USD_PER_CREDIT:.2f} per AI Credit. Your rate depends on your contract and region. "
         "AI Credits come from `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY`. "
         "Warehouse credits (one XS warehouse) are billed separately and are not included.\n")
L.append("**Read the quality numbers with the data in mind.** All data is synthetic and built from small phrase banks "
         "(`tools/phrases.py`), so most inputs repeat a few templates. The \"Synthetic input\" column says how varied each input is. "
         "A high score on templated data shows that the function handles that pattern, not that it will score the same on your data. "
         + ("The held-out tests below use new phrasings that no template or prompt was built from. " if has("w02c", "safety_recall_bare") else "")
         + "Raw numbers: [`results/field_test.json`](results/field_test.json).\n")
L.append("## Ten workloads\n")
L.append("| # | Workload | Function | Volume | Synthetic input | Quality (vs planted truth) | AI Credits | Unit cost |")
L.append("|---|---|---|---|---|---|---:|---|")
for r in rows:
    L.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | {r[5]} | {credits(r[6])} | {r[7]} |")
L.append(f"| | **Total** | | | | | **{main_total:.2f}** | **{money(main_total)}** |\n")
L.append("w07 and w08 are the versions re-run after review: w07 with held-out queries, w08 with a corrected similarity formula.\n")

if D.get("w02_refreshes"):
    L.append("## Pay once: the dynamic table refreshes (w02)\n")
    L.append("One insert-only test: create the table, insert 200 tickets, refresh, then refresh again with no new data.\n")
    L.append("| Refresh | Trigger | Rows classified | AI Credits |")
    L.append("|---|---|---:|---:|")
    for r in D["w02_refreshes"]:
        if r["RUN"] != "full":
            continue
        key = f"w02:refresh_{r['REFRESH_ACTION'].lower()}_{r['REFRESH_TRIGGER'].lower()}"
        L.append(f"| {r['REFRESH_ACTION']} | {r['REFRESH_TRIGGER']} | {int(r['INSERTED_ROWS']):,} | {COST.get(key, 0.0):.4f} |")
    L.append("\nThe refresh with no new data had no billing row (the same in the pilot). This test did not cover updates to rows, "
             "a reinitialization, or `CREATE OR REPLACE`, which classify the rows again.\n")

if has("w02b", "safety_recall_before") or has("w05b", "incident_recall_before") or has("w02c", "safety_recall_bare") or has("w05c", "incident_recall_w05"):
    L.append("## The two weak spots: one prompt change each, then a held-out check\n")
    L.append("I wrote each change after I saw the misses. So the change was first scored on the rows it was built from (b), "
             "then on held-out rows that no prompt was built from (c).\n")
    L.append("| Test | Rows | Metric | Bare prompt | Changed prompt |")
    L.append("|---|---|---|---:|---:|")
    if has("w02b", "safety_recall_before"):
        b = M["w02b"]
        L.append(f"| w02b, same templates | 549 safety + 1,000 others | safety recall | {pct(b['safety_recall_before'])} | {pct(b['safety_recall_after'])} |")
    if has("w02c", "safety_recall_bare"):
        c = M["w02c"]
        L.append(f"| **w02c, held-out** | 40 safety + 200 others | safety recall | {pct(c['safety_recall_bare'])} | **{pct(c['safety_recall_described'])}** |")
        L.append(f"| | | other tickets sent to safety | {int(c['non_safety_sent_to_safety_bare'])} of 200 | {int(c['non_safety_sent_to_safety_described'])} of 200 |")
        L.append(f"| | | accuracy, all 240 | {pct(c['accuracy_bare'])} | {pct(c['accuracy_described'])} |")
    if has("w05b", "incident_recall_before"):
        b = M["w05b"]
        L.append(f"| w05b, same templates | 291 incidents + 1,000 others | incident recall | {pct(b['incident_recall_before'])} | {pct(b['incident_recall_after'])} |")
    if has("w05c", "incident_recall_w05"):
        c = M["w05c"]
        L.append(f"| **w05c, held-out** | 60 incidents + 120 others | incident recall | {pct(c['incident_recall_w05'])} | **{pct(c['incident_recall_w05b'])}** |")
        L.append(f"| | | INFO-level incidents (30) | {pct(c['incident_recall_info_w05'])} | {pct(c['incident_recall_info_w05b'])} |")
        L.append(f"| | | other lines called incidents | {int(c['false_incidents_w05'])} of 120 | {int(c['false_incidents_w05b'])} of 120 |")
    L.append("")
    if has("w02c", "safety_recall_described"):
        L.append("- **Label descriptions generalized.** On held-out tickets, safety recall rose from "
                 f"{pct(M['w02c']['safety_recall_bare'])} to {pct(M['w02c']['safety_recall_described'])}, and no other ticket went to safety. "
                 "With bare labels, a swollen battery or a melted casing went to `product defect`.")
    if has("w02b", "accuracy_after_product_defect"):
        L.append(f"- On the w02b rows, product defect accuracy fell from {pct(M['w02b']['accuracy_before_product_defect'])} to "
                 f"{pct(M['w02b']['accuracy_after_product_defect'])}: some defect tickets went to safety. "
                 "The w02b precision is from a sample with 549 safety tickets, so it is higher than it would be in a real queue.")
    if has("w05c", "incident_recall_w05b"):
        L.append("- **\"Judge the event, not the log level\" helped, but did not fix it.** The 100% on w05b came from the six templates "
                 f"the change was written against. On held-out lines, incident recall was {pct(M['w05c']['incident_recall_w05b'])}. "
                 "Missed examples: a token created with no expiry, a database dump, a dormant account reactivated with write access. "
                 "Do not use a classifier as the only security control.")
    L.append("")

L.append("## What went wrong, in detail\n")
if D.get("w03_fp_by_stars") and has("w03", "flagged", "planted_contradictions"):
    fp = {str(r["STARS"]): int(r["N"]) for r in D["w03_fp_by_stars"]}
    L.append(f"- **w03 false positives.** {int(w['w03']['flagged']) - int(w['w03']['planted_contradictions'])} reviews were flagged with no planted contradiction: "
             f"{fp.get('1', 0)} one-star, {fp.get('2', 0)} two-star and {fp.get('3', 0)} three-star. Example: 2 stars and \"Returning it, it has a strong chemical smell.\" "
             "The three-star rows are mixed reviews, where \"contradiction\" is a judgment call. "
             "Use AI_FILTER as a cheap first pass and review what it flags.")
if has("w08", "sentiment_accuracy"):
    L.append("- **w08 sentiment.** AI_SENTIMENT called the resolved and refund calls `mixed`. The planted label was `positive`. "
             "Each of those calls starts with a complaint and ends happy, so `mixed` is a fair reading. Only the two negative scripts matched.")
if D.get("w09_order_ref_misses") and has("w09", "order_ref_preserved"):
    miss_by_lang = defaultdict(int)
    for r in D["w09_order_ref_misses"]:
        miss_by_lang[r["LANG"]] += 1
    n_miss = len(D["w09_order_ref_misses"])
    L.append(f"- **w09 order numbers.** {n_miss} of {round(n_miss / (1 - w['w09']['order_ref_preserved'])):,} order numbers changed in translation "
             f"({', '.join(f'{n} {k}' for k, n in sorted(miss_by_lang.items()))}). "
             "All of them were return requests. In Spanish, French and Portuguese, the order number became a date "
             "(`A-957972` became \"9/5/72\"). In Japanese, the `A-` prefix was dropped and \"Echo smart speaker\" became \"echo dot\". "
             "Keep IDs out of the text you translate, or join them back from the source row.")
if has("w10", "large_only_pass"):
    L.append(f"- **w10 judge.** AI_FILTER passed 297 of 300 8b replies and 300 of 300 70b replies against a three-point rubric "
             "(polite, addresses the problem, no refund amount or date). I did not check the judge against human labels. "
             "Both models sometimes claim actions the agent can't take, such as \"I've checked on the status of your order\", "
             "and the rubric does not test for that. Read a sample before you trust a judge.")
if has("w06", "top_complaint_accuracy"):
    L.append("- **w06 is easy by construction.** Each product's top complaint is about 65% of its reviews, and AI_AGG "
             "returned the planted phrase almost word for word.")
L.append("")

L.append("## Cost of the whole field test\n")
L.append("| Part | AI Credits | USD |")
L.append("|---|---:|---:|")
follow = cr("w02b") + cr("w05b") + cr("w02c") + cr("w05c")
replaced = SPENT - PILOT - main_total - follow if SPENT else 0.0
L.append(f"| Pilot (200 rows per table) | {PILOT:.2f} | {money(PILOT)} |")
L.append(f"| Ten workloads (table above) | {main_total:.2f} | {money(main_total)} |")
if follow:
    L.append(f"| Follow-ups (w02b, w05b, w02c, w05c) | {follow:.2f} | {money(follow)} |")
if replaced > 0.005:
    L.append(f"| First w07 and w08 runs, replaced after review | {replaced:.2f} | {money(replaced)} |")
total = SPENT if SPENT else PILOT + main_total + follow
L.append(f"| **Total spent** | **{total:.2f}** | **{money(total)}** |\n")
L.append("Rows are rounded, so they can differ from the total by 0.01.\n")

if D.get("billing_user_attribution"):
    sys_cr = sum(float(r["AI_CREDITS"]) for r in D["billing_user_attribution"] if r["BILLED_TO"].startswith("system"))
    L.append("## Guardrail note\n")
    L.append(f"The usage view billed {sys_cr:.2f} AI Credits (all w02 dynamic table refreshes) to the system user, USER_ID 0, "
             "which QUERY_HISTORY shows as `SYSTEM`. That includes refreshes I started with ALTER DYNAMIC TABLE ... REFRESH. "
             "Every other workload billed to the user who ran it (see `billing_user_attribution` in the JSON). "
             "The per-user quota counts spend attributed to a user, and its spending report for the day left out the refresh spend. "
             "I observed this in this test. The docs do not state it. If your AI Functions run in dynamic tables, a per-user quota "
             "alone does not cap that spend. Track it in CORTEX_AI_FUNCTIONS_USAGE_HISTORY by the refresh QUERY_ID from "
             "DYNAMIC_TABLE_REFRESH_HISTORY, as sql/meter.sql does.\n")
(ROOT / "RESULTS.md").write_text("\n".join(L))
print("\n".join(L))
