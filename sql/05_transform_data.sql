/*
    Project  : PT. LDR Data Warehouse
    File     : 05_transform_data.sql
    Purpose  : Transform dirty staging data into clean transform tables

    Updated approach:
    - Descriptive missing values are replaced with 'Unknown'.
    - Non-applicable values are replaced with 'Not Applicable'.
    - Missing courier_id is mapped to 'UNKNOWN'.
    - estimated_days is filled from service_code when missing.
    - total_amount is calculated in transform layer:
      shipping_fee + insurance_fee - discount_amount.
    - delay_days is calculated in transform layer and never becomes negative:
      actual_days > estimated_days => actual_days - estimated_days
      actual_days <= estimated_days => 0
      actual_days unknown => NULL
    - Event-based values such as delivery_date and actual_days remain NULL
      when the event has not occurred or is not yet known.
*/

USE LDR_Staging;
GO

/* Clear transform tables before re-transform */

TRUNCATE TABLE dbo.Trf_Shipments;
TRUNCATE TABLE dbo.Trf_Customers;
TRUNCATE TABLE dbo.Trf_Branches;
TRUNCATE TABLE dbo.Trf_Services;
TRUNCATE TABLE dbo.Trf_Couriers;
TRUNCATE TABLE dbo.Trf_Packages;
TRUNCATE TABLE dbo.Trf_Payments;
TRUNCATE TABLE dbo.Trf_ShipmentStatus;
GO

/* ============================================================
   1. Transform shipment status master
   ============================================================ */

INSERT INTO dbo.Trf_ShipmentStatus (
    status_code,
    status_name,
    status_category,
    status_description
)
SELECT DISTINCT
    UPPER(LTRIM(RTRIM(status_code))) AS status_code,
    LTRIM(RTRIM(status_name)) AS status_name,
    LTRIM(RTRIM(status_category)) AS status_category,
    LTRIM(RTRIM(status_description)) AS status_description
