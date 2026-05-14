/*
    Project  : PT. LDR Data Warehouse
    File     : 01_create_database.sql
    Purpose  : Create databases for ETL process
               1. LDR_Staging = for raw CSV data and transformed data
               2. LDR_DW      = for final data warehouse star schema

    Notes:
    - This script is adjusted for the PT. LDR dummy CSV dataset.
    - Run this script first before creating staging tables.
*/

USE master;
GO

/* Drop databases if they already exist.
   Use this section only if you want to recreate the project from zero.
   Comment this block if you do not want to delete existing databases.
*/

IF DB_ID('LDR_DW') IS NOT NULL
BEGIN
    ALTER DATABASE LDR_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LDR_DW;
END
GO

IF DB_ID('LDR_Staging') IS NOT NULL
BEGIN
    ALTER DATABASE LDR_Staging SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LDR_Staging;
END
GO

/* Create staging database.
   This database will store:
   - Stg_Shipments
   - Stg_Customers
   - Stg_Branches
   - Stg_Services
   - Stg_Couriers
   - Stg_Packages
   - Stg_Payments
   - Stg_ShipmentStatus

   It will also store transform tables:
   - Trf_Shipments
   - Trf_Customers
   - Trf_Branches
   - Trf_Services
   - Trf_Couriers
   - Trf_Packages
   - Trf_Payments
   - Trf_ShipmentStatus
*/

CREATE DATABASE LDR_Staging;
GO

/* Create data warehouse database.
   This database will store the final star schema:
   - DimDate
   - DimCustomer
   - DimBranch
   - DimService
   - DimCourier
   - DimPackage
   - DimPayment
   - DimShipmentStatus
   - FactShipment
*/

CREATE DATABASE LDR_DW;
GO

/* Check created databases */

SELECT 
    name AS database_name,
    create_date
FROM sys.databases
WHERE name IN ('LDR_Staging', 'LDR_DW');
GO
