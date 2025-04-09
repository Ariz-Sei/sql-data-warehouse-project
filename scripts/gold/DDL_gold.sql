
/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema).
    
    Views in this layer:
    - Join and integrate cleaned, conformed data from the Silver layer.
    - Apply final business logic and filters (e.g., removing historical records).
    - Serve as business-ready datasets for reporting, analytics, and dashboards.

Usage:
    - These views can be queried directly for insights.
    - Ideal for consumption by BI tools and data analysts.
===============================================================================
*/


-- ============================================================================
-- dim_customers View
-- ============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS 
SELECT 
	  ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key -- Surrogate key 
	  ,ci.cst_id AS customer_id
      ,ci.cst_key AS customer_number
      ,ci.cst_firstname AS first_name
      ,ci.cst_lastname AS last_name
	  ,la.cntry AS country
      ,ci.cst_material_status AS marital_status
	  ,CASE 
	       WHEN ci.cst_gndr != 'Unknown' THEN ci.cst_gndr -- CRM is the primary source for gender 
	       ELSE COALESCE(ca.gen, 'Unknown') -- Fallback to ERP data 
	   END AS gender -- Data integration and enrichment
	  ,ca.bdate AS birthdate
	  ,ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la ON ci.cst_key = la.cid;
GO

-- ============================================================================
-- dim_products View
-- ============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS 
SELECT 
	   ROW_NUMBER() OVER (ORDER BY pn.prad_start_dt, pn.prd_key) AS product_key -- Surrogate key
	  ,pn.prd_id AS product_id
	  ,pn.prd_key AS product_number
	  ,pn.prd_nm AS product_name
      ,pn.cat_id AS category_id
      ,pc.cat AS category
	  ,pc.subcat AS subcategory
      ,pc.maintainance
      ,pn.prd_cost 
      ,pn.prd_line AS product_line
      ,pn.prad_start_dt AS start_date 
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL; -- Filter to only latest/active product records
GO

-- ============================================================================
-- fact_sales View
-- ============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT 
	   sls_ord_num AS order_number
      ,pr.product_key
      ,cu.customer_key
      ,sls_order_dt AS order_date
      ,sls_ship_dt AS shipping_date
      ,sls_due_dt AS due_date
      ,sls_sales AS sales_amount
      ,sls_quantity AS quantity
      ,sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu ON sd.sls_cust_id = cu.customer_id;
GO
