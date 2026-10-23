-- w05b Follow-up to w05: most missed incidents were INFO lines. Does telling the model to judge the
-- event, not the log level, fix that? Rows: every planted incident + 1,000 other lines.
-- Same rows are scored with the original w05 labels for a side-by-side.
-- Vars: run
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w05b';

CREATE OR REPLACE TABLE W05B_LOGS AS
WITH rows_ AS (
  SELECT * FROM W05_LOGS WHERE TRUE_CLASS = 'incident'
  UNION ALL
  SELECT * FROM (SELECT * FROM W05_LOGS WHERE TRUE_CLASS <> 'incident' ORDER BY HASH(ID) LIMIT 1000))
SELECT ID, LINE, TRUE_CLASS, CLASS AS CLASS_BEFORE,
       AI_CLASSIFY(LINE, [
         {'label': 'incident', 'description': 'possible security incident: brute force, data exfiltration, privilege grant, suspicious key or login, exposed network rule. Judge the event, not the log level: an INFO line can be an incident.'},
         {'label': 'error',    'description': 'operational failure or degradation: timeouts, retries, disk, slow queries, exceptions'},
         {'label': 'routine',  'description': 'normal activity that needs no action'}],
         {'task_description': 'Triage application and security log lines for an on-call engineer. Ignore the INFO/WARN/ERROR level and judge what happened.'})
       :labels[0]::STRING AS CLASS_AFTER
FROM rows_;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05b';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w05b', 'rows', COUNT(*), NULL FROM W05B_LOGS
UNION ALL SELECT '<% run %>', 'w05b', 'incident_recall_before', AVG(IFF(CLASS_BEFORE = 'incident', 1, 0)), NULL FROM W05B_LOGS WHERE TRUE_CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05b', 'incident_recall_after',  AVG(IFF(CLASS_AFTER  = 'incident', 1, 0)), NULL FROM W05B_LOGS WHERE TRUE_CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05b', 'incident_precision_before', AVG(IFF(TRUE_CLASS = 'incident', 1, 0)), NULL FROM W05B_LOGS WHERE CLASS_BEFORE = 'incident'
UNION ALL SELECT '<% run %>', 'w05b', 'incident_precision_after',  AVG(IFF(TRUE_CLASS = 'incident', 1, 0)), NULL FROM W05B_LOGS WHERE CLASS_AFTER = 'incident'
UNION ALL SELECT '<% run %>', 'w05b', 'control_accuracy_before', AVG(IFF(CLASS_BEFORE = TRUE_CLASS, 1, 0)), 'non-incident lines' FROM W05B_LOGS WHERE TRUE_CLASS <> 'incident'
UNION ALL SELECT '<% run %>', 'w05b', 'control_accuracy_after',  AVG(IFF(CLASS_AFTER  = TRUE_CLASS, 1, 0)), 'non-incident lines' FROM W05B_LOGS WHERE TRUE_CLASS <> 'incident';

SELECT REGEXP_REPLACE(LINE, '[0-9]+', '#') PATTERN, CLASS_BEFORE, CLASS_AFTER, COUNT(*) N
FROM W05B_LOGS WHERE TRUE_CLASS = 'incident' GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05b' ORDER BY METRIC;
