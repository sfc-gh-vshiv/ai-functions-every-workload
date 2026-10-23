-- preflight.sql: count input tokens for a full run BEFORE you spend AI Credits.
-- AI_COUNT_TOKENS bills warehouse compute only, not AI Credits. It counts input tokens only;
-- output tokens (replies, translations, redacted text) add to the bill.
-- Vars: run (label for this estimate), n, k10 (w10 comparison rows), k9 (w09 classified rows)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:preflight';

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'preflight';

INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'preflight', 'w02_ai_classify_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_classify', BODY, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])), NULL
          FROM (SELECT BODY FROM TICKETS WHERE ID <= <% n %> UNION ALL SELECT BODY FROM TICKETS_NEW)
UNION ALL SELECT '<% run %>', 'preflight', 'w03_ai_filter_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_filter', 'A customer gave ' || STARS || ' out of 5 stars and wrote: "' || BODY
                                     || '". Does the star rating contradict the written review?')), NULL
          FROM REVIEWS WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w04_ai_redact_input_tokens', SUM(AI_COUNT_TOKENS('ai_redact', NOTE)), NULL
          FROM NOTES WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w05_ai_classify_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_classify', LINE, [{'label': 'incident'}, {'label': 'error'}, {'label': 'routine'}])),
                 'labels only; descriptions add tokens'
          FROM LOGS WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w07_ai_embed_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_embed', 'snowflake-arctic-embed-m-v1.5', DESCRIPTION)), NULL
          FROM PRODUCTS WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w09_ai_translate_input_tokens', SUM(AI_COUNT_TOKENS('ai_translate', BODY, LANG, 'en')), NULL
          FROM FOREIGN_TICKETS WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w09_ai_classify_original_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_classify', BODY, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])),
                 'x2 for the translated copy (approx.)'
          FROM FOREIGN_TICKETS WHERE ID <= <% k9 %>
UNION ALL SELECT '<% run %>', 'preflight', 'w10_ai_complete_8b_input_tokens',
                 SUM(AI_COUNT_TOKENS('ai_complete', 'llama3.1-8b', 'You are a support agent for an online store. Reply to the customer ticket below in two or three '
                   || 'polite sentences. Acknowledge the problem and say the next step. Do not promise a refund amount, a delivery date, '
                   || 'or anything you cannot check. Write only the reply. Ticket: ' || BODY)), 'output capped at 120 tokens per row'
          FROM TICKETS WHERE ID <= <% n %>
UNION ALL SELECT '<% run %>', 'preflight', 'w06_review_tokens_for_ai_agg',
                 SUM(AI_COUNT_TOKENS('ai_complete', 'llama3.1-8b', BODY)), 'proxy: review text only'
          FROM REVIEWS WHERE ID <= <% n %>;

SELECT METRIC, VALUE, NOTE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'preflight' ORDER BY METRIC;
