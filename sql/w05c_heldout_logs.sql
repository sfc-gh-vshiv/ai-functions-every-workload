-- w05c Held-out check for w05 and w05b: 180 log lines (60 incident, 60 error, 60 routine) written
-- separately from the templates and from both prompts. 30 of the 60 incidents are INFO lines.
-- Each line is scored with the w05 prompt and the w05b prompt ("judge the event, not the log level").
-- Vars: run
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w05c';

CREATE OR REPLACE TABLE W05C_LOGS AS
SELECT ID, TRUE_CLASS, LINE, SPLIT_PART(LINE, ' ', 1) AS LEVEL,
       AI_CLASSIFY(LINE, [
         {'label': 'incident', 'description': 'possible security incident: brute force, data exfiltration, privilege grant, suspicious key or login, exposed network rule'},
         {'label': 'error',    'description': 'operational failure or degradation: timeouts, retries, disk, slow queries, exceptions'},
         {'label': 'routine',  'description': 'normal activity that needs no action'}],
         {'task_description': 'Triage application and security log lines for an on-call engineer'})
       :labels[0]::STRING AS CLASS_W05,
       AI_CLASSIFY(LINE, [
         {'label': 'incident', 'description': 'possible security incident: brute force, data exfiltration, privilege grant, suspicious key or login, exposed network rule. Judge the event, not the log level: an INFO line can be an incident.'},
         {'label': 'error',    'description': 'operational failure or degradation: timeouts, retries, disk, slow queries, exceptions'},
         {'label': 'routine',  'description': 'normal activity that needs no action'}],
         {'task_description': 'Triage application and security log lines for an on-call engineer. Ignore the INFO/WARN/ERROR level and judge what happened.'})
       :labels[0]::STRING AS CLASS_W05B
FROM HELDOUT_LOGS;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05c';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w05c', 'rows', COUNT(*), NULL FROM W05C_LOGS
UNION ALL SELECT '<% run %>', 'w05c', 'incident_recall_w05', AVG(IFF(CLASS_W05 = 'incident', 1, 0)), '60 incidents' FROM W05C_LOGS WHERE TRUE_CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05c', 'incident_recall_w05b', AVG(IFF(CLASS_W05B = 'incident', 1, 0)), '60 incidents' FROM W05C_LOGS WHERE TRUE_CLASS = 'incident'
UNION ALL SELECT '<% run %>', 'w05c', 'incident_recall_info_w05', AVG(IFF(CLASS_W05 = 'incident', 1, 0)), '30 INFO incidents'
          FROM W05C_LOGS WHERE TRUE_CLASS = 'incident' AND LEVEL = 'INFO'
UNION ALL SELECT '<% run %>', 'w05c', 'incident_recall_info_w05b', AVG(IFF(CLASS_W05B = 'incident', 1, 0)), '30 INFO incidents'
          FROM W05C_LOGS WHERE TRUE_CLASS = 'incident' AND LEVEL = 'INFO'
UNION ALL SELECT '<% run %>', 'w05c', 'false_incidents_w05', COUNT_IF(CLASS_W05 = 'incident'), 'of 120 non-incident lines' FROM W05C_LOGS WHERE TRUE_CLASS <> 'incident'
UNION ALL SELECT '<% run %>', 'w05c', 'false_incidents_w05b', COUNT_IF(CLASS_W05B = 'incident'), 'of 120 non-incident lines' FROM W05C_LOGS WHERE TRUE_CLASS <> 'incident'
UNION ALL SELECT '<% run %>', 'w05c', 'accuracy_w05', AVG(IFF(CLASS_W05 = TRUE_CLASS, 1, 0)), NULL FROM W05C_LOGS
UNION ALL SELECT '<% run %>', 'w05c', 'accuracy_w05b', AVG(IFF(CLASS_W05B = TRUE_CLASS, 1, 0)), NULL FROM W05C_LOGS;

SELECT TRUE_CLASS, CLASS_W05, CLASS_W05B, LINE FROM W05C_LOGS
WHERE CLASS_W05 <> TRUE_CLASS OR CLASS_W05B <> TRUE_CLASS ORDER BY TRUE_CLASS, ID;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w05c' ORDER BY METRIC;
