/*
    Project  : PT. LDR Data Warehouse
    File     : 07_load_dimensions.sql
    Purpose  : Load cleaned transform data into dimension tables

    Source database:
    - LDR_Staging

    Target database:
    - LDR_DW

    Dimension tables:
    - DimDate
    - DimCustomer
    - DimBranch
    - DimService
    - DimCourier
    - DimPackage
    - DimPayment
    - DimShipmentStatus

    Notes:
    - This script should be run after 06_create_dw_tables.sql.
    - Dimension data is loaded from Trf_* tables.
*/

USE LDR_DW;
GO

/* Clear dimension tables before reload.
   FactShipment must be empty before this script is run.
*/

DELETE FROM dbo.FactShipment;
GO

DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimBranch;
DELETE FROM dbo.DimService;
DELETE FROM dbo.DimCourier;
DELETE FROM dbo.DimPackage;
DELETE FROM dbo.DimPayment;
DELETE FROM dbo.DimShipmentStatus;
DELETE FROM dbo.DimDate;
GO

/* Reset identity columns */

DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimBranch', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimService', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimCourier', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimPackage', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimPayment', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimShipmentStatus', RESEED, 0);
GO

/* ============================================================
   1. Load DimDate
   Sources:
   - transaction_date
   - pickup_date
   - delivery_date
   - payment_date
   - registration_date
   - opening_date
   - hire_date
   ============================================================ */

INSERT INTO dbo.DimDate (
    date_key,
    full_date,
    day_number,
    day_name,
    month_number,
    month_name,
    quarter_number,
    year_number,
    is_weekend
)
SELECT DISTINCT
    CONVERT(INT, FORMAT(clean_date, 'yyyyMMdd')) AS date_key,
    clean_date AS full_date,
    DAY(clean_date) AS day_number,
    DATENAME(WEEKDAY, clean_date) AS day_name,
    MONTH(clean_date) AS month_number,
    DATENAME(MONTH, clean_date) AS month_name,
    DATEPART(QUARTER, clean_date) AS quarter_number,
    YEAR(clean_date) AS year_number,
    CASE 
        WHEN DATENAME(WEEKDAY, clean_date) IN ('Saturday', 'Sunday') THEN 1 
        ELSE 0 
    END AS is_weekend
FROM (
    SELECT transaction_date AS clean_date FROM LDR_Staging.dbo.Trf_Shipments
    UNION
    SELECT pickup_date FROM LDR_Staging.dbo.Trf_Shipments
    UNION
    SELECT delivery_date FROM LDR_Staging.dbo.Trf_Shipments
    UNION
    SELECT payment_date FROM LDR_Staging.dbo.Trf_Payments
    UNION
    SELECT registration_date FROM LDR_Staging.dbo.Trf_Customers
    UNION
    SELECT opening_date FROM LDR_Staging.dbo.Trf_Branches
    UNION
    SELECT hire_date FROM LDR_Staging.dbo.Trf_Couriers
) d
WHERE clean_date IS NOT NULL;
GO

/* ============================================================
   2. Load DimCustomer
   ============================================================ */

INSERT INTO dbo.DimCustomer (
    customer_id,
    customer_name,
    customer_type,
    gender,
    phone,
    email,
    city,
    province,
    registration_date,
    is_active
)
SELECT
    customer_id,
    customer_name,
    customer_type,
    gender,
    phone,
    email,
    city,
    province,
    registration_date,
    is_active
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY customer_id
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Customers
    WHERE customer_id IS NOT NULL
) c
WHERE rn = 1;
GO

/* ============================================================
   3. Load DimBranch
   ============================================================ */

INSERT INTO dbo.DimBranch (
    branch_id,
    branch_name,
    branch_type,
    address,
    city,
    province,
    region,
    manager_name,
    opening_date,
    is_active
)
SELECT
    branch_id,
    branch_name,
    branch_type,
    address,
    city,
    province,
    region,
    manager_name,
    opening_date,
    is_active
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY branch_id 
            ORDER BY branch_id
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Branches
    WHERE branch_id IS NOT NULL
) b
WHERE rn = 1;
GO

