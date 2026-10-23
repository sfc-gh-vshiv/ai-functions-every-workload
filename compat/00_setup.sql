USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS BLOG_AIF_TEST;
CREATE SCHEMA IF NOT EXISTS BLOG_AIF_TEST.T;
CREATE WAREHOUSE IF NOT EXISTS BLOG_AIF_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE BLOG_AIF_WH;
USE SCHEMA BLOG_AIF_TEST.T;
CREATE OR REPLACE TABLE tickets (id INT, body STRING) CHANGE_TRACKING = TRUE;
INSERT INTO tickets VALUES
  (1, 'I was charged twice for order 4471.'),
  (2, 'My package is three days late.'),
  (3, 'The charger smells like burning plastic.'),
  (4, 'Call me at 415-555-0199, my name is Jane Doe.'),
  (5, 'Love the new app update!'),
  (6, 'The heater produced smoke.'),
  (7, 'Where is my refund?');
SELECT CURRENT_ACCOUNT_NAME() AS acct, CURRENT_ROLE() AS role, COUNT(*) AS n FROM tickets;