FROM dbo.Stg_ShipmentStatus
WHERE NULLIF(LTRIM(RTRIM(status_code)), '') IS NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 
    FROM dbo.Trf_ShipmentStatus 
    WHERE status_code = 'UNKNOWN'
)
BEGIN
    INSERT INTO dbo.Trf_ShipmentStatus (
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
   2. Transform customers
   ============================================================ */

INSERT INTO dbo.Trf_Customers (
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
SELECT DISTINCT
    UPPER(LTRIM(RTRIM(customer_id))) AS customer_id,

    ISNULL(NULLIF(UPPER(LTRIM(RTRIM(customer_name))), ''), 'Unknown') AS customer_name,

    CASE
        WHEN UPPER(LTRIM(RTRIM(customer_type))) IN ('INDIVIDUAL', 'PERSONAL', 'PERORANGAN') THEN 'Individual'
        WHEN UPPER(LTRIM(RTRIM(customer_type))) IN ('CORPORATE', 'COMPANY', 'PERUSAHAAN') THEN 'Corporate'
        WHEN UPPER(LTRIM(RTRIM(customer_type))) IN ('MARKETPLACE SELLER', 'SELLER') THEN 'Marketplace Seller'
        WHEN UPPER(LTRIM(RTRIM(customer_type))) IN ('E-COMMERCE PARTNER', 'ECOMMERCE PARTNER') THEN 'E-Commerce Partner'
        ELSE 'Unknown'
    END AS customer_type,

    CASE
        WHEN UPPER(LTRIM(RTRIM(gender))) IN ('MALE', 'M', 'L', 'LAKI-LAKI') THEN 'Male'
        WHEN UPPER(LTRIM(RTRIM(gender))) IN ('FEMALE', 'F', 'P', 'PEREMPUAN') THEN 'Female'
        ELSE 'Unknown'
    END AS gender,

    ISNULL(NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(phone)), '-', ''), ' ', ''), '.', ''), ''), 'Unknown') AS phone,

    ISNULL(LOWER(NULLIF(LTRIM(RTRIM(email)), '')), 'Unknown') AS email,

    CASE
        WHEN UPPER(LTRIM(RTRIM(city))) IN ('JKT PUSAT', 'JAKARTA-PUSAT', 'JAKARTA PUSAT') THEN 'Jakarta Pusat'
        WHEN UPPER(LTRIM(RTRIM(city))) IN ('JKT', 'DKI JAKARTA') THEN 'Jakarta'
        WHEN NULLIF(LTRIM(RTRIM(city)), '') IS NULL THEN 'Unknown'
        ELSE LTRIM(RTRIM(city))
    END AS city,

    ISNULL(NULLIF(LTRIM(RTRIM(province)), ''), 'Unknown') AS province,

    COALESCE(
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(registration_date)), ''), 120),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(registration_date)), ''), 111),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(registration_date)), ''), 103),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(registration_date)), ''), 105),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(registration_date)), ''), 107)
    ) AS registration_date,

    CASE
        WHEN UPPER(LTRIM(RTRIM(status))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
        WHEN UPPER(LTRIM(RTRIM(status))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
        ELSE 0
    END AS is_active

FROM dbo.Stg_Customers
WHERE NULLIF(LTRIM(RTRIM(customer_id)), '') IS NOT NULL;
GO

/* ============================================================
   3. Transform branches
   ============================================================ */

INSERT INTO dbo.Trf_Branches (
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
SELECT DISTINCT
    UPPER(LTRIM(RTRIM(branch_id))) AS branch_id,

    CASE
        WHEN UPPER(LTRIM(RTRIM(branch_name))) IN ('LDR JKT PUSAT', 'LDR JAKARTA-PUSAT') THEN 'LDR Jakarta Pusat'
        WHEN NULLIF(LTRIM(RTRIM(branch_name)), '') IS NULL THEN 'Unknown'
        ELSE LTRIM(RTRIM(branch_name))
    END AS branch_name,

    CASE
        WHEN UPPER(LTRIM(RTRIM(branch_type))) IN ('MAIN BRANCH', 'MAIN', 'CABANG UTAMA') THEN 'Main Branch'
        WHEN UPPER(LTRIM(RTRIM(branch_type))) IN ('OUTLET', 'AGENT', 'AGEN') THEN 'Outlet'
        WHEN UPPER(LTRIM(RTRIM(branch_type))) IN ('WAREHOUSE', 'GUDANG') THEN 'Warehouse'
        WHEN UPPER(LTRIM(RTRIM(branch_type))) IN ('SORTING CENTER') THEN 'Sorting Center'
        ELSE 'Unknown'
    END AS branch_type,

    ISNULL(NULLIF(LTRIM(RTRIM(address)), ''), 'Unknown') AS address,

    CASE
        WHEN UPPER(LTRIM(RTRIM(city))) IN ('JKT PUSAT', 'JAKARTA-PUSAT', 'JAKARTA PUSAT') THEN 'Jakarta Pusat'
        WHEN UPPER(LTRIM(RTRIM(city))) IN ('JKT', 'DKI JAKARTA') THEN 'Jakarta'
        WHEN NULLIF(LTRIM(RTRIM(city)), '') IS NULL THEN 'Unknown'
        ELSE LTRIM(RTRIM(city))
    END AS city,

    ISNULL(NULLIF(LTRIM(RTRIM(province)), ''), 'Unknown') AS province,
    ISNULL(NULLIF(LTRIM(RTRIM(region)), ''), 'Unknown') AS region,
    ISNULL(NULLIF(UPPER(LTRIM(RTRIM(manager_name))), ''), 'Unknown') AS manager_name,

    COALESCE(
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(opening_date)), ''), 120),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(opening_date)), ''), 111),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(opening_date)), ''), 103),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(opening_date)), ''), 105),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(opening_date)), ''), 107)
    ) AS opening_date,

    CASE
        WHEN UPPER(LTRIM(RTRIM(is_active))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
        WHEN UPPER(LTRIM(RTRIM(is_active))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
        ELSE 0
    END AS is_active

FROM dbo.Stg_Branches
WHERE NULLIF(LTRIM(RTRIM(branch_id)), '') IS NOT NULL;
GO

/* ============================================================
   4. Transform services
   ============================================================ */

INSERT INTO dbo.Trf_Services (
    service_code,
    service_name,
    service_category,
    delivery_estimation,
    max_weight,
    is_cod_available,
    is_active
)
SELECT DISTINCT
    UPPER(LTRIM(RTRIM(service_code))) AS service_code,

    ISNULL(NULLIF(LTRIM(RTRIM(service_name)), ''), 'Unknown') AS service_name,

    CASE
        WHEN UPPER(LTRIM(RTRIM(service_category))) IN ('REGULAR', 'REG') THEN 'Regular'
        WHEN UPPER(LTRIM(RTRIM(service_category))) IN ('EXPRESS', 'EXP') THEN 'Express'
        WHEN UPPER(LTRIM(RTRIM(service_category))) IN ('ECONOMY', 'ECO') THEN 'Economy'
        WHEN UPPER(LTRIM(RTRIM(service_category))) IN ('CARGO', 'TRUCKING') THEN 'Cargo'
        ELSE 'Unknown'
    END AS service_category,

    ISNULL(NULLIF(LTRIM(RTRIM(delivery_estimation)), ''), 'Unknown') AS delivery_estimation,

    TRY_CONVERT(
        DECIMAL(10,2),
        NULLIF(REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(max_weight))), 'KG', ''), ' ', ''), ',', ''), '')
    ) AS max_weight,

    CASE
        WHEN UPPER(LTRIM(RTRIM(cod_available))) IN ('YES', 'Y', 'TRUE', '1', 'AVAILABLE') THEN 1
        WHEN UPPER(LTRIM(RTRIM(cod_available))) IN ('NO', 'N', 'FALSE', '0') THEN 0
        ELSE 0
    END AS is_cod_available,

    CASE
        WHEN UPPER(LTRIM(RTRIM(status))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
        WHEN UPPER(LTRIM(RTRIM(status))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
        ELSE 0
    END AS is_active

FROM dbo.Stg_Services
WHERE NULLIF(LTRIM(RTRIM(service_code)), '') IS NOT NULL;
GO

/* ============================================================
   5. Transform couriers
   ============================================================ */

INSERT INTO dbo.Trf_Couriers (
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
SELECT DISTINCT
    UPPER(LTRIM(RTRIM(courier_id))) AS courier_id,
    ISNULL(NULLIF(UPPER(LTRIM(RTRIM(courier_name))), ''), 'Unknown Courier') AS courier_name,

    CASE
        WHEN UPPER(LTRIM(RTRIM(gender))) IN ('MALE', 'M', 'L', 'LAKI-LAKI') THEN 'Male'
        WHEN UPPER(LTRIM(RTRIM(gender))) IN ('FEMALE', 'F', 'P', 'PEREMPUAN') THEN 'Female'
        ELSE 'Unknown'
    END AS gender,

    ISNULL(NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(phone)), '-', ''), ' ', ''), '.', ''), ''), 'Unknown') AS phone,

    ISNULL(NULLIF(UPPER(LTRIM(RTRIM(branch_id))), ''), 'UNKNOWN') AS branch_id,

    CASE
        WHEN UPPER(LTRIM(RTRIM(vehicle_type))) IN ('MOTOR', 'MOTORCYCLE', 'SEPEDA MOTOR') THEN 'Motorcycle'
        WHEN UPPER(LTRIM(RTRIM(vehicle_type))) IN ('CAR', 'MOBIL') THEN 'Car'
        WHEN UPPER(LTRIM(RTRIM(vehicle_type))) IN ('VAN') THEN 'Van'
        WHEN UPPER(LTRIM(RTRIM(vehicle_type))) IN ('TRUCK', 'TRUK') THEN 'Truck'
        ELSE 'Unknown'
    END AS vehicle_type,

    COALESCE(
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), ''), 120),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), ''), 111),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), ''), 103),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), ''), 105),
        TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), ''), 107)
    ) AS hire_date,

    CASE
        WHEN UPPER(LTRIM(RTRIM(employee_status))) IN ('PERMANENT', 'TETAP') THEN 'Permanent'
        WHEN UPPER(LTRIM(RTRIM(employee_status))) IN ('CONTRACT', 'KONTRAK') THEN 'Contract'
        WHEN UPPER(LTRIM(RTRIM(employee_status))) IN ('OUTSOURCE', 'OUTSOURCED') THEN 'Outsourced'
        ELSE 'Unknown'
    END AS employee_status,

    CASE
        WHEN UPPER(LTRIM(RTRIM(is_active))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
        WHEN UPPER(LTRIM(RTRIM(is_active))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
        ELSE 0
    END AS is_active

FROM dbo.Stg_Couriers
WHERE NULLIF(LTRIM(RTRIM(courier_id)), '') IS NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 
    FROM dbo.Trf_Couriers 
    WHERE courier_id = 'UNKNOWN'
)
BEGIN
    INSERT INTO dbo.Trf_Couriers (
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
    VALUES (
        'UNKNOWN',
        'Unknown Courier',
        'Unknown',
        'Unknown',
        'UNKNOWN',
        'Unknown',
        NULL,
        'Unknown',
        0
    );
END
GO

/* ============================================================
   6. Transform packages
   ============================================================ */

INSERT INTO dbo.Trf_Packages (
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
    CASE
        WHEN weight IS NULL THEN 'Unknown'
        WHEN weight <= 1 THEN 'Light'
        WHEN weight <= 10 THEN 'Medium'
        ELSE 'Heavy'
    END AS weight_category,
    length_cm,
    width_cm,
    height_cm,
    CASE
        WHEN length_cm IS NOT NULL AND width_cm IS NOT NULL AND height_cm IS NOT NULL
            THEN length_cm * width_cm * height_cm
        ELSE NULL
    END AS volume_cm3,
    is_fragile,
    is_insured,
    item_description
FROM (
    SELECT DISTINCT
        UPPER(LTRIM(RTRIM(package_id))) AS package_id,

        CASE
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('DOCUMENT') THEN 'Document'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('PARCEL') THEN 'Parcel'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('ELECTRONICS') THEN 'Electronics'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('FOOD') THEN 'Food'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('CARGO') THEN 'Cargo'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('FRAGILE GOODS') THEN 'Fragile Goods'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('CLOTHING') THEN 'Clothing'
            WHEN UPPER(LTRIM(RTRIM(package_type))) IN ('SPARE PARTS') THEN 'Spare Parts'
            ELSE 'Unknown'
        END AS package_type,

        CASE
            WHEN UPPER(LTRIM(RTRIM(package_category))) IN ('SMALL') THEN 'Small'
            WHEN UPPER(LTRIM(RTRIM(package_category))) IN ('MEDIUM') THEN 'Medium'
            WHEN UPPER(LTRIM(RTRIM(package_category))) IN ('LARGE') THEN 'Large'
            WHEN UPPER(LTRIM(RTRIM(package_category))) IN ('CARGO') THEN 'Cargo'
            ELSE 'Unknown'
        END AS package_category,

        TRY_CONVERT(
            DECIMAL(10,2),
            NULLIF(REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(weight))), 'KG', ''), ' ', ''), ',', ''), '')
        ) AS weight,

        TRY_CONVERT(DECIMAL(10,2), NULLIF(LTRIM(RTRIM(length_cm)), '')) AS length_cm,
        TRY_CONVERT(DECIMAL(10,2), NULLIF(LTRIM(RTRIM(width_cm)), '')) AS width_cm,
        TRY_CONVERT(DECIMAL(10,2), NULLIF(LTRIM(RTRIM(height_cm)), '')) AS height_cm,

        CASE
            WHEN UPPER(LTRIM(RTRIM(fragile_flag))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
            WHEN UPPER(LTRIM(RTRIM(fragile_flag))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
            ELSE 0
        END AS is_fragile,

        CASE
            WHEN UPPER(LTRIM(RTRIM(insured_flag))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
            WHEN UPPER(LTRIM(RTRIM(insured_flag))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
            ELSE 0
        END AS is_insured,

        ISNULL(NULLIF(LTRIM(RTRIM(item_description)), ''), 'Unknown') AS item_description

    FROM dbo.Stg_Packages
    WHERE NULLIF(LTRIM(RTRIM(package_id)), '') IS NOT NULL
) p;
GO

/* ============================================================
   7. Transform payments
   ============================================================ */

INSERT INTO dbo.Trf_Payments (
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
    CASE
        WHEN bank_name IS NOT NULL THEN bank_name
        WHEN payment_method IN ('Cash', 'COD') THEN 'Not Applicable'
        WHEN payment_method = 'Bank Transfer' THEN 'Unknown Bank'
        WHEN payment_method = 'E-Wallet' THEN 'Unknown E-Wallet'
        WHEN payment_method = 'Virtual Account' THEN 'Unknown Bank'
        ELSE 'Unknown'
    END AS bank_name,
    payment_date,
    payment_status,
    is_cod,
    refund_status
FROM (
    SELECT DISTINCT
        UPPER(LTRIM(RTRIM(payment_id))) AS payment_id,

        CASE
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('CASH', 'TUNAI') THEN 'Cash'
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('TRANSFER', 'BANK TRANSFER') THEN 'Bank Transfer'
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('E-WALLET', 'EWALLET', 'OVO', 'GOPAY', 'DANA') THEN 'E-Wallet'
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('COD', 'CASH ON DELIVERY') THEN 'COD'
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('VIRTUAL ACCOUNT', 'VA') THEN 'Virtual Account'
            WHEN UPPER(LTRIM(RTRIM(payment_method))) IN ('CORPORATE BILLING') THEN 'Corporate Billing'
            ELSE 'Unknown'
        END AS payment_method,

        CASE
            WHEN UPPER(LTRIM(RTRIM(payment_channel))) IN ('OUTLET', 'GERAI') THEN 'Outlet'
            WHEN UPPER(LTRIM(RTRIM(payment_channel))) IN ('MOBILE APP', 'APP') THEN 'Mobile App'
            WHEN UPPER(LTRIM(RTRIM(payment_channel))) IN ('WEBSITE') THEN 'Website'
            WHEN UPPER(LTRIM(RTRIM(payment_channel))) IN ('MARKETPLACE') THEN 'Marketplace'
            WHEN UPPER(LTRIM(RTRIM(payment_channel))) IN ('CORPORATE SYSTEM', 'CORPORATE') THEN 'Corporate System'
            ELSE 'Unknown'
        END AS payment_channel,

        NULLIF(UPPER(LTRIM(RTRIM(bank_name))), '') AS bank_name,

        COALESCE(
            TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(payment_date)), ''), 120),
            TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(payment_date)), ''), 111),
            TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(payment_date)), ''), 103),
            TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(payment_date)), ''), 105),
            TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(payment_date)), ''), 107)
        ) AS payment_date,

        CASE
            WHEN UPPER(LTRIM(RTRIM(payment_status))) IN ('PAID', 'LUNAS') THEN 'Paid'
            WHEN UPPER(LTRIM(RTRIM(payment_status))) IN ('UNPAID', 'BELUM BAYAR') THEN 'Unpaid'
            WHEN UPPER(LTRIM(RTRIM(payment_status))) IN ('PENDING') THEN 'Pending'
            ELSE 'Unknown'
        END AS payment_status,

        CASE
            WHEN UPPER(LTRIM(RTRIM(is_cod))) IN ('YES', 'Y', 'ACTIVE', 'AKTIF', '1', 'TRUE') THEN 1
            WHEN UPPER(LTRIM(RTRIM(is_cod))) IN ('NO', 'N', 'INACTIVE', 'TIDAK', '0', 'FALSE') THEN 0
            ELSE 0
        END AS is_cod,

        CASE
            WHEN UPPER(LTRIM(RTRIM(refund_status))) IN ('REFUNDED', 'SUDAH REFUND') THEN 'Refunded'
            WHEN UPPER(LTRIM(RTRIM(refund_status))) IN ('NO', 'N', 'NOT REFUNDED', 'TIDAK') THEN 'Not Refunded'
            ELSE 'Unknown'
        END AS refund_status

    FROM dbo.Stg_Payments
    WHERE NULLIF(LTRIM(RTRIM(payment_id)), '') IS NOT NULL
) p;
GO

