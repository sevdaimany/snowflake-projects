ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "getting_started_with_snowflake"}}';


USE DATABASE tb_101;
USE ROLE accountadmin;

SHOW WAREHOUSES;

CREATE OR REPLACE WAREHOUSE my_wh
    COMMENT = 'My TastyBytes warehouse'
    WAREHOUSE_TYPE = 'standard'
    WAREHOUSE_SIZE = 'xsmall'
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'standard'
    AUTO_SUSPEND = 60
    INITIALLY_SUSPENDED = true
    AUTO_RESUME = false;

USE WAREHOUSE my_wh;

SELECT * FROM raw_pos.truck_details;

ALTER WAREHOUSE my_wh RESUME;
ALTER WAREHOUSE my_wh SET AUTO_RESUME = TRUE;

ALTER WAREHOUSE my_wh SET WAREHOUSE_SIZE = 'XLARGE';

SHOW WAREHOUSES;

SELECT 
    o.truck_brand_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.price) AS total_sales
FROM analytics.orders_v o
GROUP BY o.truck_brand_name
ORDER BY total_sales DESC;

ALTER WAREHOUSE my_wh SET warehouse_size = 'XSmall';

SELECT truck_build FROM raw_pos.truck_details;

CREATE OR REPLACE TABLE raw_pos.truck_dev CLONE raw_pos.truck_details;


ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS year NUMBER;
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS make VARCHAR(255);
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS model VARCHAR(255);

UPDATE raw_pos.truck_dev
SET
    year = truck_build:year::NUMBER,
    make = truck_build:make::VARCHAR,
    model = truck_build:model::VARCHAR;

SELECT TOP 10 *
FROM raw_pos.truck_dev;

SELECT make,
        COUNT(*)
FROM raw_pos.truck_dev
GROUP BY make
ORDER BY make DESC;

UPDATE raw_pos.truck_dev
SET make = 'Ford'
WHERE make = 'Ford_';


SELECT make,
        COUNT(*)
FROM raw_pos.truck_dev
GROUP BY make
ORDER BY make DESC;


ALTER TABLE raw_pos.truck_details SWAP WITH raw_pos.truck_dev;

ALTER TABLE raw_pos.truck_details DROP COLUMN truck_build;

DROP TABLE raw_pos.truck_details;
DESCRIBE TABLE raw_pos.truck_details;

UNDROP TABLE raw_pos.truck_details;
SELECT * FROM raw_pos.truck_details;
DROP TABLE raw_pos.truck_dev;

USE ROLE accountadmin;
CREATE OR REPLACE RESOURCE MONITOR my_resource_monitor
    WITH CREDIT_QUOTA = 100
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO SUSPEND
             ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE my_wh 
    SET RESOURCE_MONITOR = my_resource_monitor;


CREATE OR REPLACE SNOWFLAKE.CORE.BUDGET my_budget()
    COMMENT = 'My Tasty Bytes Budget';


-------------------------------------------------------------------------
--RESET--
-------------------------------------------------------------------------
-- Drop created objects
DROP RESOURCE MONITOR IF EXISTS my_resource_monitor;
DROP TABLE IF EXISTS raw_pos.truck_dev;

-- Reset truck details
CREATE OR REPLACE TABLE raw_pos.truck_details
AS 
SELECT * EXCLUDE (year, make, model)
FROM raw_pos.truck;

DROP WAREHOUSE IF EXISTS my_wh;
-- Unset Query Tag
ALTER SESSION UNSET query_tag;