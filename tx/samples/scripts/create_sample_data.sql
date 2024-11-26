/* 
This script creates a database and schema containing sample data copied from snowflake_sample_data.tpch_sf10.
This is intended as a quick way to create and test a sample Tx project using dummy data. 

As snowflake_sample_data is a "shared" database, metadata operations like "get_ddl" and "describe" are not allowed, necessitating a local copy. 
Additional changes include renaming column names to remove table prefixes and setting physical constraints to help make sense of entity relationships.

Before running the script, please change the sample values in the "assign session variables" section below.

*/


/* assign session variables */

SET role_name = 'myRole';
SET database_name = 'myDB';
SET schema_name = 'mySchema';
SET location_name = $database_name || '.' || $schema_name;


/* create db and schema */

CREATE OR REPLACE DATABASE identifier($database_name); 

CREATE OR REPLACE SCHEMA identifier($schema_name);



/* create objects */

-- ************************************** part
CREATE OR REPLACE TABLE part
(
 part_id          number(38,0) NOT NULL,
 name             varchar NOT NULL,
 manufacturer     varchar NOT NULL,
 brand            varchar NOT NULL,
 type             varchar NOT NULL,
 size_centimeters number(38,0) NOT NULL,
 container        varchar NOT NULL,
 retail_price_usd number(12,2) NOT NULL,
 comment          varchar,
 __load_dts       timestamp_ltz(9),

 CONSTRAINT pk_part PRIMARY KEY ( part_id ) RELY
)
COMMENT = 'Parts we distribute'
AS 
SELECT p_partkey, p_name, p_mfgr, p_brand, p_type, p_size, p_container, p_retailprice, p_comment, CURRENT_TIMESTAMP() 
FROM snowflake_sample_data.tpch_sf10.part  
;

-- ************************************** location
CREATE OR REPLACE TABLE region 
(
 region_id number(38,0) NOT NULL,
 name        varchar(25) NOT NULL,
 comment     varchar(152),
 __load_dts       timestamp_ltz(9),
 
 CONSTRAINT pk_location PRIMARY KEY ( region_id) RELY
)
COMMENT = 'region mapping for our locations'
AS 
SELECT r_regionkey, r_name, r_comment, CURRENT_TIMESTAMP() 
FROM snowflake_sample_data.tpch_sf10.region  
;



-- ************************************** location
CREATE OR REPLACE TABLE location
(
 location_id number(38,0) NOT NULL,
 name        varchar(25) NOT NULL,
 region_id   number(38,0) NOT NULL,
 comment     varchar(152),
 __load_dts       timestamp_ltz(9),
 
 CONSTRAINT pk_location PRIMARY KEY ( location_id) RELY,
 CONSTRAINT ak_location_name UNIQUE ( name ) RELY,
 CONSTRAINT fk_location_mappedto_region FOREIGN KEY ( region_id ) REFERENCES region ( region_id ) RELY
)
COMMENT = 'location assigned to 
customer or supplier'
AS 
SELECT n_nationkey, n_name, n_regionkey, n_comment, CURRENT_TIMESTAMP()   
FROM snowflake_sample_data.tpch_sf10.nation  
;

-- ************************************** supplier
CREATE OR REPLACE TABLE supplier
(
 supplier_id         number(38,0) NOT NULL,
 name                varchar NOT NULL,
 address             varchar NOT NULL,
 location_id         number(38,0) NOT NULL,
 phone               varchar NOT NULL,
 account_balance_usd number(12,2) NOT NULL,
 comment             varchar,
 __load_dts       timestamp_ltz(9),
 
 CONSTRAINT pk_supplier PRIMARY KEY ( supplier_id ) RELY,
 CONSTRAINT FK_SUPPLIER_BASED_IN_LOCATION FOREIGN KEY ( location_id ) REFERENCES location ( location_id ) RELY
)
COMMENT = 'Suppliers who we buy from'
AS 
SELECT s_suppkey, s_name, s_address, s_nationkey, s_phone, s_acctbal, s_comment, CURRENT_TIMESTAMP()   
FROM snowflake_sample_data.tpch_sf10.supplier
;

-- ************************************** customer
CREATE OR REPLACE TABLE customer
(
 customer_id         number(38,0) NOT NULL,
 name                varchar NOT NULL,
 address             varchar NOT NULL,
 location_id         number(38,0) NOT NULL,
 phone               varchar(15) NOT NULL,
 account_balance_usd number(12,2) NOT NULL,
 market_segment      varchar(10) NOT NULL,
 comment             varchar,
 __load_dts       timestamp_ltz(9),

 CONSTRAINT pk_customer PRIMARY KEY ( customer_id ) RELY,
 CONSTRAINT FK_CUSTOMER_BASED_IN_LOCATION FOREIGN KEY ( location_id ) REFERENCES location ( location_id ) RELY
)
COMMENT = 'Registered cusotmers'
AS 
SELECT c_custkey, c_name, c_address, c_nationkey, c_phone, c_acctbal, c_mktsegment, c_comment, CURRENT_TIMESTAMP()   
FROM snowflake_sample_data.tpch_sf10.customer
;

