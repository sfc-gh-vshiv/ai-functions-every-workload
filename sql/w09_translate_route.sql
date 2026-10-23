-- w09 Global support: AI_TRANSLATE brings tickets in five languages to English (source language
-- detected), then AI_CLASSIFY routes them. Also tests AI_CLASSIFY on the untranslated text.
-- Vars: run, n (tickets translated), k (tickets classified, both ways)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w09';

CREATE OR REPLACE TABLE W09_TRANSLATED AS
SELECT ID, LANG, BODY, TRUE_CATEGORY, ORDER_REF, AI_TRANSLATE(BODY, '', 'en') AS BODY_EN
FROM FOREIGN_TICKETS WHERE ID <= <% n %>;

ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w09:classify';
CREATE OR REPLACE TABLE W09_CLASSIFIED AS
SELECT ID, LANG, TRUE_CATEGORY,
       REPLACE(AI_CLASSIFY(BODY_EN, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])
               :labels[0]::STRING, ' ', '_') AS CAT_FROM_EN,
       REPLACE(AI_CLASSIFY(BODY, ['billing', 'shipping', 'product defect', 'account access', 'returns', 'safety'])
               :labels[0]::STRING, ' ', '_') AS CAT_FROM_ORIGINAL
FROM W09_TRANSLATED WHERE ID <= <% k %>;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w09';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w09', 'translated', COUNT(*), NULL FROM W09_TRANSLATED
UNION ALL SELECT '<% run %>', 'w09', 'null_translations', COUNT_IF(BODY_EN IS NULL), NULL FROM W09_TRANSLATED
UNION ALL SELECT '<% run %>', 'w09', 'order_ref_preserved', AVG(IFF(CONTAINS(BODY_EN, ORDER_REF), 1, 0)), 'order number survives translation'
          FROM W09_TRANSLATED WHERE ORDER_REF <> ''
UNION ALL SELECT '<% run %>', 'w09', 'classified', COUNT(*), NULL FROM W09_CLASSIFIED
UNION ALL SELECT '<% run %>', 'w09', 'accuracy_translated', AVG(IFF(CAT_FROM_EN = TRUE_CATEGORY, 1, 0)), NULL FROM W09_CLASSIFIED
UNION ALL SELECT '<% run %>', 'w09', 'accuracy_original', AVG(IFF(CAT_FROM_ORIGINAL = TRUE_CATEGORY, 1, 0)), 'no translation step' FROM W09_CLASSIFIED
UNION ALL SELECT '<% run %>', 'w09', 'accuracy_translated_' || LANG, AVG(IFF(CAT_FROM_EN = TRUE_CATEGORY, 1, 0)), NULL
          FROM W09_CLASSIFIED GROUP BY LANG;

SELECT LANG, BODY, BODY_EN FROM W09_TRANSLATED QUALIFY ROW_NUMBER() OVER (PARTITION BY LANG ORDER BY ID) = 1;
SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w09' ORDER BY METRIC;
