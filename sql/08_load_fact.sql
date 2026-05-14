/*
    Project  : PT. LDR Data Warehouse
    File     : 08_load_fact.sql
    Purpose  : Load cleaned shipment transactions into FactShipment

    Source:
    - LDR_Staging.dbo.Trf_Shipments
    - LDR_Staging.dbo.Trf_Packages

    Target:
    - LDR_DW.dbo.FactShipment

    Notes:
    - Grain: one row represents one shipment transaction.
    - total_amount is calculated during fact loading using:
      shipping_fee + insurance_fee - discount_amount
    - This prevents total_revenue from becoming 0 because of dirty total_amount values
      in the source CSV.
*/

USE LDR_DW;
GO

/* Clear fact table before reload */

DELETE FROM dbo.FactShipment;
GO

DBCC CHECKIDENT ('dbo.FactShipment', RESEED, 0);
GO

/* Load FactShipment */

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
        WHEN s.pickup_date IS NOT NULL 
            THEN CONVERT(INT, FORMAT(s.pickup_date, 'yyyyMMdd'))
        ELSE NULL
    END AS pickup_date_key,

    CASE 
        WHEN s.delivery_date IS NOT NULL 
            THEN CONVERT(INT, FORMAT(s.delivery_date, 'yyyyMMdd'))
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

    CASE
        WHEN s.actual_days IS NOT NULL 
         AND s.estimated_days IS NOT NULL
            THEN s.actual_days - s.estimated_days
        ELSE NULL
    END AS delay_days,

    p.weight AS package_weight,

    ISNULL(s.shipping_fee, 0) AS shipping_fee,
    ISNULL(s.insurance_fee, 0) AS insurance_fee,
    ISNULL(s.discount_amount, 0) AS discount_amount,

    ISNULL(s.shipping_fee, 0)
    + ISNULL(s.insurance_fee, 0)
    - ISNULL(s.discount_amount, 0) AS total_amount,

    s.is_delivered,
    s.is_late,
    s.is_failed,
    s.is_returned,
    s.is_cancelled

FROM LDR_Staging.dbo.Trf_Shipments s

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

LEFT JOIN LDR_Staging.dbo.Trf_Packages p
    ON s.package_id = p.package_id

LEFT JOIN dbo.DimPayment dpay
    ON s.payment_id = dpay.payment_id

LEFT JOIN dbo.DimShipmentStatus dss
    ON s.status_code = dss.status_code

WHERE s.transaction_date IS NOT NULL;
GO

/* Check fact row count and total revenue */

SELECT 
    COUNT(*) AS total_fact_rows,
    SUM(shipping_fee) AS total_shipping_fee,
    SUM(insurance_fee) AS total_insurance_fee,
    SUM(discount_amount) AS total_discount_amount,
    SUM(total_amount) AS total_revenue
FROM dbo.FactShipment;
GO

/* Preview fact table */

SELECT TOP 20 *
FROM dbo.FactShipment
ORDER BY shipment_key;
GO

/* Check unmapped foreign keys */

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

/* Analysis preview after fact loading */

SELECT
    s.service_name,
    COUNT(*) AS total_shipments,
    SUM(f.shipping_fee) AS total_shipping_fee,
    SUM(f.insurance_fee) AS total_insurance_fee,
    SUM(f.discount_amount) AS total_discount_amount,
    SUM(f.total_amount) AS total_revenue,
    SUM(CASE WHEN f.is_late = 1 THEN 1 ELSE 0 END) AS total_late_shipments
FROM dbo.FactShipment f
LEFT JOIN dbo.DimService s
    ON f.service_key = s.service_key
GROUP BY s.service_name
ORDER BY total_shipments DESC;
GO
