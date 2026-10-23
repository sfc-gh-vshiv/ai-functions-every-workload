-- w10 Agent assist: AI_COMPLETE drafts a reply for every ticket with a small model (llama3.1-8b).
-- On a k-row sample, a larger model (llama3.3-70b) drafts the same replies, and AI_FILTER
-- judges both against one rubric. The question: does the small model's quality justify its price?
-- Vars: run, n (tickets drafted with the small model), k (comparison sample)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
SET W10_PROMPT = 'You are a support agent for an online store. Reply to the customer ticket below in two or three '
  || 'polite sentences. Acknowledge the problem and say the next step. Do not promise a refund amount, a delivery date, '
  || 'or anything you cannot check. Write only the reply. Ticket: ';

ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w10:small';
CREATE OR REPLACE TABLE W10_REPLIES AS
SELECT ID, BODY, AI_COMPLETE(model => 'llama3.1-8b', prompt => $W10_PROMPT || BODY,
                             model_parameters => {'temperature': 0, 'max_tokens': 120}) AS REPLY_SMALL
FROM TICKETS WHERE ID <= <% n %>;

ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w10:large';
CREATE OR REPLACE TABLE W10_COMPARE AS
SELECT ID, BODY, REPLY_SMALL,
       AI_COMPLETE(model => 'llama3.3-70b', prompt => $W10_PROMPT || BODY,
                   model_parameters => {'temperature': 0, 'max_tokens': 120}) AS REPLY_LARGE
FROM W10_REPLIES WHERE ID <= <% k %>;

ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w10:judge';
SET W10_RUBRIC = 'Support ticket: "{0}" Draft reply: "{1}" Is this reply polite, does it address the customer''s '
  || 'actual problem, and does it avoid promising a refund amount or a delivery date?';
CREATE OR REPLACE TABLE W10_JUDGED AS
SELECT ID, AI_FILTER(PROMPT($W10_RUBRIC, BODY, REPLY_SMALL)) AS PASS_SMALL,
           AI_FILTER(PROMPT($W10_RUBRIC, BODY, REPLY_LARGE)) AS PASS_LARGE
FROM W10_COMPARE;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w10';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w10', 'replies_small', COUNT(*), 'llama3.1-8b' FROM W10_REPLIES
UNION ALL SELECT '<% run %>', 'w10', 'empty_replies_small', COUNT_IF(REPLY_SMALL IS NULL OR LENGTH(TRIM(REPLY_SMALL)) = 0), NULL FROM W10_REPLIES
UNION ALL SELECT '<% run %>', 'w10', 'avg_reply_chars_small', AVG(LENGTH(REPLY_SMALL)), NULL FROM W10_REPLIES
UNION ALL SELECT '<% run %>', 'w10', 'compared', COUNT(*), NULL FROM W10_JUDGED
UNION ALL SELECT '<% run %>', 'w10', 'pass_rate_small', AVG(IFF(PASS_SMALL, 1, 0)), 'llama3.1-8b, AI_FILTER rubric' FROM W10_JUDGED
UNION ALL SELECT '<% run %>', 'w10', 'pass_rate_large', AVG(IFF(PASS_LARGE, 1, 0)), 'llama3.3-70b, AI_FILTER rubric' FROM W10_JUDGED
UNION ALL SELECT '<% run %>', 'w10', 'large_only_pass', COUNT_IF(PASS_LARGE AND NOT PASS_SMALL), NULL FROM W10_JUDGED
UNION ALL SELECT '<% run %>', 'w10', 'small_only_pass', COUNT_IF(PASS_SMALL AND NOT PASS_LARGE), NULL FROM W10_JUDGED;

SELECT c.ID, LEFT(c.BODY, 90) TICKET, c.REPLY_SMALL, c.REPLY_LARGE, j.PASS_SMALL, j.PASS_LARGE
FROM W10_COMPARE c JOIN W10_JUDGED j USING (ID) ORDER BY c.ID LIMIT 3;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w10' ORDER BY METRIC;
