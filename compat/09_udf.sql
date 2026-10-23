USE ROLE SYSADMIN;
USE WAREHOUSE BLOG_AIF_WH;
USE SCHEMA BLOG_AIF_TEST.T;
CREATE OR REPLACE SECURE FUNCTION classify_ticket(b STRING)
  RETURNS STRING
  AS $$ AI_CLASSIFY(b, ['billing', 'delivery', 'safety', 'other']):labels[0]::STRING $$;
SELECT id, classify_ticket(body) AS topic FROM tickets ORDER BY id;
