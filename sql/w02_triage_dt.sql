-- w02 Support triage: AI_CLASSIFY inside an incremental dynamic table.
-- The claim under test: you pay once per row. New rows cost new calls, unchanged rows cost nothing.
-- Vars: run, n (initial tickets), n_new (tickets that arrive later)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w02';
SET W02_T0 = CURRENT_TIMESTAMP();

CREATE OR REPLACE TABLE W02_TICKETS CHANGE_TRACKING = TRUE AS
SELECT * FROM TICKETS WHERE ID <= <% n %>;

CREATE OR REPLACE DYNAMIC TABLE W02_TRIAGE
  TARGET_LAG = '1 day' WAREHOUSE = AIFW_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
SELECT ID, CREATED_AT, BODY, TRUE_CATEGORY, ALT_CATEGORY,
       REPLACE(AI_CLASSIFY(BODY, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])
               :labels[0]::STRING, ' ', '_') AS CATEGORY
FROM W02_TICKETS;

-- New tickets arrive. Refresh twice: the first refresh classifies only the new rows,
-- the second has no new data and must make no AI calls.
INSERT INTO W02_TICKETS SELECT * FROM TICKETS_NEW WHERE ID <= 10000 + <% n_new %>;
ALTER DYNAMIC TABLE W02_TRIAGE REFRESH;
ALTER DYNAMIC TABLE W02_TRIAGE REFRESH;

CREATE TABLE IF NOT EXISTS W02_REFRESHES (RUN STRING, QUERY_ID STRING, REFRESH_ACTION STRING, REFRESH_TRIGGER STRING,
  INSERTED_ROWS INT, REFRESH_START_TIME TIMESTAMP_LTZ, REFRESH_END_TIME TIMESTAMP_LTZ);
DELETE FROM W02_REFRESHES WHERE RUN = '<% run %>';
INSERT INTO W02_REFRESHES
SELECT '<% run %>', QUERY_ID, REFRESH_ACTION, REFRESH_TRIGGER, STATISTICS:numInsertedRows::INT,
       REFRESH_START_TIME, REFRESH_END_TIME
FROM TABLE(AIFW.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'AIFW.W.W02_TRIAGE'))
WHERE STATE = 'SUCCEEDED' AND REFRESH_START_TIME >= $W02_T0;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w02', 'rows', COUNT(*), NULL FROM W02_TRIAGE
UNION ALL SELECT '<% run %>', 'w02', 'accuracy',
                 AVG(IFF(CATEGORY = TRUE_CATEGORY OR (ALT_CATEGORY <> '' AND CATEGORY = ALT_CATEGORY), 1, 0)),
                 'correct = the primary topic, or the second topic for two-topic tickets' FROM W02_TRIAGE
UNION ALL SELECT '<% run %>', 'w02', 'accuracy_single_topic', AVG(IFF(CATEGORY = TRUE_CATEGORY, 1, 0)), NULL
          FROM W02_TRIAGE WHERE ALT_CATEGORY = ''
UNION ALL SELECT '<% run %>', 'w02', 'safety_recall', AVG(IFF(CATEGORY = 'safety', 1, 0)), 'share of safety tickets routed to safety'
          FROM W02_TRIAGE WHERE TRUE_CATEGORY = 'safety' AND ALT_CATEGORY = ''
UNION ALL SELECT '<% run %>', 'w02', 'safety_precision', AVG(IFF(TRUE_CATEGORY = 'safety' OR ALT_CATEGORY = 'safety', 1, 0)), NULL
          FROM W02_TRIAGE WHERE CATEGORY = 'safety'
UNION ALL SELECT '<% run %>', 'w02', 'refresh_' || LOWER(REFRESH_ACTION) || '_' || LOWER(REFRESH_TRIGGER) || '_rows',
                 INSERTED_ROWS, QUERY_ID FROM W02_REFRESHES WHERE RUN = '<% run %>';

SELECT * FROM W02_REFRESHES WHERE RUN = '<% run %>' ORDER BY REFRESH_START_TIME;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w02' ORDER BY METRIC;
