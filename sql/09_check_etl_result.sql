/*
    Project  : PT. LDR Data Warehouse
    File     : 09_check_etl_result.sql
    Purpose  : Validate final ETL result

    Notes:
    - Run this script after:
      08_load_fact.sql

    - This script checks:
      1. Row count for staging tables
      2. Row count for transform tables
      3. Row count for dimension and fact tables
      4. Missing foreign keys in fact table
      5. Sample analysis query
*/

USE LDR_DW;
GO

/* ============================================================
   1. Check staging row counts
   ============================================================ */

SELECT 'Stg_Shipments' AS table_name, COUNT(*) AS total_rows FROM LDR_Staging.dbo.Stg_Shipments
UNION ALL
SELECT 'Stg_Customers', COUNT(*) FROM LDR_Staging.dbo.Stg_Customers
UNION ALL
SELECT 'Stg_Branches', COUNT(*) FROM LDR_Staging.dbo.Stg_Branches
UNION ALL
SELECT 'Stg_Services', COUNT(*) FROM LDR_Staging.dbo.Stg_Services
UNION ALL
SELECT 'Stg_Couriers', COUNT(*) FROM LDR_Staging.dbo.Stg_Couriers
UNION ALL
SELECT 'Stg_Packages', COUNT(*) FROM LDR_Staging.dbo.Stg_Packages
UNION ALL
SELECT 'Stg_Payments', COUNT(*) FROM LDR_Staging.dbo.Stg_Payments
UNION ALL
SELECT 'Stg_ShipmentStatus', COUNT(*) FROM LDR_Staging.dbo.Stg_ShipmentStatus;
GO

/* ============================================================
   2. Check transform row counts
   ============================================================ */

SELECT 'Trf_Shipments' AS table_name, COUNT(*) AS total_rows FROM LDR_Staging.dbo.Trf_Shipments
UNION ALL
SELECT 'Trf_Customers', COUNT(*) FROM LDR_Staging.dbo.Trf_Customers
UNION ALL
SELECT 'Trf_Branches', COUNT(*) FROM LDR_Staging.dbo.Trf_Branches
UNION ALL
SELECT 'Trf_Services', COUNT(*) FROM LDR_Staging.dbo.Trf_Services
UNION ALL
SELECT 'Trf_Couriers', COUNT(*) FROM LDR_Staging.dbo.Trf_Couriers
UNION ALL
SELECT 'Trf_Packages', COUNT(*) FROM LDR_Staging.dbo.Trf_Packages
UNION ALL
SELECT 'Trf_Payments', COUNT(*) FROM LDR_Staging.dbo.Trf_Payments
UNION ALL
SELECT 'Trf_ShipmentStatus', COUNT(*) FROM LDR_Staging.dbo.Trf_ShipmentStatus;
GO

/* ============================================================
   3. Check data warehouse row counts
   ============================================================ */

SELECT 'DimDate' AS table_name, COUNT(*) AS total_rows FROM dbo.DimDate
UNION ALL
SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL
SELECT 'DimBranch', COUNT(*) FROM dbo.DimBranch
UNION ALL
SELECT 'DimService', COUNT(*) FROM dbo.DimService
UNION ALL
SELECT 'DimCourier', COUNT(*) FROM dbo.DimCourier
UNION ALL
SELECT 'DimPackage', COUNT(*) FROM dbo.DimPackage
UNION ALL
SELECT 'DimPayment', COUNT(*) FROM dbo.DimPayment
UNION ALL
SELECT 'DimShipmentStatus', COUNT(*) FROM dbo.DimShipmentStatus
UNION ALL
SELECT 'FactShipment', COUNT(*) FROM dbo.FactShipment;
GO

/* ============================================================
   4. Check missing foreign keys in FactShipment
   ============================================================ */

SELECT
    SUM(CASE WHEN transaction_date_key IS NULL THEN 1 ELSE 0 END) AS null_transaction_date_key,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_key,
    SUM(CASE WHEN origin_branch_key IS NULL THEN 1 ELSE 0 END) AS null_origin_branch_key,
    SUM(CASE WHEN destination_branch_key IS NULL THEN 1 ELSE 0 END) AS null_destination_branch_key,
    SUM(CASE WHEN service_key IS NULL THEN 1 ELSE 0 END) AS null_service_key,
    SUM(CASE WHEN courier_key IS NULL THEN 1 ELSE 0 END) AS null_courier_key,
    SUM(CASE WHEN package_key IS NULL THEN 1 ELSE 0 END) AS null_package_key,
    SUM(CASE WHEN payment_key IS NULL THEN 1 ELSE 0 END) AS null_payment_key,
    SUM(CASE WHEN status_key IS NULL THEN 1 ELSE 0 END) AS null_status_key
FROM dbo.FactShipment;
GO

/* ============================================================
   5. Check final joined data
   ============================================================ */

SELECT TOP 20
    f.shipment_key,
    f.shipment_id,
    f.awb_number,
    d.full_date AS transaction_date,
    c.customer_name,
    ob.branch_name AS origin_branch,
    db.branch_name AS destination_branch,
    s.service_name,
    cr.courier_name,
    p.package_type,
    pay.payment_method,
    st.status_name,
    f.shipping_fee,
    f.total_amount,
    f.is_late
FROM dbo.FactShipment f
LEFT JOIN dbo.DimDate d
    ON f.transaction_date_key = d.date_key
LEFT JOIN dbo.DimCustomer c
    ON f.customer_key = c.customer_key
LEFT JOIN dbo.DimBranch ob
    ON f.origin_branch_key = ob.branch_key
LEFT JOIN dbo.DimBranch db
    ON f.destination_branch_key = db.branch_key
LEFT JOIN dbo.DimService s
    ON f.service_key = s.service_key
LEFT JOIN dbo.DimCourier cr
    ON f.courier_key = cr.courier_key
LEFT JOIN dbo.DimPackage p
    ON f.package_key = p.package_key
LEFT JOIN dbo.DimPayment pay
    ON f.payment_key = pay.payment_key
LEFT JOIN dbo.DimShipmentStatus st
    ON f.status_key = st.status_key
ORDER BY f.shipment_key;
GO

/* ============================================================
   6. Simple ETL validation summary
   ============================================================ */

SELECT
    (SELECT COUNT(*) FROM LDR_Staging.dbo.Stg_Shipments) AS total_raw_shipments,
    (SELECT COUNT(*) FROM LDR_Staging.dbo.Trf_Shipments) AS total_transformed_shipments,
    (SELECT COUNT(*) FROM dbo.FactShipment) AS total_loaded_fact_shipments;
GO

/* ============================================================
   7. Sample analytical result after ETL
   ============================================================ */

SELECT
    s.service_name,
    COUNT(*) AS total_shipments,
    SUM(f.total_amount) AS total_revenue,
    SUM(CASE WHEN f.is_late = 1 THEN 1 ELSE 0 END) AS total_late_shipments
FROM dbo.FactShipment f
LEFT JOIN dbo.DimService s
    ON f.service_key = s.service_key
GROUP BY s.service_name
ORDER BY total_shipments DESC;
GO
