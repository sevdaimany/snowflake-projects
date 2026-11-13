ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "data_pipeline"}}';

USE DATABASE tb_101;
USE WAREHOUSE tb_de_wh;
USE ROLE tb_data_engineer;

CREATE OR REPLACE STAGE raw_pos.menu_stage
    COMMENT = 'Stage for menu data'
    URL =  's3://sfquickstarts/frostbyte_tastybytes/raw_pos/menu/'
    FILE_FORMAT = public.csv_ff;

CREATE OR REPLACE TABLE raw_pos.menu_staging
(
    menu_id NUMBER(19,0),
    menu_type_id NUMBER(38,0),
    menu_type VARCHAR(16777216),
    truck_brand_name VARCHAR(16777216),
    menu_item_id NUMBER(38,0),
    menu_item_name VARCHAR(16777216),
    item_category VARCHAR(16777216),
    item_subcategory VARCHAR(16777216),
    cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

COPY INTO raw_pos.menu_staging 
FROM @raw_pos.menu_stage;

SELECT TOP 10 *
FROM raw_pos.menu_staging;

SELECT menu_item_health_metrics_obj FROM raw_pos.menu_staging;

SELECT 
    menu_item_name,
    menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id,
    menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY AS ingredients 
FROM raw_pos.menu_staging;

SELECT 
    i.value::STRING AS ingredient_name,
    menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id,

FROM raw_pos.menu_staging m,
LATERAL FLATTEN(INPUT => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i
LIMIT 10;

-- Dynamic tables
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredients
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'
AS 
    SELECT 
        ingredient_name,
        menu_ids
    FROM (
        SELECT DISTINCT
               i.value::STRING as ingredient_name,
               ARRAY_AGG(m.menu_item_id) AS menu_ids
        FROM raw_pos.menu_staging m,
        LATERAL FLATTEN(input => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i
        GROUP BY i.value::STRING
    );

SELECT * FROM harmonized.ingredients LIMIT 10;

INSERT INTO raw_pos.menu_staging 
SELECT 
    10101, 15, 'Sandwiches', 'Better Off Bread', 157, 'Banh Mi', 'Main', 'Cold Option', 9.0, 12.0,
    PARSE_JSON('{"menu_item_health_metrics": [{"ingredients": ["French Baguette","Mayonnaise","Pickled Daikon","Cucumber","Pork Belly"],"is_dairy_free_flag": "N","is_gluten_free_flag": "N","is_healthy_flag": "Y","is_nut_free_flag": "Y"}],"menu_item_id": 157}');


-- You may need to wait up to 1 minute and re-run this query
SELECT * FROM harmonized.ingredients 
WHERE ingredient_name IN ('French Baguette', 'Pickled Daikon');

CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_to_menu_lookup
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'
AS
    SELECT 
        i.ingredient_name,
        m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
    FROM raw_pos.menu_staging m,
    LATERAL FLATTEN(input => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) f
    JOIN harmonized.ingredients i
    ON i.ingredient_name = f.value::STRING;

SELECT * 
FROM harmonized.ingredient_to_menu_lookup
ORDER BY menu_item_id;

INSERT INTO raw_pos.order_header
SELECT 
    459520441, 15, 1030, 101565, null, 200322900,
    TO_TIMESTAMP_NTZ('08:00:00', 'hh:mi:ss'),
    TO_TIMESTAMP_NTZ('14:00:00', 'hh:mi:ss'),
    null, TO_TIMESTAMP_NTZ('2022-01-27 08:21:08.000'),
    null, 'USD', 14.00, null, null, 14.00;
    
INSERT INTO raw_pos.order_detail
SELECT
    904745311, 459520441, 157, null, 0, 2, 14.00, 28.00, null;

CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_usage_by_truck 
    LAG = '2 minute'
    WAREHOUSE = 'TB_DE_WH'  
    AS 
    SELECT
        oh.truck_id,
        EXTRACT(YEAR FROM oh.order_ts) AS order_year,
        MONTH(oh.order_ts) AS order_month,
        i.ingredient_name,
        SUM(od.quantity) AS total_ingredients_used
    FROM
        raw_pos.order_detail od
        JOIN raw_pos.order_header oh ON od.order_id = oh.order_id
        JOIN harmonized.ingredient_to_menu_lookup iml ON od.menu_item_id = iml.menu_item_id
        JOIN harmonized.ingredients i ON iml.ingredient_name = i.ingredient_name
        JOIN raw_pos.location l ON l.location_id = oh.location_id
    WHERE l.country = 'United States'
    GROUP BY
        oh.truck_id,
        order_year,
        order_month,
        i.ingredient_name
    ORDER BY
        oh.truck_id,
        total_ingredients_used DESC;

-- You may need to wait up to 2 minutes and re-run this query
SELECT
    truck_id,
    ingredient_name,
    SUM(total_ingredients_used) AS total_ingredients_used
FROM
    harmonized.ingredient_usage_by_truck
WHERE
    order_month = 1
    AND truck_id = 15
GROUP BY truck_id, ingredient_name
ORDER BY total_ingredients_used DESC;


-------------------------------------------------------------------------
--RESET--
-------------------------------------------------------------------------
USE ROLE accountadmin;
--Drop Dynamic Tables
DROP TABLE IF EXISTS raw_pos.menu_staging;
DROP TABLE IF EXISTS harmonized.ingredients;
DROP TABLE IF EXISTS harmonized.ingredient_to_menu_lookup;
DROP TABLE IF EXISTS harmonized.ingredient_usage_by_truck;

--Delete inserts
DELETE FROM raw_pos.order_detail
WHERE order_detail_id = 904745311;
DELETE FROM raw_pos.order_header
WHERE order_id = 459520441;

-- Unset Query Tag
ALTER SESSION UNSET query_tag;
-- Suspend warehouse
ALTER WAREHOUSE tb_de_wh SUSPEND;