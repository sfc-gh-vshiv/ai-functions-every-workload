# Results

Measured on one Snowflake account (AWS US West 2, cross-region routing ANY_REGION), October 22, 2026. USD uses $2.00 per AI Credit. Your rate depends on your contract and region. AI Credits come from `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY`. Warehouse credits (one XS warehouse) are billed separately and are not included.

**Time** is wall-clock time for each workload script on one X-Small warehouse, from the first query start to the last query end, from `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`. It includes the scoring queries, which are fast. The workloads ran one after the other. Queue time was 0.3 s or less per workload.

**Read the quality numbers with the data in mind.** All data is synthetic and built from small phrase banks (`tools/phrases.py`), so most inputs repeat a few templates. The "Synthetic input" column says how varied each input is. A high score on templated data shows that the function handles that pattern, not that it will score the same on your data. The held-out tests below use new phrasings that no template or prompt was built from. Raw numbers: [`results/field_test.json`](results/field_test.json).

## Ten workloads

| # | Workload | Function | Volume | Synthetic input | Quality (vs planted truth) | AI Credits | Unit cost | Time |
|---|---|---|---|---|---|---:|---|---:|
| w01 | Accounts payable | AI_EXTRACT | 200 invoice PDFs | 3 layouts, 8 vendors, born-digital PDFs | all 4 fields right on 100.0% of PDFs | 1.25 | $0.0125 per PDF | 37 s |
| w02 | Support triage | AI_CLASSIFY in a dynamic table | 10,000 + 200 tickets | 6 templates per category | accuracy 90.5%; safety recall 65.4% | 3.50 | $0.69 per 1,000 | 73 s |
| w03 | Review data quality | AI_FILTER | 10,000 reviews | 194 distinct texts; contradictions are full flips | recall 100.0%, precision 60.9% | 1.62 | $0.32 per 1,000 | 2.0 min |
| w04 | CRM notes PII | AI_REDACT + masking policy | 10,000 notes | 5 PII templates, US formats | 0 of 8,769 planted values found verbatim | 2.41 | $0.48 per 1,000 | 6.7 min |
| w05 | Log triage | AI_CLASSIFY | 10,000 log lines | 6 incident templates | incident recall 80.1%, precision 100.0% | 4.56 | $0.91 per 1,000 | 36 s |
| w06 | Top complaint | AI_AGG | 10,000 reviews, 50 products | top complaint is ~65% of reviews | right complaint for 100.0% of products | 0.24 | $0.0095 per product | 13 s |
| w07 | Catalog search | AI_EMBED + vector similarity | 10,000 products, 60 queries | no family-specific word shared; 9 of 60 share only generic words | precision@5 0.67; keyword search on the same queries 0.00 | 0.0072 | $0.0014 per 1,000 products | 11 s |
| w08 | Call center | AI_TRANSCRIBE + AI_SENTIMENT | 40 calls, 10.3 min | 4 scripts, synthetic (text-to-speech) voices | transcript similarity 0.994; sentiment matched 50.0% | 0.0419 | $0.49 per audio hour, both functions | 9 s |
| w09 | Global support | AI_TRANSLATE + AI_CLASSIFY | 10,000 tickets, 5 languages | 6 templates per language | order numbers kept 99.8%; routing 92.2% (500 rows) | 0.96 | $0.19 per 1,000, incl. 500 routed twice | 38 s |
| w10 | Reply drafts | AI_COMPLETE + AI_FILTER | 10,000 drafts (llama3.1-8b) | 36 ticket templates | rubric pass, 300 rows: 8b 99.0%, 70b 100.0% | 0.43 | $0.0430 per 1,000 8b drafts | 1.6 min |
| | **Total** | | | | | **15.01** | **$30.03** | **13.9 min** |

w07 and w08 are the versions re-run after review: w07 with held-out queries, w08 with a corrected similarity formula.

## Pay once: the dynamic table refreshes (w02)

One insert-only test: create the table, insert 200 tickets, refresh, then refresh again with no new data.

| Refresh | Trigger | Rows classified | AI Credits | Time |
|---|---|---:|---:|---:|
| INCREMENTAL | CREATION | 10,000 | 3.4316 | 51.3 s |
| INCREMENTAL | MANUAL | 200 | 0.0686 | 14.7 s |
| NO_DATA | MANUAL | 0 | 0.0000 | 0.6 s |

The refresh with no new data had no billing row (the same in the pilot). This test did not cover updates to rows, a reinitialization, or `CREATE OR REPLACE`, which classify the rows again.