/* ============================================================
   8. Transform shipments
   ============================================================ */

INSERT INTO dbo.Trf_Shipments (
    shipment_id,
    awb_number,
    transaction_date,
    pickup_date,
    delivery_date,
    customer_id,
    origin_branch_id,
    destination_branch_id,
    service_code,
    courier_id,
    package_id,
    payment_id,
    status_code,
    status_name,
    estimated_days,
    actual_days,
    delay_days,
    shipping_fee,
    insurance_fee,
    discount_amount,
    total_amount,
    is_delivered,
    is_late,
    is_failed,
    is_returned,
    is_cancelled
)
SELECT
    shipment_id,
    awb_number,
    transaction_date,
    pickup_date,
    delivery_date,
    customer_id,
    origin_branch_id,
    destination_branch_id,
    service_code,
    ISNULL(courier_id, 'UNKNOWN') AS courier_id,
    package_id,
    payment_id,
    status_code,
    status_name,
    final_estimated_days AS estimated_days,
    actual_days,

    CASE
        WHEN actual_days IS NULL OR final_estimated_days IS NULL THEN NULL
        WHEN actual_days > final_estimated_days THEN actual_days - final_estimated_days
        ELSE 0
    END AS delay_days,

    ISNULL(shipping_fee, 0) AS shipping_fee,
    ISNULL(insurance_fee, 0) AS insurance_fee,
    ISNULL(discount_amount, 0) AS discount_amount,

    ISNULL(shipping_fee, 0)
    + ISNULL(insurance_fee, 0)
    - ISNULL(discount_amount, 0) AS total_amount,

    CASE WHEN status_code = 'DLV' THEN 1 ELSE 0 END AS is_delivered,

    CASE
        WHEN actual_days IS NOT NULL
         AND final_estimated_days IS NOT NULL
         AND actual_days > final_estimated_days THEN 1
        ELSE 0
    END AS is_late,

    CASE WHEN status_code = 'FAIL' THEN 1 ELSE 0 END AS is_failed,
    CASE WHEN status_code = 'RTR' THEN 1 ELSE 0 END AS is_returned,
    CASE WHEN status_code = 'CANCEL' THEN 1 ELSE 0 END AS is_cancelled

