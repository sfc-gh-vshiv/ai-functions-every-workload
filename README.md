# AI Functions in every workload: a field test

Ten everyday data workloads, each solved with one or two Snowflake Cortex AI Functions in plain SQL,
run at up to 10,000 rows (w01: 200 PDFs, w08: 40 calls) against synthetic data with planted ground truth. Every result is scored, and every
AI Credit is metered per workload.

**Results:** [RESULTS.md](RESULTS.md). The ten workloads cost 15.01 AI Credits. Everything, including the pilot,
the follow-up tests and two re-runs after review, cost 17.54 AI Credits.

| # | Workload | AI Function | Placement |
|---|---|---|---|
| w01 | Read 200 invoice PDFs in 3 layouts | AI_EXTRACT | table |
| w02 | Route support tickets | AI_CLASSIFY | incremental dynamic table |
| w03 | Find reviews whose stars contradict the text | AI_FILTER | table |
| w04 | Redact PII in CRM notes, once | AI_REDACT | table + conditional masking policy |
| w05 | Triage log lines | AI_CLASSIFY | table |
| w06 | Name each product's top complaint | AI_AGG | GROUP BY |
| w07 | Search a catalog by meaning, with queries that share no family-specific words with it | AI_EMBED | table + VECTOR_COSINE_SIMILARITY |
| w08 | Transcribe calls and score sentiment | AI_TRANSCRIBE, AI_SENTIMENT | table |
| w09 | Translate tickets in 5 languages, then route | AI_TRANSLATE, AI_CLASSIFY | table |
| w10 | Draft replies with a small model, judge them | AI_COMPLETE, AI_FILTER | table |
| w02b, w05b | Fix the two weak spots with one prompt change each | AI_CLASSIFY | table |
| w02c, w05c | Check both fixes on held-out phrasings | AI_CLASSIFY | table |

Every function used here was generally available on 2026-10-22, except
[`PROMPT`](https://docs.snowflake.com/en/sql-reference/functions/prompt) (w03, w10), which is in public preview. Check
[the regional availability page](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-regional-availability)
for your region before you run.

**The data is synthetic and templated.** Read [RESULTS.md](RESULTS.md) for how varied each input is.
A score on templated data shows that a function handles that pattern. It does not predict the score on your data.

## Before you run: cost and safety

- **It spends real AI Credits.** The ten workloads cost 15.01 AI Credits on my account (about $30 at $2.00 per credit).
  Start with the pilot: about 0.5 AI Credits.
- **Use a sandbox account on Enterprise Edition or higher.** w04 uses a masking policy, and `compat/` uses a
  data metric function. Both need Enterprise Edition.
- **ACCOUNTADMIN steps:** `sql/00_setup.sql`, `sql/01_guardrails.sql`, `sql/meter.sql`, `tools/export_results.py`,
  `sql/99_teardown.sql`, and `compat/04_task.sql` and `compat/05_alert.sql`.
- **The quota covers only you.** `sql/01_guardrails.sql` creates a per-user AI spend quota with block enforcement.
  A new quota covers every user in the account by default. The script narrows it to the user who runs it
  (check the `GET_QUOTA_SCOPE` output). Changes take about 5-10 minutes to apply, and a block can land later
  than that. Treat it as a backstop.
- **The quota did not see dynamic table refreshes.** In this test, the w02 refreshes billed to the system user,
  so the per-user quota did not count them. See [RESULTS.md](RESULTS.md#guardrail-note).
- **Warehouse credits are extra.** Everything runs on one XS warehouse with a 60-second auto-suspend.

## Run it

You need the [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) with a
connection to your sandbox account. Run every command from the repo root.

```bash
# 1. Role, warehouse, database, stages (ACCOUNTADMIN)
snow sql -c <conn> -f sql/00_setup.sql

# 2. Spend backstop: a per-user monthly limit of (your spend this month + cap) AI Credits
snow sql -c <conn> -f sql/01_guardrails.sql -D cap=20

# 3. Load the synthetic data, PDFs and audio
snow sql -c <conn> -f sql/02_data.sql

# 4. Estimate input tokens for a full run (no AI Credits). AI_COUNT_TOKENS does not support ai_filter
#    (w03 shows NULL), and files (w01, w08) are not estimated. Output tokens are extra.
snow sql -c <conn> -f sql/preflight.sql -D run=full -D n=10000 -D k9=500 -D k10=300

# 5. Pilot, then meter it (billing rows lag a few minutes behind)
tools/run_all.sh <conn> pilot
snow sql -c <conn> -f sql/meter.sql -D run=pilot

# 6. Full run, then meter it. On my account the full run cost about 30 times the pilot.
tools/run_all.sh <conn> full
snow sql -c <conn> -f sql/meter.sql -D run=full

# 7. Optional follow-ups and held-out checks (about 2 AI Credits)
snow sql -c <conn> -f sql/w02b_label_descriptions.sql -D run=full
snow sql -c <conn> -f sql/w05b_event_not_level.sql -D run=full
snow sql -c <conn> -f sql/w02c_heldout_tickets.sql -D run=full
snow sql -c <conn> -f sql/w05c_heldout_logs.sql -D run=full

# 8. Export results, then remove everything (database, warehouse, roles, quota)
python3 tools/export_results.py <conn> && python3 tools/results_md.py
snow sql -c <conn> -f sql/99_teardown.sql
```

`tools/run_all.sh <conn> full w02 w05` runs only the workloads you name.

## The data

Everything is synthetic and seeded, so each run produces the same rows. Names, emails (`example.com`),
phone numbers (`555-01xx`), addresses and IP addresses (RFC 5737 ranges) are fictional.

- `tools/make_data.py`: tickets, reviews, CRM notes, logs, products and foreign-language tickets, with
  planted truth columns (category, contradiction, PII values, incident class, product family).
- `tools/heldout_phrases.py` and `tools/make_heldout.py`: held-out tickets, log lines and shopper queries.
  They were written separately from the templates and from the prompts they test.
- `tools/make_invoices.py`: 200 one-page invoice PDFs in three layouts (needs `reportlab`).
- `tools/make_calls.py`: 40 two-voice support calls from 4 scripts (macOS `say` and `ffmpeg`).

The generated files are in `data/`, so you need the scripts only to change the data.

## Also in this repo

`compat/` has small tests that put an AI Function inside other Snowflake objects: a data metric
function, a masking policy, semantic view dimensions and metrics, a task over a stream, an alert
condition, a materialized view (fails: materialized views reject non-deterministic functions), a
Cortex Search service source query, a COPY transformation and a secure UDF. Run them with
`compat/run.sh <conn>`. The data metric function runs AI_FILTER every hour and the search service
refreshes daily, so run `compat/99_cleanup.sql` when you finish. These tests use a few rows each.
They show that a function runs in that object, not how well it performs there.

## License

Apache 2.0. See [LICENSE](LICENSE).
