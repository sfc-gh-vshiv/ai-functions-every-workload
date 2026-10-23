-- w05 Security and ops: AI_CLASSIFY sorts raw log lines into incident, error or routine.
-- The number that matters is incident recall: how many planted incidents reach a human.
-- Vars: run, n
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w05';

CREATE OR REPLACE TABLE W05_LOGS AS
SELECT ID, TS, LINE, TRUE_CLASS,
       AI_CLASSIFY(LINE, [
         {'label': 'incident', 'description': 'possible security incident: brute force, data exfiltration, privilege grant, suspicious key or login, exposed network rule'},
         {'label': 'error',    'description': 'operational failure or degradation: timeouts, retries, disk, slow queries, exceptions'},
         {'label': 'routine',  'description': 'normal activity that needs no action'}],
         {'task_description': 'Triage application and security log lines for an on-call engineer'})
       :labels[0]::STRING AS CLASS
FROM LOGS WHERE ID <= <% n %>;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w05', 'rows', COUNT(*), NULL FROM W05_LOGS
UNION ALL SELECT '<% run %>', 'w05', 'accuracy', AVG(IFF(CLASS = TRUE_CLASS, 1, 0)), NULL FROM W05_LOGS
UNION ALL SELECT '<% run %>', 'w05', 'planted_incidents', COUNT_IF(TRUE_CLASS = 'incident'), NULL FROM W05_LOGS
UNION ALL SELECT '<% run %>', 'w05', 'incident_recall', AVG(IFF(CLASS = 'incident', 1, 0)), NULL FROM W05_LOGS WHERE TRUE_CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05', 'incident_precision', AVG(IFF(TRUE_CLASS = 'incident', 1, 0)), NULL FROM W05_LOGS WHERE CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05', 'lines_for_human_review', COUNT_IF(CLASS IN ('incident', 'error')), 'incident + error' FROM W05_LOGS
UNION ALL SELECT '<% run %>', 'w05', 'confusion_' || TRUE_CLASS || '_as_' || COALESCE(CLASS, 'null'), COUNT(*), NULL
          FROM W05_LOGS GROUP BY TRUE_CLASS, CLASS;

SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05' ORDER BY METRIC;