/* ============================================================
   4. Load DimService
   ============================================================ */

INSERT INTO dbo.DimService (
    service_code,
    service_name,
    service_category,
    delivery_estimation,
    max_weight,
    is_cod_available,
    is_active
)
SELECT
    service_code,
    service_name,
    service_category,
    delivery_estimation,
    max_weight,
    is_cod_available,
    is_active
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY service_code 
            ORDER BY service_code
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Services
    WHERE service_code IS NOT NULL
) s
WHERE rn = 1;
GO

/* ============================================================
   5. Load DimCourier
   ============================================================ */

INSERT INTO dbo.DimCourier (
    courier_id,
    courier_name,
    gender,
    phone,
    branch_id,
    vehicle_type,
    hire_date,
    employee_status,
    is_active
)
SELECT
    courier_id,
    courier_name,
    gender,
    phone,
    branch_id,
    vehicle_type,
    hire_date,
    employee_status,
    is_active
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY courier_id 
            ORDER BY courier_id
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Couriers
    WHERE courier_id IS NOT NULL
) c
WHERE rn = 1;
GO

/* ============================================================
   6. Load DimPackage
   ============================================================ */

INSERT INTO dbo.DimPackage (
    package_id,
    package_type,
    package_category,
    weight,
    weight_category,
    length_cm,
    width_cm,
    height_cm,
    volume_cm3,
    is_fragile,
    is_insured,
    item_description
)
SELECT
    package_id,
    package_type,
    package_category,
    weight,
    weight_category,
    length_cm,
    width_cm,
    height_cm,
    volume_cm3,
    is_fragile,
    is_insured,
    item_description
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY package_id 
            ORDER BY package_id
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Packages
    WHERE package_id IS NOT NULL
) p
WHERE rn = 1;
GO

/* ============================================================
   7. Load DimPayment
   ============================================================ */

INSERT INTO dbo.DimPayment (
    payment_id,
    payment_method,
    payment_channel,
    bank_name,
    payment_date,
    payment_status,
    is_cod,
    refund_status
)
SELECT
    payment_id,
    payment_method,
    payment_channel,
    bank_name,
    payment_date,
    payment_status,
    is_cod,
    refund_status
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id 
            ORDER BY payment_id
        ) AS rn
    FROM LDR_Staging.dbo.Trf_Payments
    WHERE payment_id IS NOT NULL
) p
WHERE rn = 1;
GO

/* ============================================================
   8. Load DimShipmentStatus
   ============================================================ */

INSERT INTO dbo.DimShipmentStatus (
    status_code,
    status_name,
    status_category,
    status_description
)
SELECT
    status_code,
    status_name,
    status_category,
    status_description
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY status_code 
            ORDER BY status_code
        ) AS rn
    FROM LDR_Staging.dbo.Trf_ShipmentStatus
    WHERE status_code IS NOT NULL
) s
WHERE rn = 1;
GO

/* Add Unknown status if needed */

IF NOT EXISTS (
    SELECT 1 FROM dbo.DimShipmentStatus WHERE status_code = 'UNKNOWN'
)
BEGIN
    INSERT INTO dbo.DimShipmentStatus (
        status_code,
        status_name,
        status_category,
        status_description
    )
    VALUES (
        'UNKNOWN',
        'Unknown',
        'Unknown',
        'Unmapped shipment status'
    );
END
GO

/* ============================================================
   9. Check dimension row counts
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
SELECT 'DimShipmentStatus', COUNT(*) FROM dbo.DimShipmentStatus;
GO

/* Preview dimensions */

SELECT TOP 10 * FROM dbo.DimCustomer;
SELECT TOP 10 * FROM dbo.DimBranch;
SELECT TOP 10 * FROM dbo.DimService;
GO
