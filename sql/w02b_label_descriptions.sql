-- w02b Follow-up to w02: with bare labels, a third of safety tickets went to 'product defect'.
-- Do label descriptions and a "safety first" task description fix that?
-- Rows: every single-topic safety ticket + 200 single-topic tickets from each other category.
-- Same rows are scored with the original w02 labels for a side-by-side.
-- Vars: run
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w02b';

CREATE OR REPLACE TABLE W02B_TICKETS AS
WITH rows_ AS (
  SELECT * FROM W02_TRIAGE WHERE ALT_CATEGORY = '' AND TRUE_CATEGORY = 'safety'
  UNION ALL
  SELECT * FROM W02_TRIAGE WHERE ALT_CATEGORY = '' AND TRUE_CATEGORY <> 'safety'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY TRUE_CATEGORY ORDER BY HASH(ID)) <= 200)
SELECT ID, BODY, TRUE_CATEGORY, CATEGORY AS CATEGORY_BEFORE,
       REPLACE(AI_CLASSIFY(BODY, [
         {'label': 'billing',        'description': 'charges, invoices, fees, taxes, refunds not received, subscription price'},
         {'label': 'shipping',       'description': 'delivery, tracking, late, lost or misdelivered packages'},
         {'label': 'product defect', 'description': 'the product is broken or does not work, with no danger to people'},
         {'label': 'account access', 'description': 'login, password reset, two-factor codes, locked or taken-over accounts'},
         {'label': 'returns',        'description': 'starting a return, return labels, exchanges, the return window'},
         {'label': 'safety',         'description': 'any risk of harm: heat, burning smell, smoke, sparks, electric shock, cuts, parts flying off. Use this even if the product is also broken.'}],
         {'task_description': 'Route customer support tickets to the right queue. Safety takes priority over every other label.'})
       :labels[0]::STRING, ' ', '_') AS CATEGORY_AFTER
FROM rows_;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02b';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w02b', 'rows', COUNT(*), NULL FROM W02B_TICKETS
UNION ALL SELECT '<% run %>', 'w02b', 'safety_recall_before', AVG(IFF(CATEGORY_BEFORE = 'safety', 1, 0)), NULL FROM W02B_TICKETS WHERE TRUE_CATEGORY = 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'safety_recall_after',  AVG(IFF(CATEGORY_AFTER  = 'safety', 1, 0)), NULL FROM W02B_TICKETS WHERE TRUE_CATEGORY = 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'safety_precision_before', AVG(IFF(TRUE_CATEGORY = 'safety', 1, 0)), NULL FROM W02B_TICKETS WHERE CATEGORY_BEFORE = 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'safety_precision_after',  AVG(IFF(TRUE_CATEGORY = 'safety', 1, 0)), NULL FROM W02B_TICKETS WHERE CATEGORY_AFTER = 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'control_accuracy_before', AVG(IFF(CATEGORY_BEFORE = TRUE_CATEGORY, 1, 0)), '200 per other category' FROM W02B_TICKETS WHERE TRUE_CATEGORY <> 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'control_accuracy_after',  AVG(IFF(CATEGORY_AFTER  = TRUE_CATEGORY, 1, 0)), '200 per other category' FROM W02B_TICKETS WHERE TRUE_CATEGORY <> 'safety'
UNION ALL SELECT '<% run %>', 'w02b', 'accuracy_after_' || TRUE_CATEGORY, AVG(IFF(CATEGORY_AFTER = TRUE_CATEGORY, 1, 0)), NULL
          FROM W02B_TICKETS GROUP BY TRUE_CATEGORY
UNION ALL SELECT '<% run %>', 'w02b', 'accuracy_before_' || TRUE_CATEGORY, AVG(IFF(CATEGORY_BEFORE = TRUE_CATEGORY, 1, 0)), NULL
          FROM W02B_TICKETS GROUP BY TRUE_CATEGORY;

SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02b' ORDER BY METRIC;
