/*
    Project  : PT. LDR Data Warehouse
    File     : 04_create_transform_tables.sql
    Purpose  : Create transform tables for cleaned data

    Updated:
    - Trf_Shipments now includes delay_days.
    - Business calculation fields are prepared in transform layer.
*/

USE LDR_Staging;
GO

/* Drop transform tables if they already exist */

IF OBJECT_ID('dbo.Trf_Shipments', 'U') IS NOT NULL DROP TABLE dbo.Trf_Shipments;
IF OBJECT_ID('dbo.Trf_Customers', 'U') IS NOT NULL DROP TABLE dbo.Trf_Customers;
IF OBJECT_ID('dbo.Trf_Branches', 'U') IS NOT NULL DROP TABLE dbo.Trf_Branches;
IF OBJECT_ID('dbo.Trf_Services', 'U') IS NOT NULL DROP TABLE dbo.Trf_Services;
IF OBJECT_ID('dbo.Trf_Couriers', 'U') IS NOT NULL DROP TABLE dbo.Trf_Couriers;
IF OBJECT_ID('dbo.Trf_Packages', 'U') IS NOT NULL DROP TABLE dbo.Trf_Packages;
IF OBJECT_ID('dbo.Trf_Payments', 'U') IS NOT NULL DROP TABLE dbo.Trf_Payments;
IF OBJECT_ID('dbo.Trf_ShipmentStatus', 'U') IS NOT NULL DROP TABLE dbo.Trf_ShipmentStatus;
GO

/* 1. Cleaned shipment transaction data */

CREATE TABLE dbo.Trf_Shipments (
    shipment_id             VARCHAR(50),
    awb_number              VARCHAR(50),
    transaction_date        DATE,
    pickup_date             DATE,
    delivery_date           DATE,
    customer_id             VARCHAR(50),
    origin_branch_id        VARCHAR(50),
    destination_branch_id   VARCHAR(50),
    service_code            VARCHAR(50),
    courier_id              VARCHAR(50),
    package_id              VARCHAR(50),
    payment_id              VARCHAR(50),
    status_code             VARCHAR(50),
    status_name             VARCHAR(100),
    estimated_days          INT,
    actual_days             INT,
    delay_days              INT,
    shipping_fee            DECIMAL(18,2),
    insurance_fee           DECIMAL(18,2),
    discount_amount         DECIMAL(18,2),
    total_amount            DECIMAL(18,2),
    is_delivered            BIT,
    is_late                 BIT,
    is_failed               BIT,
    is_returned             BIT,
    is_cancelled            BIT
);
GO

/* 2. Cleaned customer data */

CREATE TABLE dbo.Trf_Customers (
    customer_id         VARCHAR(50),
    customer_name       VARCHAR(150),
    customer_type       VARCHAR(100),
    gender              VARCHAR(50),
    phone               VARCHAR(50),
    email               VARCHAR(150),
    city                VARCHAR(100),
    province            VARCHAR(100),
    registration_date   DATE,
    is_active           BIT
);
GO

/* 3. Cleaned branch data */

CREATE TABLE dbo.Trf_Branches (
    branch_id       VARCHAR(50),
    branch_name     VARCHAR(150),
    branch_type     VARCHAR(100),
    address         VARCHAR(255),
    city            VARCHAR(100),
    province        VARCHAR(100),
    region          VARCHAR(100),
    manager_name    VARCHAR(150),
    opening_date    DATE,
    is_active       BIT
);
GO

/* 4. Cleaned service master data */

CREATE TABLE dbo.Trf_Services (
    service_code            VARCHAR(50),
    service_name            VARCHAR(150),
    service_category        VARCHAR(100),
    delivery_estimation     VARCHAR(100),
    max_weight              DECIMAL(10,2),
    is_cod_available        BIT,
    is_active               BIT
);
GO

/* 5. Cleaned courier data */

CREATE TABLE dbo.Trf_Couriers (
    courier_id          VARCHAR(50),
    courier_name        VARCHAR(150),
    gender              VARCHAR(50),
    phone               VARCHAR(50),
    branch_id           VARCHAR(50),
    vehicle_type        VARCHAR(100),
    hire_date           DATE,
    employee_status     VARCHAR(100),
    is_active           BIT
);
GO

/* 6. Cleaned package data */

CREATE TABLE dbo.Trf_Packages (
    package_id          VARCHAR(50),
    package_type        VARCHAR(100),
    package_category    VARCHAR(100),
    weight              DECIMAL(10,2),
    weight_category     VARCHAR(50),
    length_cm           DECIMAL(10,2),
    width_cm            DECIMAL(10,2),
    height_cm           DECIMAL(10,2),
    volume_cm3          DECIMAL(18,2),
    is_fragile          BIT,
    is_insured          BIT,
    item_description    VARCHAR(255)
);
GO

/* 7. Cleaned payment data */

CREATE TABLE dbo.Trf_Payments (
    payment_id          VARCHAR(50),
    payment_method      VARCHAR(100),
    payment_channel     VARCHAR(100),
    bank_name           VARCHAR(100),
    payment_date        DATE,
    payment_status      VARCHAR(100),
    is_cod              BIT,
    refund_status       VARCHAR(100)
);
GO

/* 8. Cleaned shipment status master data */

CREATE TABLE dbo.Trf_ShipmentStatus (
    status_code             VARCHAR(50),
    status_name             VARCHAR(100),
    status_category         VARCHAR(100),
    status_description      VARCHAR(255)
);
GO

/* Check created transform tables */

SELECT 
    TABLE_NAME AS transform_table_name
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND TABLE_NAME LIKE 'Trf_%'
ORDER BY TABLE_NAME;
GO
