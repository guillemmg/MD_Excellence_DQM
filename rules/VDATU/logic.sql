WITH BASE_DATA AS (
    SELECT DISTINCT
        EORD.SOURCE_SYSTEM,
        EORD.MATNR,
        EORD.VDATU,
        EORD.ERDAT   -- Creation date of the source list
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EORD AS EORD
    WHERE 
        -- Filter: Only specified source systems
        EORD.SOURCE_SYSTEM LIKE '%ATHENA%'
            OR EORD.SOURCE_SYSTEM IN ('P08', 'SHIFT')
),

DQ_CHECKS AS (
    SELECT 
        SOURCE_SYSTEM,
        MATNR,
        'VDATU' AS ATTRIBUTE,
        
        -- COMPLETENESS CHECK
        -- KO (1) if ANY record for the SOURCE_SYSTEM + MATNR combination has NULL/empty VDATU
        MAX(CASE 
            WHEN VDATU IS NULL OR TRIM(VDATU) = '' THEN 1
            ELSE 0
        END) AS COMPLETENESS,
        
        -- ACCURACY CHECK
        -- KO (1) if ANY record for the SOURCE_SYSTEM + MATNR combination has VDATU != ERDAT
        MAX(CASE 
            WHEN VDATU IS NULL THEN 1  -- NULL is inaccurate
            WHEN ERDAT IS NULL THEN 1  -- Cannot validate without creation date
            WHEN VDATU != ERDAT THEN 1  -- Dates don't match
            ELSE 0
        END) AS ACCURACY
        
    FROM BASE_DATA
    -- Aggregate to one row per SOURCE_SYSTEM + MATNR combination
    GROUP BY
        SOURCE_SYSTEM,
        MATNR
)

-- FINAL OUTPUT
SELECT 
    SOURCE_SYSTEM,
    MATNR AS GMID,
    ATTRIBUTE,
    COMPLETENESS,
    ACCURACY
FROM DQ_CHECKS
ORDER BY 
    SOURCE_SYSTEM,
    GMID,
    COMPLETENESS DESC,
    ACCURACY DESC