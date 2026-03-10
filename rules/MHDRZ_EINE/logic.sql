WITH base_data AS (
    -- =====================================================
    -- STEP 1: Extract base EINE data and join with EINA for GMID
    -- Filter for active records only (LVORM IS NULL)
    -- Filter for specific SOURCE_SYSTEMS: ATHENA instances, P08, SHIFT
    -- =====================================================
    SELECT DISTINCT
        eine.SOURCE_SYSTEM,
        eine.INFNR,
        eine.MHDRZ,
        eina.MATNR AS GMID,
        eina.LOEKZ  -- Include LOEKZ for filtering
    FROM 
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS eine
    INNER JOIN 
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS eina
        ON eine.INFNR = eina.INFNR
        AND eine.SOURCE_SYSTEM = eina.SOURCE_SYSTEM
    -- =====================================================
    -- Filter: Only include active/non-deleted records
    -- LVORM IS NULL indicates active purchasing info records
    -- =====================================================
    WHERE eina.LOEKZ IS NULL
    -- =====================================================
    -- Filter: Only check specific SOURCE_SYSTEMS
    -- ATHENA instances (using LIKE for pattern matching)
    -- P08 and SHIFT (exact matches)
    -- =====================================================
    AND (
        eine.SOURCE_SYSTEM LIKE '%ATHENA%'
        OR eine.SOURCE_SYSTEM = 'P08'
        OR eine.SOURCE_SYSTEM = 'SHIFT'
    )
),

quality_checks AS (
    -- =====================================================
    -- STEP 2: Apply Completeness and Accuracy Logic
    -- =====================================================
    SELECT DISTINCT
        SOURCE_SYSTEM,
        GMID,
        'MHDRZ_EINE' AS ATTRIBUTE,
        
        -- =====================================================
        -- COMPLETENESS CHECK
        -- Logic: MHDRZ should be populated (not NULL and not empty)
        -- KO = 1 if NULL or empty/zero, OK = 0 if populated
        -- =====================================================
        CASE 
            WHEN MHDRZ IS NULL THEN 1
            WHEN CAST(MHDRZ AS VARCHAR) = '' THEN 1
            WHEN MHDRZ = 0 THEN 1
            ELSE 0
        END AS COMPLETENESS,
        
        -- =====================================================
        -- ACCURACY CHECK
        -- Logic: MHDRZ must be a positive integer representing days
        -- Reasonable range: 1 to 3650 days (approximately 10 years)
        -- KO = 1 if invalid, OK = 0 if valid
        -- =====================================================
        CASE 
            WHEN MHDRZ IS NULL THEN 1  -- NULL is inaccurate
            WHEN MHDRZ < 0 THEN 1  -- Negative values are invalid
            WHEN MHDRZ = 0 THEN 1  -- Zero days doesn't make business sense
            WHEN MHDRZ > 3650 THEN 1  -- Unreasonably high (>10 years)
            ELSE 0
        END AS ACCURACY
        
    FROM 
        base_data
)

-- =====================================================
-- STEP 3: Final Output
-- =====================================================
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