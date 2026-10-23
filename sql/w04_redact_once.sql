-- w04 CRM notes: redact PII once with AI_REDACT, store the result, and serve it through a
-- conditional masking policy. Readers never trigger an AI call. Only AIFW_PII_READER sees raw text.
-- Vars: run, n
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w04';
-- A row that AI_REDACT can't process returns NULL instead of failing the whole query.
ALTER SESSION SET AI_SQL_ERROR_HANDLING_USE_FAIL_ON_ERROR = FALSE;

CREATE OR REPLACE TABLE W04_NOTES AS
SELECT ID, NOTE, AI_REDACT(NOTE)::STRING AS NOTE_REDACTED, HAS_PII, PLANTED_PII
FROM NOTES WHERE ID <= <% n %>;

-- Score before the policy goes on: scoring needs the raw text.
CREATE OR REPLACE TABLE W04_PLANTED AS
SELECT n.ID, p.value::STRING AS PLANTED, CONTAINS(n.NOTE_REDACTED, p.value::STRING) AS LEAKED
FROM W04_NOTES n, LATERAL FLATTEN(PARSE_JSON(n.PLANTED_PII)) p
WHERE n.HAS_PII AND n.NOTE_REDACTED IS NOT NULL;

CREATE OR REPLACE TABLE W04_NAME_PARTS AS  -- first and last names, checked one by one
SELECT n.ID, s.value::STRING AS PART, CONTAINS(n.NOTE_REDACTED, s.value::STRING) AS LEAKED
FROM W04_NOTES n, LATERAL FLATTEN(PARSE_JSON(n.PLANTED_PII)) p, LATERAL SPLIT_TO_TABLE(p.value::STRING, ' ') s
WHERE n.HAS_PII AND n.NOTE_REDACTED IS NOT NULL AND p.index = 0 AND p.value::STRING NOT LIKE '%@%'
  AND REGEXP_LIKE(p.value::STRING, '^[A-Z][a-z]+ [A-Z][a-z]+$');

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w04';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w04', 'rows', COUNT(*), NULL FROM W04_NOTES
UNION ALL SELECT '<% run %>', 'w04', 'rows_with_pii', COUNT_IF(HAS_PII), NULL FROM W04_NOTES
UNION ALL SELECT '<% run %>', 'w04', 'null_rows', COUNT_IF(NOTE_REDACTED IS NULL), 'AI_REDACT returned NULL' FROM W04_NOTES
UNION ALL SELECT '<% run %>', 'w04', 'planted_values', COUNT(*), NULL FROM W04_PLANTED
UNION ALL SELECT '<% run %>', 'w04', 'value_leak_rate', AVG(IFF(LEAKED, 1, 0)), 'planted value still present verbatim' FROM W04_PLANTED
UNION ALL SELECT '<% run %>', 'w04', 'row_leak_rate', AVG(l), 'PII rows with any planted value verbatim'
          FROM (SELECT ID, MAX(IFF(LEAKED, 1, 0)) l FROM W04_PLANTED GROUP BY ID)
UNION ALL SELECT '<% run %>', 'w04', 'name_part_leak_rate', AVG(IFF(LEAKED, 1, 0)), 'first or last name still present' FROM W04_NAME_PARTS
UNION ALL SELECT '<% run %>', 'w04', 'clean_rows_changed', AVG(IFF(NOTE_REDACTED <> NOTE, 1, 0)), 'over-redaction on notes with no PII'
          FROM W04_NOTES WHERE NOT HAS_PII AND NOTE_REDACTED IS NOT NULL;

-- Serve it. Everyone except AIFW_PII_READER reads the stored redacted text from the NOTE column.
CREATE OR REPLACE MASKING POLICY W04_NOTE_MASK AS (note STRING, note_redacted STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('AIFW_PII_READER') THEN note ELSE note_redacted END;
ALTER TABLE W04_NOTES MODIFY COLUMN NOTE SET MASKING POLICY W04_NOTE_MASK USING (NOTE, NOTE_REDACTED);

INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
SELECT '<% run %>', 'w04', 'masked_reads_show_redacted', AVG(IFF(NOTE IS NOT DISTINCT FROM NOTE_REDACTED, 1, 0)),
       'NOTE as read by AIFW_ROLE after the policy' FROM W04_NOTES;

SELECT ID, NOTE AS NOTE_AS_AIFW_ROLE_SEES_IT FROM W04_NOTES WHERE HAS_PII ORDER BY ID LIMIT 3;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w04' ORDER BY METRIC;