FROM (
    SELECT
        base.*,
        CASE
            WHEN base.estimated_days IS NOT NULL THEN base.estimated_days
            WHEN base.service_code = 'SDS' THEN 0
            WHEN base.service_code = 'EXP' THEN 1
            WHEN base.service_code = 'REG' THEN 3
            WHEN base.service_code = 'COD' THEN 3
            WHEN base.service_code = 'ECO' THEN 5
            WHEN base.service_code = 'CARGO' THEN 6
            WHEN base.service_code = 'TRK' THEN 7
            ELSE NULL
        END AS final_estimated_days
    FROM (
        SELECT
            UPPER(LTRIM(RTRIM(shipment_id))) AS shipment_id,
            UPPER(LTRIM(RTRIM(awb_number))) AS awb_number,

            COALESCE(
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(transaction_date)), ''), 120),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(transaction_date)), ''), 111),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(transaction_date)), ''), 103),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(transaction_date)), ''), 105),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(transaction_date)), ''), 107)
            ) AS transaction_date,

            COALESCE(
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(pickup_date)), ''), 120),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(pickup_date)), ''), 111),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(pickup_date)), ''), 103),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(pickup_date)), ''), 105),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(pickup_date)), ''), 107)
            ) AS pickup_date,

            COALESCE(
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(delivery_date)), ''), 120),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(delivery_date)), ''), 111),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(delivery_date)), ''), 103),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(delivery_date)), ''), 105),
                TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(delivery_date)), ''), 107)
            ) AS delivery_date,

            UPPER(LTRIM(RTRIM(customer_id))) AS customer_id,
            UPPER(LTRIM(RTRIM(origin_branch_id))) AS origin_branch_id,
            UPPER(LTRIM(RTRIM(destination_branch_id))) AS destination_branch_id,
            UPPER(LTRIM(RTRIM(service_code))) AS service_code,
            NULLIF(UPPER(LTRIM(RTRIM(courier_id))), '') AS courier_id,
            UPPER(LTRIM(RTRIM(package_id))) AS package_id,
            UPPER(LTRIM(RTRIM(payment_id))) AS payment_id,

            CASE
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('DLV', 'DELIVERED', 'TERKIRIM', 'SAMPAI') THEN 'DLV'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('ONP', 'ON PROCESS', 'DALAM PERJALANAN', 'ON_PROCESS') THEN 'ONP'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('TRN', 'TRANSIT', 'IN TRANSIT') THEN 'TRN'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('OFD', 'OUT FOR DELIVERY', 'ANTAR KE PENERIMA') THEN 'OFD'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('FAIL', 'FAILED', 'GAGAL') THEN 'FAIL'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('RTR', 'RETURNED', 'RETUR') THEN 'RTR'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('CANCEL', 'CANCELLED', 'BATAL') THEN 'CANCEL'
                ELSE 'UNKNOWN'
            END AS status_code,

            CASE
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('DLV', 'DELIVERED', 'TERKIRIM', 'SAMPAI') THEN 'Delivered'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('ONP', 'ON PROCESS', 'DALAM PERJALANAN', 'ON_PROCESS') THEN 'On Process'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('TRN', 'TRANSIT', 'IN TRANSIT') THEN 'In Transit'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('OFD', 'OUT FOR DELIVERY', 'ANTAR KE PENERIMA') THEN 'Out For Delivery'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('FAIL', 'FAILED', 'GAGAL') THEN 'Failed'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('RTR', 'RETURNED', 'RETUR') THEN 'Returned'
                WHEN UPPER(LTRIM(RTRIM(status_code))) IN ('CANCEL', 'CANCELLED', 'BATAL') THEN 'Cancelled'
                ELSE 'Unknown'
            END AS status_name,

            TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(estimated_days)), '')) AS estimated_days,
            TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(actual_days)), '')) AS actual_days,

            TRY_CONVERT(
                DECIMAL(18,2),
                NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(shipping_fee)), 'Rp', ''), 'RP', ''), '.', ''), ',', ''), ' ', ''), '')
            ) AS shipping_fee,

            TRY_CONVERT(
                DECIMAL(18,2),
                NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(insurance_fee)), 'Rp', ''), 'RP', ''), '.', ''), ',', ''), ' ', ''), '')
            ) AS insurance_fee,

            TRY_CONVERT(
                DECIMAL(18,2),
                NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(discount_amount)), 'Rp', ''), 'RP', ''), '.', ''), ',', ''), ' ', ''), '')
            ) AS discount_amount

        FROM dbo.Stg_Shipments
        WHERE NULLIF(LTRIM(RTRIM(shipment_id)), '') IS NOT NULL
    ) base
) s;
GO

