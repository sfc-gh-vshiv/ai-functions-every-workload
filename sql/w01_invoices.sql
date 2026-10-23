-- w01 Accounts payable: pull four fields from invoice PDFs in three layouts with AI_EXTRACT.
-- No template and no training. Scored against the values printed on each PDF.
-- Vars: run, n (number of PDFs)
USE ROLE AIFW_ROLE; USE WAREHOUSE AIFW_WH; USE SCHEMA AIFW.W;
ALTER SESSION SET QUERY_TAG = 'aifw:<% run %>:w01';

CREATE OR REPLACE TABLE W01_INVOICES AS
SELECT d.RELATIVE_PATH AS FILE,
       AI_EXTRACT(
         file => TO_FILE('@INVOICES', d.RELATIVE_PATH),
         responseFormat => {
           'vendor':       'What company issued this invoice?',
           'invoice_no':   'What is the invoice number or reference?',
           'invoice_date': 'What is the invoice issue date, as YYYY-MM-DD?',
           'total':        'What is the total amount due, as a number?'}) AS R
FROM DIRECTORY(@INVOICES) d
WHERE d.RELATIVE_PATH ILIKE '%.pdf'
ORDER BY d.RELATIVE_PATH
LIMIT <% n %>;

CREATE OR REPLACE TABLE W01_SCORED AS
SELECT t.FILE, t.LAYOUT,
       UPPER(TRIM(e.R:response:vendor::STRING)) = UPPER(t.VENDOR) AS VENDOR_OK,
       REGEXP_REPLACE(UPPER(e.R:response:invoice_no::STRING), '[^A-Z0-9]', '')
         = REGEXP_REPLACE(t.INVOICE_NO, '[^A-Z0-9]', '') AS NO_OK,
       TRY_TO_DATE(e.R:response:invoice_date::STRING) = t.INVOICE_DATE AS DATE_OK,
       TRY_TO_NUMBER(REGEXP_REPLACE(e.R:response:total::STRING, '[^0-9.]', ''), 12, 2) = t.TOTAL AS TOTAL_OK
FROM W01_INVOICES e JOIN INVOICE_TRUTH t ON t.FILE = e.FILE;

DELETE FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w01';
INSERT INTO RESULTS (RUN, WORKLOAD, METRIC, VALUE, NOTE)
          SELECT '<% run %>', 'w01', 'documents',       COUNT(*), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'vendor_accuracy', AVG(IFF(VENDOR_OK, 1, 0)), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'invoice_no_accuracy', AVG(IFF(NO_OK, 1, 0)), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'date_accuracy',   AVG(IFF(DATE_OK, 1, 0)), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'total_accuracy',  AVG(IFF(TOTAL_OK, 1, 0)), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'all_four_correct', AVG(IFF(VENDOR_OK AND NO_OK AND DATE_OK AND TOTAL_OK, 1, 0)), NULL FROM W01_SCORED
UNION ALL SELECT '<% run %>', 'w01', 'all_four_correct_layout_' || LAYOUT,
                 AVG(IFF(VENDOR_OK AND NO_OK AND DATE_OK AND TOTAL_OK, 1, 0)), NULL FROM W01_SCORED GROUP BY LAYOUT;

SELECT * FROM RESULTS WHERE RUN = '<% run %>' AND WORKLOAD = 'w01' ORDER BY METRIC;
