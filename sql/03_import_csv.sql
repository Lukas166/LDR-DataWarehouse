/*
    Project  : PT. LDR Data Warehouse
    File     : 03_import_csv.sql
    Purpose  : Import 8 dirty CSV files into staging tables

    IMPORTANT:
    - Before running this script, extract the CSV ZIP file to your computer.
    - Change the file path below according to your own folder location.

    Example recommended folder:
    C:\Data Warehouse\LDR-DataWarehouse\data\

    CSV files:
    1. shipments.csv
    2. customers.csv
    3. branches.csv
    4. services.csv
    5. couriers.csv
    6. packages.csv
    7. payments.csv
    8. shipment_status.csv
*/

USE LDR_Staging;
GO

/*
    Optional: Clear staging tables before import.
    Use this if you want to re-import from zero.
*/

TRUNCATE TABLE dbo.Stg_Shipments;
TRUNCATE TABLE dbo.Stg_Customers;
TRUNCATE TABLE dbo.Stg_Branches;
TRUNCATE TABLE dbo.Stg_Services;
TRUNCATE TABLE dbo.Stg_Couriers;
TRUNCATE TABLE dbo.Stg_Packages;
TRUNCATE TABLE dbo.Stg_Payments;
TRUNCATE TABLE dbo.Stg_ShipmentStatus;
GO

/*
    Change this path if your CSV files are stored in another location.

    IMPORTANT:
    SQL Server reads files from the machine where SQL Server service is running.
    If SQL Server is installed on your own laptop, this local path is fine.
*/

DECLARE @data_path VARCHAR(255);
SET @data_path = 'C:\Data Warehouse\LDR-DataWarehouse\data\';

/*
    BULK INSERT cannot directly use variable paths.
    Therefore, dynamic SQL is used here.
*/

DECLARE @sql NVARCHAR(MAX);

/* 1. Import shipments.csv */

SET @sql = '
BULK INSERT dbo.Stg_Shipments
FROM ''' + @data_path + 'shipments.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 2. Import customers.csv */

SET @sql = '
BULK INSERT dbo.Stg_Customers
FROM ''' + @data_path + 'customers.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 3. Import branches.csv */

SET @sql = '
BULK INSERT dbo.Stg_Branches
FROM ''' + @data_path + 'branches.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 4. Import services.csv */

SET @sql = '
BULK INSERT dbo.Stg_Services
FROM ''' + @data_path + 'services.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 5. Import couriers.csv */

SET @sql = '
BULK INSERT dbo.Stg_Couriers
FROM ''' + @data_path + 'couriers.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 6. Import packages.csv */

SET @sql = '
BULK INSERT dbo.Stg_Packages
FROM ''' + @data_path + 'packages.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 7. Import payments.csv */

SET @sql = '
BULK INSERT dbo.Stg_Payments
FROM ''' + @data_path + 'payments.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;

/* 8. Import shipment_status.csv */

SET @sql = '
BULK INSERT dbo.Stg_ShipmentStatus
FROM ''' + @data_path + 'shipment_status.csv''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
GO

/* Check imported row counts */

SELECT 'Stg_Shipments' AS table_name, COUNT(*) AS total_rows FROM dbo.Stg_Shipments
UNION ALL
SELECT 'Stg_Customers', COUNT(*) FROM dbo.Stg_Customers
UNION ALL
SELECT 'Stg_Branches', COUNT(*) FROM dbo.Stg_Branches
UNION ALL
SELECT 'Stg_Services', COUNT(*) FROM dbo.Stg_Services
UNION ALL
SELECT 'Stg_Couriers', COUNT(*) FROM dbo.Stg_Couriers
UNION ALL
SELECT 'Stg_Packages', COUNT(*) FROM dbo.Stg_Packages
UNION ALL
SELECT 'Stg_Payments', COUNT(*) FROM dbo.Stg_Payments
UNION ALL
SELECT 'Stg_ShipmentStatus', COUNT(*) FROM dbo.Stg_ShipmentStatus;
GO

/* Preview imported data */

SELECT TOP 10 * FROM dbo.Stg_Shipments;
SELECT TOP 10 * FROM dbo.Stg_Customers;
SELECT TOP 10 * FROM dbo.Stg_Branches;
GO
