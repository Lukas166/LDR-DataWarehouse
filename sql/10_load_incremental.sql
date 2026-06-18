/*
    Project  : PT. LDR Data Warehouse
    File     : 10_load_incremental.sql
    Purpose  : Incrementally load transformed data into the data warehouse

    Source database:
    - LDR_Staging

    Target database:
    - LDR_DW

    Approach:
    - This script does not change the existing star schema.
    - Dimensions are loaded using SCD Type 1:
      existing business keys are updated, new business keys are inserted.
    - FactShipment is append-only:
      only shipment_id values that do not exist in FactShipment are inserted.
    - Run this after importing and transforming the latest batch:
      03_import_csv.sql
      05_transform_data.sql
      10_load_incremental.sql

    Important:
    - Do not run 07_load_dimensions.sql or 08_load_fact.sql for incremental
      updates because those scripts perform full reloads.
*/

USE LDR_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* ============================================================
       1. Prepare one-row-per-business-key source sets
       ============================================================ */

    IF OBJECT_ID('tempdb..#DateSource') IS NOT NULL DROP TABLE #DateSource;
    IF OBJECT_ID('tempdb..#CustomerSource') IS NOT NULL DROP TABLE #CustomerSource;
    IF OBJECT_ID('tempdb..#BranchSource') IS NOT NULL DROP TABLE #BranchSource;
    IF OBJECT_ID('tempdb..#ServiceSource') IS NOT NULL DROP TABLE #ServiceSource;
    IF OBJECT_ID('tempdb..#CourierSource') IS NOT NULL DROP TABLE #CourierSource;
    IF OBJECT_ID('tempdb..#PackageSource') IS NOT NULL DROP TABLE #PackageSource;
    IF OBJECT_ID('tempdb..#PaymentSource') IS NOT NULL DROP TABLE #PaymentSource;
    IF OBJECT_ID('tempdb..#StatusSource') IS NOT NULL DROP TABLE #StatusSource;
    IF OBJECT_ID('tempdb..#ShipmentSource') IS NOT NULL DROP TABLE #ShipmentSource;

    SELECT DISTINCT clean_date
    INTO #DateSource
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
    INTO #CustomerSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS rn
        FROM LDR_Staging.dbo.Trf_Customers
        WHERE customer_id IS NOT NULL
    ) c
    WHERE rn = 1;

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
    INTO #BranchSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY branch_id ORDER BY branch_id) AS rn
        FROM LDR_Staging.dbo.Trf_Branches
        WHERE branch_id IS NOT NULL
    ) b
    WHERE rn = 1;

    SELECT
        service_code,
        service_name,
        service_category,
        delivery_estimation,
        max_weight,
        is_cod_available,
        is_active
    INTO #ServiceSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY service_code ORDER BY service_code) AS rn
        FROM LDR_Staging.dbo.Trf_Services
        WHERE service_code IS NOT NULL
    ) s
    WHERE rn = 1;

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
    INTO #CourierSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY courier_id ORDER BY courier_id) AS rn
        FROM LDR_Staging.dbo.Trf_Couriers
        WHERE courier_id IS NOT NULL
    ) c
    WHERE rn = 1;

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
    INTO #PackageSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY package_id ORDER BY package_id) AS rn
        FROM LDR_Staging.dbo.Trf_Packages
        WHERE package_id IS NOT NULL
    ) p
    WHERE rn = 1;

    SELECT
        payment_id,
        payment_method,
        payment_channel,
        bank_name,
        payment_date,
        payment_status,
        is_cod,
        refund_status
    INTO #PaymentSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY payment_id) AS rn
        FROM LDR_Staging.dbo.Trf_Payments
        WHERE payment_id IS NOT NULL
    ) p
    WHERE rn = 1;

    SELECT
        status_code,
        status_name,
        status_category,
        status_description
    INTO #StatusSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY status_code ORDER BY status_code) AS rn
        FROM LDR_Staging.dbo.Trf_ShipmentStatus
        WHERE status_code IS NOT NULL
    ) s
    WHERE rn = 1;

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
        courier_id,
        package_id,
        payment_id,
        status_code,
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
    INTO #ShipmentSource
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY shipment_id ORDER BY transaction_date DESC, shipment_id) AS rn
        FROM LDR_Staging.dbo.Trf_Shipments
        WHERE shipment_id IS NOT NULL
    ) s
    WHERE rn = 1;

    /* ============================================================
       2. Incremental DimDate
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
    SELECT
        CONVERT(INT, FORMAT(ds.clean_date, 'yyyyMMdd')) AS date_key,
        ds.clean_date AS full_date,
        DAY(ds.clean_date) AS day_number,
        DATENAME(WEEKDAY, ds.clean_date) AS day_name,
        MONTH(ds.clean_date) AS month_number,
        DATENAME(MONTH, ds.clean_date) AS month_name,
        DATEPART(QUARTER, ds.clean_date) AS quarter_number,
        YEAR(ds.clean_date) AS year_number,
        CASE
            WHEN DATENAME(WEEKDAY, ds.clean_date) IN ('Saturday', 'Sunday') THEN 1
            ELSE 0
        END AS is_weekend
    FROM #DateSource ds
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimDate d
        WHERE d.date_key = CONVERT(INT, FORMAT(ds.clean_date, 'yyyyMMdd'))
    );

    /* ============================================================
       3. Incremental dimensions using SCD Type 1
       ============================================================ */

    UPDATE d
    SET
        d.customer_name = s.customer_name,
        d.customer_type = s.customer_type,
        d.gender = s.gender,
        d.phone = s.phone,
        d.email = s.email,
        d.city = s.city,
        d.province = s.province,
        d.registration_date = s.registration_date,
        d.is_active = s.is_active
    FROM dbo.DimCustomer d
    INNER JOIN #CustomerSource s
        ON d.customer_id = s.customer_id;

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
        s.customer_id,
        s.customer_name,
        s.customer_type,
        s.gender,
        s.phone,
        s.email,
        s.city,
        s.province,
        s.registration_date,
        s.is_active
    FROM #CustomerSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimCustomer d
        WHERE d.customer_id = s.customer_id
    );

    UPDATE d
    SET
        d.branch_name = s.branch_name,
        d.branch_type = s.branch_type,
        d.address = s.address,
        d.city = s.city,
        d.province = s.province,
        d.region = s.region,
        d.manager_name = s.manager_name,
        d.opening_date = s.opening_date,
        d.is_active = s.is_active
    FROM dbo.DimBranch d
    INNER JOIN #BranchSource s
        ON d.branch_id = s.branch_id;

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
        s.branch_id,
        s.branch_name,
        s.branch_type,
        s.address,
        s.city,
        s.province,
        s.region,
        s.manager_name,
        s.opening_date,
        s.is_active
    FROM #BranchSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimBranch d
        WHERE d.branch_id = s.branch_id
    );

    UPDATE d
    SET
        d.service_name = s.service_name,
        d.service_category = s.service_category,
        d.delivery_estimation = s.delivery_estimation,
        d.max_weight = s.max_weight,
        d.is_cod_available = s.is_cod_available,
        d.is_active = s.is_active
    FROM dbo.DimService d
    INNER JOIN #ServiceSource s
        ON d.service_code = s.service_code;

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
        s.service_code,
        s.service_name,
        s.service_category,
        s.delivery_estimation,
        s.max_weight,
        s.is_cod_available,
        s.is_active
    FROM #ServiceSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimService d
        WHERE d.service_code = s.service_code
    );

    UPDATE d
    SET
        d.courier_name = s.courier_name,
        d.gender = s.gender,
        d.phone = s.phone,
        d.branch_id = s.branch_id,
        d.vehicle_type = s.vehicle_type,
        d.hire_date = s.hire_date,
        d.employee_status = s.employee_status,
        d.is_active = s.is_active
    FROM dbo.DimCourier d
    INNER JOIN #CourierSource s
        ON d.courier_id = s.courier_id;

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
        s.courier_id,
        s.courier_name,
        s.gender,
        s.phone,
        s.branch_id,
        s.vehicle_type,
        s.hire_date,
        s.employee_status,
        s.is_active
    FROM #CourierSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimCourier d
        WHERE d.courier_id = s.courier_id
    );

    UPDATE d
    SET
        d.package_type = s.package_type,
        d.package_category = s.package_category,
        d.weight = s.weight,
        d.weight_category = s.weight_category,
        d.length_cm = s.length_cm,
        d.width_cm = s.width_cm,
        d.height_cm = s.height_cm,
        d.volume_cm3 = s.volume_cm3,
        d.is_fragile = s.is_fragile,
        d.is_insured = s.is_insured,
        d.item_description = s.item_description
    FROM dbo.DimPackage d
    INNER JOIN #PackageSource s
        ON d.package_id = s.package_id;

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
        s.package_id,
        s.package_type,
        s.package_category,
        s.weight,
        s.weight_category,
        s.length_cm,
        s.width_cm,
        s.height_cm,
        s.volume_cm3,
        s.is_fragile,
        s.is_insured,
        s.item_description
    FROM #PackageSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimPackage d
        WHERE d.package_id = s.package_id
    );

    UPDATE d
    SET
        d.payment_method = s.payment_method,
        d.payment_channel = s.payment_channel,
        d.bank_name = s.bank_name,
        d.payment_date = s.payment_date,
        d.payment_status = s.payment_status,
        d.is_cod = s.is_cod,
        d.refund_status = s.refund_status
    FROM dbo.DimPayment d
    INNER JOIN #PaymentSource s
        ON d.payment_id = s.payment_id;

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
        s.payment_id,
        s.payment_method,
        s.payment_channel,
        s.bank_name,
        s.payment_date,
        s.payment_status,
        s.is_cod,
        s.refund_status
    FROM #PaymentSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimPayment d
        WHERE d.payment_id = s.payment_id
    );

    UPDATE d
    SET
        d.status_name = s.status_name,
        d.status_category = s.status_category,
        d.status_description = s.status_description
    FROM dbo.DimShipmentStatus d
    INNER JOIN #StatusSource s
        ON d.status_code = s.status_code;

    INSERT INTO dbo.DimShipmentStatus (
        status_code,
        status_name,
        status_category,
        status_description
    )
    SELECT
        s.status_code,
        s.status_name,
        s.status_category,
        s.status_description
    FROM #StatusSource s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimShipmentStatus d
        WHERE d.status_code = s.status_code
    );

    /* ============================================================
       4. Validate mandatory dimensional lookups before fact load
       ============================================================ */

    IF EXISTS (
        SELECT 1
        FROM #ShipmentSource s
        LEFT JOIN dbo.DimCustomer dc
            ON s.customer_id = dc.customer_id
        LEFT JOIN dbo.DimBranch ob
            ON s.origin_branch_id = ob.branch_id
        LEFT JOIN dbo.DimBranch db
            ON s.destination_branch_id = db.branch_id
        LEFT JOIN dbo.DimService ds
            ON s.service_code = ds.service_code
        LEFT JOIN dbo.DimCourier dcr
            ON s.courier_id = dcr.courier_id
        LEFT JOIN dbo.DimPackage dpkg
            ON s.package_id = dpkg.package_id
        LEFT JOIN dbo.DimPayment dpay
            ON s.payment_id = dpay.payment_id
        LEFT JOIN dbo.DimShipmentStatus dss
            ON s.status_code = dss.status_code
        WHERE s.transaction_date IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.FactShipment f
              WHERE f.shipment_id = s.shipment_id
          )
          AND (
              dc.customer_key IS NULL
              OR ob.branch_key IS NULL
              OR db.branch_key IS NULL
              OR ds.service_key IS NULL
              OR dcr.courier_key IS NULL
              OR dpkg.package_key IS NULL
              OR dpay.payment_key IS NULL
              OR dss.status_key IS NULL
          )
    )
    BEGIN
        THROW 50001, 'Incremental fact load failed because one or more new shipments cannot be mapped to all required dimensions.', 1;
    END;

    /* ============================================================
       5. Incremental fact append
       ============================================================ */

    INSERT INTO dbo.FactShipment (
        shipment_id,
        awb_number,
        transaction_date_key,
        pickup_date_key,
        delivery_date_key,
        customer_key,
        origin_branch_key,
        destination_branch_key,
        service_key,
        courier_key,
        package_key,
        payment_key,
        status_key,
        total_shipment,
        estimated_days,
        actual_days,
        delay_days,
        package_weight,
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
        s.shipment_id,
        s.awb_number,
        CONVERT(INT, FORMAT(s.transaction_date, 'yyyyMMdd')) AS transaction_date_key,
        CASE
            WHEN s.pickup_date IS NOT NULL THEN CONVERT(INT, FORMAT(s.pickup_date, 'yyyyMMdd'))
            ELSE NULL
        END AS pickup_date_key,
        CASE
            WHEN s.delivery_date IS NOT NULL THEN CONVERT(INT, FORMAT(s.delivery_date, 'yyyyMMdd'))
            ELSE NULL
        END AS delivery_date_key,
        dc.customer_key,
        ob.branch_key AS origin_branch_key,
        db.branch_key AS destination_branch_key,
        ds.service_key,
        dcr.courier_key,
        dpkg.package_key,
        dpay.payment_key,
        dss.status_key,
        1 AS total_shipment,
        s.estimated_days,
        s.actual_days,
        s.delay_days,
        dpkg.weight AS package_weight,
        s.shipping_fee,
        s.insurance_fee,
        s.discount_amount,
        s.total_amount,
        s.is_delivered,
        s.is_late,
        s.is_failed,
        s.is_returned,
        s.is_cancelled
    FROM #ShipmentSource s
    LEFT JOIN dbo.DimCustomer dc
        ON s.customer_id = dc.customer_id
    LEFT JOIN dbo.DimBranch ob
        ON s.origin_branch_id = ob.branch_id
    LEFT JOIN dbo.DimBranch db
        ON s.destination_branch_id = db.branch_id
    LEFT JOIN dbo.DimService ds
        ON s.service_code = ds.service_code
    LEFT JOIN dbo.DimCourier dcr
        ON s.courier_id = dcr.courier_id
    LEFT JOIN dbo.DimPackage dpkg
        ON s.package_id = dpkg.package_id
    LEFT JOIN dbo.DimPayment dpay
        ON s.payment_id = dpay.payment_id
    LEFT JOIN dbo.DimShipmentStatus dss
        ON s.status_code = dss.status_code
    WHERE s.transaction_date IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.FactShipment f
          WHERE f.shipment_id = s.shipment_id
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

/* ============================================================
   6. Check incremental load result
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

SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT shipment_id) AS distinct_shipments,
    COUNT(*) - COUNT(DISTINCT shipment_id) AS duplicate_shipment_rows,
    SUM(total_amount) AS total_revenue
FROM dbo.FactShipment;
GO

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
