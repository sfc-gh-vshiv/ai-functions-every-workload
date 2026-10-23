-- w07 Catalog search: embed product descriptions once with AI_EMBED, then search them with shopper
-- queries using VECTOR_COSINE_SIMILARITY. Searches cost warehouse time plus a few tokens per query.
-- The 60 held-out queries (3 per family) share no family-specific word with the descriptions. Nine share
-- only generic words (from, in, one, compact, travel) that occur in every family, so a keyword search
-- can't tell the families apart. The keyword baseline below shows that on the same queries.
-- Score: precision@5, the share of the 5 nearest products in the family the shopper wants.
-- Vars: run, n (products)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w07';

CREATE OR REPLACE TABLE W07_PRODUCTS AS
SELECT ID, FAMILY, DESCRIPTION, AI_EMBED('snowflake-arctic-embed-m-v1.5', DESCRIPTION) AS V
FROM PRODUCTS WHERE ID <= <% n %>;

ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w07:search';
CREATE OR REPLACE TABLE W07_QUERY_HITS AS
WITH q AS (SELECT ID, FAMILY AS WANT, Q, AI_EMBED('snowflake-arctic-embed-m-v1.5', Q) AS V FROM HELDOUT_QUERIES)
SELECT q.ID AS QID, q.Q, q.WANT, c.FAMILY AS HIT_FAMILY, VECTOR_COSINE_SIMILARITY(q.V, c.V) AS SIM
FROM q JOIN W07_PRODUCTS c
QUALIFY ROW_NUMBER() OVER (PARTITION BY q.ID ORDER BY SIM DESC, c.ID) <= 5;

-- Keyword baseline on the same queries: rank products by the number of distinct shared words.
CREATE OR REPLACE TABLE W07_KEYWORD_HITS AS
WITH qt AS (SELECT DISTINCT q.ID AS QID, q.FAMILY AS WANT, t.value::STRING AS TOK
            FROM HELDOUT_QUERIES q, LATERAL FLATTEN(REGEXP_SUBSTR_ALL(LOWER(q.Q), '[a-z0-9]+')) t),
     pt AS (SELECT DISTINCT p.ID, p.FAMILY, t.value::STRING AS TOK
            FROM PRODUCTS p, LATERAL FLATTEN(REGEXP_SUBSTR_ALL(LOWER(p.DESCRIPTION), '[a-z0-9]+')) t
            WHERE p.ID <= <% n %>),
     scored AS (SELECT qt.QID, qt.WANT, pt.ID, pt.FAMILY, COUNT(*) AS SHARED
                FROM qt JOIN pt ON pt.TOK = qt.TOK GROUP BY 1, 2, 3, 4),
     all_q AS (SELECT ID AS QID, FAMILY AS WANT FROM HELDOUT_QUERIES)
SELECT a.QID, a.WANT, s.FAMILY AS HIT_FAMILY, COALESCE(s.SHARED, 0) AS SHARED
FROM all_q a LEFT JOIN scored s ON s.QID = a.QID
QUALIFY ROW_NUMBER() OVER (PARTITION BY a.QID ORDER BY s.SHARED DESC NULLS LAST, s.ID) <= 5;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w07';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w07', 'products_embedded', COUNT(*), NULL FROM W07_PRODUCTS
UNION ALL SELECT '<% run %>', 'w07', 'queries', COUNT(DISTINCT QID), 'held-out, no family-specific word shared' FROM W07_QUERY_HITS
UNION ALL SELECT '<% run %>', 'w07', 'precision_at_5', AVG(IFF(HIT_FAMILY = WANT, 1, 0)), 'AI_EMBED + cosine similarity' FROM W07_QUERY_HITS
UNION ALL SELECT '<% run %>', 'w07', 'top1_accuracy', AVG(IFF(HIT_FAMILY = WANT, 1, 0)), 'nearest product only'
          FROM (SELECT * FROM W07_QUERY_HITS QUALIFY ROW_NUMBER() OVER (PARTITION BY QID ORDER BY SIM DESC) = 1)
UNION ALL SELECT '<% run %>', 'w07', 'keyword_precision_at_5', AVG(IFF(HIT_FAMILY = WANT, 1, 0)), 'shared-word ranking, same queries' FROM W07_KEYWORD_HITS
UNION ALL SELECT '<% run %>', 'w07', 'keyword_queries_with_no_match', COUNT(DISTINCT QID), 'no word in common with any product'
          FROM W07_KEYWORD_HITS WHERE SHARED = 0
UNION ALL SELECT '<% run %>', 'w07', 'random_baseline', 1 / COUNT(DISTINCT FAMILY), 'chance of a right-family hit' FROM W07_PRODUCTS;

SELECT Q, WANT, LISTAGG(HIT_FAMILY, ', ') WITHIN GROUP (ORDER BY SIM DESC) AS TOP5 FROM W07_QUERY_HITS GROUP BY QID, Q, WANT ORDER BY QID;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w07' ORDER BY METRIC;
