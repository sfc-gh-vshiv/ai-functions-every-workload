USE ROLE ACCOUNTADMIN;
USE WAREHOUSE BLOG_AIF_WH;
USE SCHEMA BLOG_AIF_TEST.T;
CREATE OR REPLACE STREAM tickets_s ON TABLE tickets;
CREATE OR REPLACE TABLE tickets_enriched (id INT, topic STRING);
INSERT INTO tickets VALUES (8, 'The kettle lid burned my hand.');
CREATE OR REPLACE TASK t_enrich
  WAREHOUSE = BLOG_AIF_WH
  SCHEDULE = '60 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('TICKETS_S')
AS
  INSERT INTO tickets_enriched
  SELECT id, AI_CLASSIFY(body, ['billing', 'delivery', 'safety', 'other']):labels[0]::STRING
  FROM tickets_s;
EXECUTE TASK t_enrich;
