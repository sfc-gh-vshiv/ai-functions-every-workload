USE ROLE SYSADMIN;
USE WAREHOUSE BLOG_AIF_WH;
USE SCHEMA BLOG_AIF_TEST.T;
CREATE OR REPLACE MATERIALIZED VIEW mv_topic AS
  SELECT id, AI_CLASSIFY(body, ['billing', 'delivery', 'safety', 'other']):labels[0]::STRING AS topic
  FROM tickets;
SELECT * FROM mv_topic ORDER BY id;