-- ************************************** sales_order
CREATE OR REPLACE TABLE sales_order
(
 sales_order_id  number(38,0) NOT NULL,
 customer_id     number(38,0) NOT NULL,
 order_status    varchar(1),
 total_price_usd number(12,2),
 order_date      date,
 order_priority  varchar(15),
 clerk           varchar(15),
 ship_priority   number(38,0),
 comment         varchar(79),
 __load_dts      timestamp_ltz(9),

 CONSTRAINT pk_sales_order PRIMARY KEY ( sales_order_id ) RELY,
 CONSTRAINT FK_SALES_ORDER_PLACED_BY_CUSTOMER FOREIGN KEY ( customer_id ) REFERENCES customer ( customer_id ) RELY
)
COMMENT = 'single order per customer'
AS 
SELECT o_orderkey, o_custkey, o_orderstatus, o_totalprice, o_orderdate, o_orderpriority, o_clerk, o_shippriority, o_comment, CURRENT_TIMESTAMP()   
FROM snowflake_sample_data.tpch_sf10.orders 
;


-- ************************************** inventory
CREATE OR REPLACE TABLE inventory
(
 part_id           number(38,0) NOT NULL COMMENT 'part of unique identifier with ps_suppkey',
 supplier_id       number(38,0) NOT NULL COMMENT 'part of unique identifier with ps_partkey',
 available_amount  number(38,0) NOT NULL COMMENT 'number of parts available for sale',
 supplier_cost_usd number(12,2) NOT NULL COMMENT 'original cost paid to supplier',
 comment           varchar(),
 __load_dts       timestamp_ltz(9),

 CONSTRAINT pk_inventory PRIMARY KEY ( part_id, supplier_id ) RELY,
 CONSTRAINT FK_INVENTORY_STORES_PART FOREIGN KEY ( part_id ) REFERENCES part ( part_id ) RELY,
 CONSTRAINT FK_INVENTORY_SUPPLIED_BY_SUPPLIER FOREIGN KEY ( supplier_id ) REFERENCES supplier ( supplier_id ) RELY
)
COMMENT = 'Warehouse Inventory'
AS 
SELECT ps_partkey, ps_suppkey, ps_availqty, ps_supplycost, ps_comment, CURRENT_TIMESTAMP() 
FROM snowflake_sample_data.tpch_sf10.partsupp  
;

-- ************************************** lineitem
CREATE OR REPLACE TABLE lineitem
(
 line_number        number(38,0) NOT NULL,
 sales_order_id     number(38,0) NOT NULL,
 part_id            number(38,0) NOT NULL,
 supplier_id        number(38,0) NOT NULL,
 quantity           number(12,2),
 extended_price_usd number(12,2),
 discount_percent   number(12,2),
 tax_percent        number(12,2),
 return_flag        varchar(1),
 line_status        varchar(1),
 ship_date          date,
 commit_date        date,
 receipt_date       date,
 ship_instructions  varchar(25),
 ship_mode          varchar(10),
 comment            varchar(44),
 __load_dts         timestamp_ltz(9),

 CONSTRAINT pk_lineitem PRIMARY KEY ( line_number, sales_order_id ) RELY,
 CONSTRAINT FK_LINEITEM_CONSISTS_OF_SALES_ORDER FOREIGN KEY ( sales_order_id ) REFERENCES sales_order ( sales_order_id ) RELY,
 CONSTRAINT FK_LINEITEM_CONTAINING_PART FOREIGN KEY ( part_id ) REFERENCES part ( part_id ) RELY,
 CONSTRAINT FK_LINEITEM_SUPPLIED_BY_SUPPLIER FOREIGN KEY ( supplier_id ) REFERENCES supplier ( supplier_id ) RELY
)
COMMENT = 'various line items per order'
AS 
SELECT l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment, CURRENT_TIMESTAMP()  
FROM snowflake_sample_data.tpch_sf10.lineitem  
;


/* grant rights on newly created objects */ 

GRANT USAGE ON database  IDENTIFIER($database_name) TO ROLE IDENTIFIER($role_name);

-- Grant the ability to create schemas in the  database
GRANT CREATE SCHEMA ON DATABASE IDENTIFIER($database_name) TO ROLE IDENTIFIER($role_name);

-- Grant select privilege on all tables and views in the schema
GRANT USAGE ON SCHEMA IDENTIFIER($location_name) TO ROLE IDENTIFIER($role_name);
GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER($location_name) TO ROLE IDENTIFIER($role_name);

-- Optionally, if future tables will be created in the schema, ensure the role can select from them as well
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER($location_name)  TO ROLE IDENTIFIER($role_name);
