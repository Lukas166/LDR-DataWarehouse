/*
    Project  : PT. LDR Data Warehouse
    File     : 06_create_dw_tables.sql
    Purpose  : Create final Data Warehouse tables using Star Schema

    Database:
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

    Fact table:
    - FactShipment

    Notes:
    - This script creates the final star schema.
    - Run this script after:
      01_create_database.sql
      02_create_staging_tables.sql
      03_import_csv.sql
      04_create_transform_tables.sql
      05_transform_data.sql
*/

USE LDR_DW;
GO

/* Drop fact table first because it depends on dimension tables */

IF OBJECT_ID('dbo.FactShipment', 'U') IS NOT NULL DROP TABLE dbo.FactShipment;
GO

/* Drop dimension tables */

IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID('dbo.DimCustomer', 'U') IS NOT NULL DROP TABLE dbo.DimCustomer;
IF OBJECT_ID('dbo.DimBranch', 'U') IS NOT NULL DROP TABLE dbo.DimBranch;
IF OBJECT_ID('dbo.DimService', 'U') IS NOT NULL DROP TABLE dbo.DimService;
IF OBJECT_ID('dbo.DimCourier', 'U') IS NOT NULL DROP TABLE dbo.DimCourier;
IF OBJECT_ID('dbo.DimPackage', 'U') IS NOT NULL DROP TABLE dbo.DimPackage;
IF OBJECT_ID('dbo.DimPayment', 'U') IS NOT NULL DROP TABLE dbo.DimPayment;
IF OBJECT_ID('dbo.DimShipmentStatus', 'U') IS NOT NULL DROP TABLE dbo.DimShipmentStatus;
GO

/* ============================================================
   1. DimDate
   ============================================================ */

CREATE TABLE dbo.DimDate (
    date_key        INT PRIMARY KEY,
    full_date       DATE NOT NULL,
    day_number      INT,
    day_name        VARCHAR(20),
    month_number    INT,
    month_name      VARCHAR(20),
    quarter_number  INT,
    year_number     INT,
    is_weekend      BIT
);
GO

/* ============================================================
   2. DimCustomer
   ============================================================ */

