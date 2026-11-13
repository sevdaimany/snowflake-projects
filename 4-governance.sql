ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "governance_with_horizon"}}';

USE ROLE useradmin;
USE DATABASE tb_101;
USE WAREHOUSE tb_dev_wh;

SHOW ROLES;

CREATE OR REPLACE ROLE tb_data_steward
COMMENT = 'Custom Role';

USE ROLE SECURITYADMIN;
-- warahouse
GRANT OPERATE, USAGE ON WAREHOUSE tb_dev_wh TO ROLE tb_data_steward;
-- database
GRANT USAGE ON DATABASE tb_101 TO ROLE tb_data_steward;
-- schemas
GRANT USAGE ON ALL SCHEMAS IN DATABASE tb_101 TO ROLE tb_data_steward;
-- tables
GRANT SELECT ON ALL TABLES IN SCHEMA raw_customer TO ROLE tb_data_steward;
GRANT ALL ON SCHEMA governance TO ROLE tb_data_steward;
GRANT ALL ON ALL TABLES IN SCHEMA governance TO ROLE tb_data_steward;


SET my_user = '"' || CURRENT_USER() || '"';  -- quote to preserve lowercase user name
GRANT ROLE tb_data_steward TO USER IDENTIFIER($my_user);

USE ROLE tb_data_steward;
SELECT TOP 50 * FROM raw_customer.customer_loyalty;

