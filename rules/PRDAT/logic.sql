WITH base_data AS (
    -- ---------------------------------------------------------------------------------
    -- Step 1: Extract base data from EINE and join with EINA for GMID and deletion flag
    --         Then join with MARC to get WEBAZ (Planned Delivery Time)
    -- ---------------------------------------------------------------------------------
    SELECT DISTINCT
        EINE.SOURCE_SYSTEM,
        EINA.MATNR AS GMID,                    -- Material Number (GMID) from EINA
        EINE.PRDAT,                             -- Price Date / Validity End Date
        MARC.WEBAZ,                             -- Planned Delivery Time in days from MARC
        EINA.LOEKZ                              -- Deletion flag (must be NULL)
    FROM 
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS EINE
    INNER JOIN 
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS EINA
        ON EINE.INFNR = EINA.INFNR                -- Join on Purchasing Info Record Number
        AND EINE.SOURCE_SYSTEM = EINA.SOURCE_SYSTEM  -- Join on Source System
    LEFT JOIN 
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC AS MARC
        ON EINA.MATNR = MARC.MATNR                -- Join on Material Number
        AND EINA.SOURCE_SYSTEM = MARC.SOURCE_SYSTEM  -- Join on Source System
    WHERE 
        EINA.LOEKZ IS NULL                      -- Filter: Only active records (not logically deleted)
        AND (
            EINE.SOURCE_SYSTEM LIKE 'ATHENA%'   -- Any ATHENA instance (ATHENA, ATHENA_US, etc.)
            OR EINE.SOURCE_SYSTEM = 'P08'       -- P08 system
            OR EINE.SOURCE_SYSTEM = 'SHIFT'     -- SHIFT system
        )
),

quality_checks AS (
    -- ---------------------------------------------------------------------------------
    -- Step 2: Apply Completeness and Accuracy business rules
    -- ---------------------------------------------------------------------------------
    SELECT DISTINCT
        SOURCE_SYSTEM,
        GMID,
        'PRDAT' AS ATTRIBUTE,                   -- Hardcoded attribute name
        
        -- COMPLETENESS CHECK: Flag as KO (1) if PRDAT is NULL or empty
        CASE 
            WHEN PRDAT IS NULL OR TRIM(PRDAT) = '' THEN 1
            ELSE 0
        END AS COMPLETENESS,
        
        -- ACCURACY CHECK: Flag as KO (1) if PRDAT is not sufficient for lead time requirements
        -- Formula: PRDAT must be > CURRENT_DATE + 5 days (Processing Time) + WEBAZ (Planned Delivery Time from MARC)
        -- If MARC.WEBAZ is NULL, treat it as 0 using COALESCE
        CASE 
            WHEN PRDAT IS NULL THEN 1           -- NULL values are also inaccurate
            WHEN PRDAT <= DATEADD(DAY, 5 + COALESCE(WEBAZ, 0), CURRENT_DATE()) THEN 1
            ELSE 0
        END AS ACCURACY
        
    FROM 
        base_data
)

-- ---------------------------------------------------------------------------------
-- Step 3: Final output with all quality check results
-- ---------------------------------------------------------------------------------
SELECT DISTINCT
    SOURCE_SYSTEM,
    GMID,
    ATTRIBUTE,
    COMPLETENESS,
    ACCURACY
FROM 
    quality_checks
ORDER BY 
    SOURCE_SYSTEM,
    GMID