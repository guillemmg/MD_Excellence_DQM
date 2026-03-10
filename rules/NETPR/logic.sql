SELECT DISTINCT
    e.SOURCE_SYSTEM,
    a.MATNR AS GMID,
    'NETPR' AS ATTRIBUTE,

    -- COMPLETENESS CHECK: NETPR must not be NULL or blank
    CASE
        WHEN e.NETPR IS NULL OR TRIM(CAST(e.NETPR AS VARCHAR)) = ''
        THEN 1
        ELSE 0
    END AS COMPLETENESS,

    -- ACCURACY CHECK: NETPR must not be 0
    -- (Value is calculated from pricing/condition records and is for information purposes only)
    CASE
        WHEN e.NETPR IS NULL OR TRIM(CAST(e.NETPR AS VARCHAR)) = ''
        THEN 0  -- Already flagged in Completeness; skip Accuracy
        WHEN e.NETPR = 0
        THEN 1
        ELSE 0
    END AS ACCURACY

FROM
    SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE e

LEFT JOIN
    SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA a
    ON  e.INFNR         = a.INFNR
    AND e.SOURCE_SYSTEM = a.SOURCE_SYSTEM

WHERE
    a.LOEKZ IS NULL  -- Only check lines when EINA.LOEKZ is NULL
    AND (
        e.SOURCE_SYSTEM LIKE 'ATHENA%'  -- Any ATHENA instance
        OR e.SOURCE_SYSTEM = 'P08'
        OR e.SOURCE_SYSTEM = 'SHIFT'
    )