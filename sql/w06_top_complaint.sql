-- w06 Product: AI_AGG reads every review for a product and names the top complaint.
-- Truth = the most frequent planted complaint in the same rows (computed, not assumed).
-- Vars: run, n
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w06';

CREATE OR REPLACE TABLE W06_TOP_COMPLAINT AS
SELECT PRODUCT, COUNT(*) AS REVIEWS,
       AI_AGG(BODY, 'These are customer reviews of one product. What is the single most common complaint? '
                    || 'Answer with one short phrase. If there are no complaints, answer: none.') AS ANSWER
FROM REVIEWS WHERE ID <= <% n %>
GROUP BY PRODUCT;

-- Keyword map from complaint key to the words an answer must contain to count as a match.
CREATE OR REPLACE TABLE W06_KEYWORDS (KEY STRING, PATTERN STRING) AS
SELECT * FROM VALUES
  ('battery', 'batter'), ('fit', 'siz|small|fit'), ('noise', 'loud|nois'), ('instructions', 'instruction|manual'),
  ('durability', 'apart|durab|broke|break|month'), ('smell', 'smell|odor|odour'), ('app', '(^|[^a-z])apps?([^a-z]|$)|crash'),
  ('delivery_damage', 'scratch|dent|damage'), ('missing_parts', 'missing|screw|parts'), ('overheating', 'hot|heat');

CREATE OR REPLACE TABLE W06_SCORED AS
WITH truth AS (
  SELECT PRODUCT, COMPLAINT_KEY AS KEY, COUNT(*) c,
         COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY PRODUCT) AS SHARE
  FROM REVIEWS WHERE ID <= <% n %> AND COMPLAINT_KEY <> ''
  GROUP BY PRODUCT, COMPLAINT_KEY
  QUALIFY ROW_NUMBER() OVER (PARTITION BY PRODUCT ORDER BY c DESC, KEY) = 1)
SELECT a.PRODUCT, a.REVIEWS, a.ANSWER, t.KEY AS TRUE_KEY, t.SHARE AS TRUE_KEY_SHARE,
       REGEXP_LIKE(LOWER(a.ANSWER), '.*(' || k.PATTERN || ').*', 's') AS MATCHED
FROM W06_TOP_COMPLAINT a JOIN truth t ON t.PRODUCT = a.PRODUCT JOIN W06_KEYWORDS k ON k.KEY = t.KEY;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w06';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w06', 'products', COUNT(*), NULL FROM W06_SCORED
UNION ALL SELECT '<% run %>', 'w06', 'reviews_read', SUM(REVIEWS), NULL FROM W06_SCORED
UNION ALL SELECT '<% run %>', 'w06', 'top_complaint_accuracy', AVG(IFF(MATCHED, 1, 0)), 'answer names the most frequent complaint' FROM W06_SCORED
UNION ALL SELECT '<% run %>', 'w06', 'avg_true_key_share', AVG(TRUE_KEY_SHARE), 'how dominant the top complaint is' FROM W06_SCORED;

SELECT PRODUCT, TRUE_KEY, MATCHED, ANSWER FROM W06_SCORED ORDER BY PRODUCT LIMIT 10;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w06' ORDER BY METRIC;