/* ============================================================
   9. Check transform result
   ============================================================ */

SELECT 'Trf_Shipments' AS table_name, COUNT(*) AS total_rows FROM dbo.Trf_Shipments
UNION ALL
SELECT 'Trf_Customers', COUNT(*) FROM dbo.Trf_Customers
UNION ALL
SELECT 'Trf_Branches', COUNT(*) FROM dbo.Trf_Branches
UNION ALL
SELECT 'Trf_Services', COUNT(*) FROM dbo.Trf_Services
UNION ALL
SELECT 'Trf_Couriers', COUNT(*) FROM dbo.Trf_Couriers
UNION ALL
SELECT 'Trf_Packages', COUNT(*) FROM dbo.Trf_Packages
UNION ALL
SELECT 'Trf_Payments', COUNT(*) FROM dbo.Trf_Payments
UNION ALL
SELECT 'Trf_ShipmentStatus', COUNT(*) FROM dbo.Trf_ShipmentStatus;
GO

SELECT TOP 20 *
FROM dbo.Trf_Shipments
ORDER BY shipment_id;
GO

SELECT
    SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END) AS missing_transaction_date,
    SUM(CASE WHEN customer_id IS NULL OR customer_id = '' THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN service_code IS NULL OR service_code = '' THEN 1 ELSE 0 END) AS missing_service_code,
    SUM(CASE WHEN package_id IS NULL OR package_id = '' THEN 1 ELSE 0 END) AS missing_package_id,
    SUM(CASE WHEN payment_id IS NULL OR payment_id = '' THEN 1 ELSE 0 END) AS missing_payment_id,
    SUM(CASE WHEN courier_id = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_courier,
    SUM(CASE WHEN status_code = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_status,
    SUM(CASE WHEN estimated_days IS NULL THEN 1 ELSE 0 END) AS missing_estimated_days,
    SUM(CASE WHEN delay_days < 0 THEN 1 ELSE 0 END) AS negative_delay_days,
    SUM(total_amount) AS transformed_total_revenue
FROM dbo.Trf_Shipments;
GO
