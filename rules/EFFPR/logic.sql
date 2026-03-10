WITH eine_data AS (
    -- Extract EINE records with EFFPR field
    -- Filter for ATHENA instances, P08, and SHIFT only
    SELECT DISTINCT
        SOURCE_SYSTEM,
        INFNR,
        EFFPR
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE
    WHERE SOURCE_SYSTEM LIKE 'ATHENA%' 
       OR SOURCE_SYSTEM = 'P08' 
       OR SOURCE_SYSTEM = 'SHIFT'
),

eina_data AS (
    -- Extract EINA records with MATNR (GMID)
    -- Filter to only include active/valid records where LVORM IS NULL
    -- Filter for ATHENA instances, P08, and SHIFT only
    SELECT DISTINCT
        SOURCE_SYSTEM,
        INFNR,
        MATNR AS GMID,
        LOEKZ
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA
    WHERE LOEKZ IS NULL  -- Only include active/valid EINA records
      AND (SOURCE_SYSTEM LIKE 'ATHENA%' 
           OR SOURCE_SYSTEM = 'P08' 
           OR SOURCE_SYSTEM = 'SHIFT')
),

joined_data AS (
    -- Join EINE and EINA using INFNR as connector
    SELECT DISTINCT
        ei.SOURCE_SYSTEM,
        ea.GMID,
        ei.EFFPR
    FROM eine_data ei
    INNER JOIN eina_data ea
        ON ei.INFNR = ea.INFNR
        AND ei.SOURCE_SYSTEM = ea.SOURCE_SYSTEM
),

completeness_check AS (
    -- Check for NULL or blank EFFPR values
    SELECT DISTINCT
        SOURCE_SYSTEM,
        GMID,
        'EFFPR' AS ATTRIBUTE,
        CASE 
            WHEN EFFPR IS NULL OR TRIM(CAST(EFFPR AS VARCHAR)) = '' 
            THEN 1 
            ELSE 0 
        END AS COMPLETENESS,
        NULL AS ACCURACY
    FROM joined_data
),

accuracy_check AS (
    -- Check for EFFPR = 0 (invalid per business rules)
    SELECT DISTINCT
        SOURCE_SYSTEM,
        GMID,
        'EFFPR' AS ATTRIBUTE,
        NULL AS COMPLETENESS,
        CASE 
            WHEN EFFPR = 0 
            THEN 1 
            ELSE 0 
        END AS ACCURACY
    FROM joined_data
    WHERE EFFPR IS NOT NULL  -- Only check accuracy if value exists
),

combined_checks AS (
    -- Combine completeness and accuracy checks
    SELECT DISTINCT
        c.SOURCE_SYSTEM,
        c.GMID,
        c.ATTRIBUTE,
        c.COMPLETENESS,
        a.ACCURACY
    FROM completeness_check c
    LEFT JOIN accuracy_check a
        ON c.SOURCE_SYSTEM = a.SOURCE_SYSTEM
        AND c.GMID = a.GMID
        AND c.ATTRIBUTE = a.ATTRIBUTE
)

-- =====================================================
-- Final Output: Data Quality Check Results
-- =====================================================
SELECT DISTINCT
    SOURCE_SYSTEM,
    GMID,
    ATTRIBUTE,
    COMPLETENESS,
    ACCURACY
FROM combined_checks
ORDER BY 
    SOURCE_SYSTEM,
    GMID