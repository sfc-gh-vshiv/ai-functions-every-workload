-- w02c Held-out check for w02 and w02b: 240 tickets (40 per category) written separately from the
-- templates and from both prompts. Each ticket is scored with the bare labels (w02) and with the
-- label descriptions + "safety first" task description (w02b). No rows here shaped either prompt.
-- Vars: run
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w02c';

CREATE OR REPLACE TABLE W02C_TICKETS AS
SELECT ID, TRUE_CATEGORY, BODY,
       REPLACE(AI_CLASSIFY(BODY, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])
               :labels[0]::STRING, ' ', '_') AS CATEGORY_BARE,
       REPLACE(AI_CLASSIFY(BODY, [
         {'label': 'billing',        'description': 'charges, invoices, fees, taxes, refunds not received, subscription price'},
         {'label': 'shipping',       'description': 'delivery, tracking, late, lost or misdelivered packages'},
         {'label': 'product defect', 'description': 'the product is broken or does not work, with no danger to people'},
         {'label': 'account access', 'description': 'login, password reset, two-factor codes, locked or taken-over accounts'},
         {'label': 'returns',        'description': 'starting a return, return labels, exchanges, the return window'},
         {'label': 'safety',         'description': 'any risk of harm: heat, burning smell, smoke, sparks, electric shock, cuts, parts flying off. Use this even if the product is also broken.'}],
         {'task_description': 'Route customer support tickets to the right queue. Safety takes priority over every other label.'})
       :labels[0]::STRING, ' ', '_') AS CATEGORY_DESCRIBED
FROM HELDOUT_TICKETS;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02c';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w02c', 'rows', COUNT(*), NULL FROM W02C_TICKETS
UNION ALL SELECT '<% run %>', 'w02c', 'accuracy_bare', AVG(IFF(CATEGORY_BARE = TRUE_CATEGORY, 1, 0)), NULL FROM W02C_TICKETS
UNION ALL SELECT '<% run %>', 'w02c', 'accuracy_described', AVG(IFF(CATEGORY_DESCRIBED = TRUE_CATEGORY, 1, 0)), NULL FROM W02C_TICKETS
UNION ALL SELECT '<% run %>', 'w02c', 'safety_recall_bare', AVG(IFF(CATEGORY_BARE = 'safety', 1, 0)), NULL FROM W02C_TICKETS WHERE TRUE_CATEGORY = 'safety'
UNION ALL SELECT '<% run %>', 'w02c', 'safety_recall_described', AVG(IFF(CATEGORY_DESCRIBED = 'safety', 1, 0)), NULL FROM W02C_TICKETS WHERE TRUE_CATEGORY = 'safety'
UNION ALL SELECT '<% run %>', 'w02c', 'non_safety_sent_to_safety_bare', COUNT_IF(CATEGORY_BARE = 'safety'), 'of 200 non-safety tickets'
          FROM W02C_TICKETS WHERE TRUE_CATEGORY <> 'safety'
UNION ALL SELECT '<% run %>', 'w02c', 'non_safety_sent_to_safety_described', COUNT_IF(CATEGORY_DESCRIBED = 'safety'), 'of 200 non-safety tickets'
          FROM W02C_TICKETS WHERE TRUE_CATEGORY <> 'safety'
UNION ALL SELECT '<% run %>', 'w02c', 'accuracy_bare_' || TRUE_CATEGORY, AVG(IFF(CATEGORY_BARE = TRUE_CATEGORY, 1, 0)), NULL
          FROM W02C_TICKETS GROUP BY TRUE_CATEGORY
UNION ALL SELECT '<% run %>', 'w02c', 'accuracy_described_' || TRUE_CATEGORY, AVG(IFF(CATEGORY_DESCRIBED = TRUE_CATEGORY, 1, 0)), NULL
          FROM W02C_TICKETS GROUP BY TRUE_CATEGORY;

SELECT TRUE_CATEGORY, CATEGORY_BARE, CATEGORY_DESCRIBED, BODY FROM W02C_TICKETS
WHERE CATEGORY_BARE <> TRUE_CATEGORY OR CATEGORY_DESCRIBED <> TRUE_CATEGORY ORDER BY TRUE_CATEGORY, ID;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02c' ORDER BY METRIC;
