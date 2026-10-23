-- w03 Review data quality: AI_FILTER finds reviews whose star rating contradicts the text.
-- Vars: run, n
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w03';

CREATE OR REPLACE TABLE W03_REVIEWS AS
SELECT ID, PRODUCT, STARS, BODY, TRUE_CONTRADICTION,
       AI_FILTER(PROMPT('A customer gave {0} out of 5 stars and wrote: "{1}". Does the star rating contradict the written review?',
                        STARS, BODY)) AS FLAGGED
FROM REVIEWS WHERE ID <= <% n %>;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w03';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
WITH c AS (
  SELECT COUNT_IF(FLAGGED AND TRUE_CONTRADICTION) tp, COUNT_IF(FLAGGED AND NOT TRUE_CONTRADICTION) fp,
         COUNT_IF(NOT FLAGGED AND TRUE_CONTRADICTION) fn, COUNT(*) n, COUNT_IF(FLAGGED IS NULL) nulls
  FROM W03_REVIEWS)
          SELECT '<% run %>', 'w03', 'rows', n, NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'planted_contradictions', tp + fn, NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'flagged', tp + fp, NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'precision', tp / NULLIF(tp + fp, 0), NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'recall', tp / NULLIF(tp + fn, 0), NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'f1', 2 * tp / NULLIF(2 * tp + fp + fn, 0), NULL FROM c
UNION ALL SELECT '<% run %>', 'w03', 'null_rows', nulls, NULL FROM c;

SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w03' ORDER BY METRIC;