## The two weak spots: one prompt change each, then a held-out check

I wrote each change after I saw the misses. So the change was first scored on the rows it was built from (b), then on held-out rows that no prompt was built from (c).

| Test | Rows | Metric | Bare prompt | Changed prompt |
|---|---|---|---:|---:|
| w02b, same templates | 549 safety + 1,000 others | safety recall | 65.4% | 100.0% |
| **w02c, held-out** | 40 safety + 200 others | safety recall | 65.0% | **97.5%** |
| | | other tickets sent to safety | 0 of 200 | 0 of 200 |
| | | accuracy, all 240 | 91.7% | 99.2% |
| w05b, same templates | 291 incidents + 1,000 others | incident recall | 80.1% | 100.0% |
| **w05c, held-out** | 60 incidents + 120 others | incident recall | 35.0% | **58.3%** |
| | | INFO-level incidents (30) | 10.0% | 50.0% |
| | | other lines called incidents | 0 of 120 | 0 of 120 |

- **Label descriptions generalized.** On held-out tickets, safety recall rose from 65.0% to 97.5%, and no other ticket went to safety. With bare labels, a swollen battery or a melted casing went to `product defect`.
- On the w02b rows, product defect accuracy fell from 100.0% to 92.5%: some defect tickets went to safety. The w02b precision is from a sample with 549 safety tickets, so it is higher than it would be in a real queue.
- **"Judge the event, not the log level" helped, but did not fix it.** The 100% on w05b came from the six templates the change was written against. On held-out lines, incident recall was 58.3%. Missed examples: a token created with no expiry, a database dump, a dormant account reactivated with write access. Do not use a classifier as the only security control.

## What went wrong, in detail

- **w03 false positives.** 282 reviews were flagged with no planted contradiction: 111 one-star, 32 two-star and 139 three-star. Example: 2 stars and "Returning it, it has a strong chemical smell." The three-star rows are mixed reviews, where "contradiction" is a judgment call. Use AI_FILTER as a cheap first pass and review what it flags.
- **w08 sentiment.** AI_SENTIMENT called the resolved and refund calls `mixed`. The planted label was `positive`. Each of those calls starts with a complaint and ends happy, so `mixed` is a fair reading. Only the two negative scripts matched.
- **w09 order numbers.** 9 of 5,028 order numbers changed in translation (1 es, 1 fr, 6 ja, 1 pt). All of them were return requests. In Spanish, French and Portuguese, the order number became a date (`A-957972` became "9/5/72"). In Japanese, the `A-` prefix was dropped and "Echo smart speaker" became "echo dot". Keep IDs out of the text you translate, or join them back from the source row.
- **w10 judge.** AI_FILTER passed 297 of 300 8b replies and 300 of 300 70b replies against a three-point rubric (polite, addresses the problem, no refund amount or date). I did not check the judge against human labels. Both models sometimes claim actions the agent can't take, such as "I've checked on the status of your order", and the rubric does not test for that. Read a sample before you trust a judge.
- **w06 is easy by construction.** Each product's top complaint is about 65% of its reviews, and AI_AGG returned the planted phrase almost word for word.

## Cost of the whole field test

| Part | AI Credits | USD |
|---|---:|---:|
| Pilot (200 rows per table) | 0.50 | $1.00 |
| Ten workloads (table above) | 15.01 | $30.03 |
| Follow-ups (w02b, w05b, w02c, w05c) | 1.97 | $3.95 |
| First w07 and w08 runs, replaced after review | 0.05 | $0.11 |
| **Total spent** | **17.54** | **$35.08** |

Rows are rounded, so they can differ from the total by 0.01.

## Guardrail note

The usage view billed 3.58 AI Credits (all w02 dynamic table refreshes) to the system user, USER_ID 0, which QUERY_HISTORY shows as `SYSTEM`. That includes refreshes I started with ALTER DYNAMIC TABLE ... REFRESH. Every other workload billed to the user who ran it (see `billing_user_attribution` in the JSON). The per-user quota counts spend attributed to a user, and its spending report for the day left out the refresh spend. I observed this in this test. The docs do not state it. If your AI Functions run in dynamic tables, a per-user quota alone does not cap that spend. Track it in CORTEX_AI_FUNCTIONS_USAGE_HISTORY by the refresh QUERY_ID from DYNAMIC_TABLE_REFRESH_HISTORY, as sql/meter.sql does.