CREATE TABLE dbo.DimCustomer (
    customer_key        INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL,
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

/* ============================================================
   3. DimBranch
   ============================================================ */

CREATE TABLE dbo.DimBranch (
    branch_key      INT IDENTITY(1,1) PRIMARY KEY,
    branch_id       VARCHAR(50) NOT NULL,
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

/* ============================================================
   4. DimService
   ============================================================ */

CREATE TABLE dbo.DimService (
    service_key            INT IDENTITY(1,1) PRIMARY KEY,
    service_code           VARCHAR(50) NOT NULL,
    service_name           VARCHAR(150),
    service_category       VARCHAR(100),
    delivery_estimation    VARCHAR(100),
    max_weight             DECIMAL(10,2),
    is_cod_available       BIT,
    is_active              BIT
);
GO

/* ============================================================
   5. DimCourier
   ============================================================ */

CREATE TABLE dbo.DimCourier (
    courier_key        INT IDENTITY(1,1) PRIMARY KEY,
    courier_id         VARCHAR(50) NOT NULL,
    courier_name       VARCHAR(150),
    gender             VARCHAR(50),
    phone              VARCHAR(50),
    branch_id          VARCHAR(50),
    vehicle_type       VARCHAR(100),
    hire_date          DATE,
    employee_status    VARCHAR(100),
    is_active          BIT
);
GO

/* ============================================================
   6. DimPackage
   ============================================================ */

CREATE TABLE dbo.DimPackage (
    package_key        INT IDENTITY(1,1) PRIMARY KEY,
    package_id         VARCHAR(50) NOT NULL,
    package_type       VARCHAR(100),
    package_category   VARCHAR(100),
    weight             DECIMAL(10,2),
    weight_category    VARCHAR(50),
    length_cm          DECIMAL(10,2),
    width_cm           DECIMAL(10,2),
    height_cm          DECIMAL(10,2),
    volume_cm3         DECIMAL(18,2),
    is_fragile         BIT,
    is_insured         BIT,
    item_description   VARCHAR(255)
);
GO

/* ============================================================
   7. DimPayment
   ============================================================ */

CREATE TABLE dbo.DimPayment (
    payment_key       INT IDENTITY(1,1) PRIMARY KEY,
    payment_id        VARCHAR(50) NOT NULL,
    payment_method    VARCHAR(100),
    payment_channel   VARCHAR(100),
    bank_name         VARCHAR(100),
    payment_date      DATE,
    payment_status    VARCHAR(100),
    is_cod            BIT,
    refund_status     VARCHAR(100)
);
GO

/* ============================================================
   8. DimShipmentStatus
   ============================================================ */

CREATE TABLE dbo.DimShipmentStatus (
    status_key          INT IDENTITY(1,1) PRIMARY KEY,
    status_code         VARCHAR(50) NOT NULL,
    status_name         VARCHAR(100),
    status_category     VARCHAR(100),
    status_description  VARCHAR(255)
);
GO

/* ============================================================
   9. FactShipment
   Grain: one row represents one shipment transaction
   ============================================================ */

CREATE TABLE dbo.FactShipment (
    shipment_key              INT IDENTITY(1,1) PRIMARY KEY,

    shipment_id               VARCHAR(50),
    awb_number                VARCHAR(50),

    transaction_date_key      INT,
    pickup_date_key           INT,
    delivery_date_key         INT,

    customer_key              INT,
    origin_branch_key         INT,
    destination_branch_key    INT,
    service_key               INT,
    courier_key               INT,
    package_key               INT,
    payment_key               INT,
    status_key                INT,

    total_shipment            INT,
    estimated_days            INT,
    actual_days               INT,
    delay_days                INT,

    package_weight            DECIMAL(10,2),
    shipping_fee              DECIMAL(18,2),
    insurance_fee             DECIMAL(18,2),
    discount_amount           DECIMAL(18,2),
    total_amount              DECIMAL(18,2),

    is_delivered              BIT,
    is_late                   BIT,
    is_failed                 BIT,
    is_returned               BIT,
    is_cancelled              BIT,

    created_at                DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_FactShipment_TransactionDate
        FOREIGN KEY (transaction_date_key) REFERENCES dbo.DimDate(date_key),

    CONSTRAINT FK_FactShipment_PickupDate
        FOREIGN KEY (pickup_date_key) REFERENCES dbo.DimDate(date_key),

    CONSTRAINT FK_FactShipment_DeliveryDate
        FOREIGN KEY (delivery_date_key) REFERENCES dbo.DimDate(date_key),

    CONSTRAINT FK_FactShipment_Customer
        FOREIGN KEY (customer_key) REFERENCES dbo.DimCustomer(customer_key),

    CONSTRAINT FK_FactShipment_OriginBranch
        FOREIGN KEY (origin_branch_key) REFERENCES dbo.DimBranch(branch_key),

    CONSTRAINT FK_FactShipment_DestinationBranch
        FOREIGN KEY (destination_branch_key) REFERENCES dbo.DimBranch(branch_key),

    CONSTRAINT FK_FactShipment_Service
        FOREIGN KEY (service_key) REFERENCES dbo.DimService(service_key),

    CONSTRAINT FK_FactShipment_Courier
        FOREIGN KEY (courier_key) REFERENCES dbo.DimCourier(courier_key),

    CONSTRAINT FK_FactShipment_Package
        FOREIGN KEY (package_key) REFERENCES dbo.DimPackage(package_key),

    CONSTRAINT FK_FactShipment_Payment
        FOREIGN KEY (payment_key) REFERENCES dbo.DimPayment(payment_key),

    CONSTRAINT FK_FactShipment_Status
        FOREIGN KEY (status_key) REFERENCES dbo.DimShipmentStatus(status_key)
);
GO

/* Check created DW tables */

SELECT 
    TABLE_NAME AS dw_table_name
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO
