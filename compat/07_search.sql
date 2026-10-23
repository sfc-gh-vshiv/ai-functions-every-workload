USE ROLE SYSADMIN;
USE WAREHOUSE BLOG_AIF_WH;
USE SCHEMA BLOG_AIF_TEST.T;
CREATE OR REPLACE CORTEX SEARCH SERVICE css_tickets
  ON summary
  WAREHOUSE = BLOG_AIF_WH
  TARGET_LAG = '1 day'
AS
  SELECT id::STRING AS id,
         AI_COMPLETE('llama3.1-8b',
           'Summarize this support ticket in 10 words: ' || body)::STRING AS summary
  FROM tickets;
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_TICKETS';
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW('BLOG_AIF_TEST.T.CSS_TICKETS',
  '{"query": "refund", "columns": ["id", "summary"], "limit": 2}') AS hits;
