/*
    Project  : PT. LDR Data Warehouse
    File     : 02_create_staging_tables.sql
    Purpose  : Create staging tables for raw CSV data

    Notes:
    - This script is adjusted to the 8 dirty CSV files:
      1. shipments.csv
      2. customers.csv
      3. branches.csv
      4. services.csv
      5. couriers.csv
      6. packages.csv
      7. payments.csv
      8. shipment_status.csv

    - All columns are mostly VARCHAR because staging tables store raw dirty data.
    - Data type conversion will be done later in the transform step.
*/

USE LDR_Staging;
GO

/* Drop staging tables if they already exist */

IF OBJECT_ID('dbo.Stg_Shipments', 'U') IS NOT NULL DROP TABLE dbo.Stg_Shipments;
IF OBJECT_ID('dbo.Stg_Customers', 'U') IS NOT NULL DROP TABLE dbo.Stg_Customers;
IF OBJECT_ID('dbo.Stg_Branches', 'U') IS NOT NULL DROP TABLE dbo.Stg_Branches;
IF OBJECT_ID('dbo.Stg_Services', 'U') IS NOT NULL DROP TABLE dbo.Stg_Services;
IF OBJECT_ID('dbo.Stg_Couriers', 'U') IS NOT NULL DROP TABLE dbo.Stg_Couriers;
IF OBJECT_ID('dbo.Stg_Packages', 'U') IS NOT NULL DROP TABLE dbo.Stg_Packages;
IF OBJECT_ID('dbo.Stg_Payments', 'U') IS NOT NULL DROP TABLE dbo.Stg_Payments;
IF OBJECT_ID('dbo.Stg_ShipmentStatus', 'U') IS NOT NULL DROP TABLE dbo.Stg_ShipmentStatus;
GO

/* 1. Raw shipment transaction data */

CREATE TABLE dbo.Stg_Shipments (
    shipment_id             VARCHAR(50),
    awb_number              VARCHAR(50),
    transaction_date        VARCHAR(50),
    pickup_date             VARCHAR(50),
    delivery_date           VARCHAR(50),
    customer_id             VARCHAR(50),
    origin_branch_id        VARCHAR(50),
    destination_branch_id   VARCHAR(50),
    service_code            VARCHAR(50),
    courier_id              VARCHAR(50),
    package_id              VARCHAR(50),
    payment_id              VARCHAR(50),
    status_code             VARCHAR(100),
    estimated_days          VARCHAR(50),
    actual_days             VARCHAR(50),
    shipping_fee            VARCHAR(50),
    insurance_fee           VARCHAR(50),
    discount_amount         VARCHAR(50),
    total_amount            VARCHAR(50)
);
GO

/* 2. Raw customer data */

CREATE TABLE dbo.Stg_Customers (
    customer_id         VARCHAR(50),
    customer_name       VARCHAR(150),
    customer_type       VARCHAR(100),
    gender              VARCHAR(50),
    phone               VARCHAR(50),
    email               VARCHAR(150),
    city                VARCHAR(100),
    province            VARCHAR(100),
    registration_date   VARCHAR(50),
    status              VARCHAR(50)
);
GO

/* 3. Raw branch data */

CREATE TABLE dbo.Stg_Branches (
    branch_id       VARCHAR(50),
    branch_name     VARCHAR(150),
    branch_type     VARCHAR(100),
    address         VARCHAR(255),
    city            VARCHAR(100),
    province        VARCHAR(100),
    region          VARCHAR(100),
    manager_name    VARCHAR(150),
    opening_date    VARCHAR(50),
    is_active       VARCHAR(50)
);
GO

/* 4. Raw service master data */

CREATE TABLE dbo.Stg_Services (
    service_code            VARCHAR(50),
    service_name            VARCHAR(150),
    service_category        VARCHAR(100),
    delivery_estimation     VARCHAR(100),
    max_weight              VARCHAR(50),
    cod_available           VARCHAR(50),
    status                  VARCHAR(50)
);
GO

/* 5. Raw courier data */

CREATE TABLE dbo.Stg_Couriers (
    courier_id          VARCHAR(50),
    courier_name        VARCHAR(150),
    gender              VARCHAR(50),
    phone               VARCHAR(50),
    branch_id           VARCHAR(50),
    vehicle_type        VARCHAR(100),
    hire_date           VARCHAR(50),
    employee_status     VARCHAR(100),
    is_active           VARCHAR(50)
);
GO

/* 6. Raw package data */

CREATE TABLE dbo.Stg_Packages (
    package_id          VARCHAR(50),
    package_type        VARCHAR(100),
    package_category    VARCHAR(100),
    weight              VARCHAR(50),
    weight_unit         VARCHAR(20),
    length_cm           VARCHAR(50),
    width_cm            VARCHAR(50),
    height_cm           VARCHAR(50),
    fragile_flag        VARCHAR(50),
    insured_flag        VARCHAR(50),
    item_description    VARCHAR(255)
);
GO

/* 7. Raw payment data */

CREATE TABLE dbo.Stg_Payments (
    payment_id          VARCHAR(50),
    payment_method      VARCHAR(100),
    payment_channel     VARCHAR(100),
    bank_name           VARCHAR(100),
    payment_date        VARCHAR(50),
    payment_status      VARCHAR(100),
    is_cod              VARCHAR(50),
    refund_status       VARCHAR(100)
);
GO

/* 8. Raw shipment status master data */

CREATE TABLE dbo.Stg_ShipmentStatus (
    status_code             VARCHAR(50),
    status_name             VARCHAR(100),
    status_category         VARCHAR(100),
    status_description      VARCHAR(255)
);
GO

/* Check created staging tables */

SELECT 
    TABLE_NAME AS staging_table_name
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO
