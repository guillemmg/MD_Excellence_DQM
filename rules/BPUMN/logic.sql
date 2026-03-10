WITH BASE_DATA AS (
    SELECT
        -- System and Material identifiers
        eina.SOURCE_SYSTEM                AS SOURCE_SYSTEM,
        eina.MATNR                        AS GMID,
        eine.INFNR                        AS INFO_RECORD_NUMBER,

        -- Key fields for conversion factor validation
        eine.BPRME                        AS ORDER_PRICE_UNIT,       -- UoM from supplier agreement/price list
        eina.MEINS                        AS PO_UNIT_OF_MEASURE,     -- PO UoM
        eine.BPUMN                        AS CONVERSION_NUMERATOR,   -- Numerator for conversion
        eine.BPUMZ                        AS CONVERSION_DENOMINATOR, -- Denominator for conversion

        -- ✅ ADDED: Explicit ATTRIBUTE tag for BPUMN traceability
        'BPUMN'                           AS ATTRIBUTE               -- Attribute identifier

    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS eine

    INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS eina
        ON  eine.INFNR         = eina.INFNR
        AND eine.SOURCE_SYSTEM = eina.SOURCE_SYSTEM

    WHERE 1=1
        -- Exclude deleted PIR records (general data)
        AND (eina.LOEKZ IS NULL OR eina.LOEKZ = '')

        -- ✅ MODIFIED: Filter scope to target SOURCE_SYSTEM instances only
        --    Includes: all ATHENA instances (e.g. ATHENA_XX), P08, and SHIFT
        AND (
            eina.SOURCE_SYSTEM LIKE 'ATHENA%'
            OR eina.SOURCE_SYSTEM = 'P08'
            OR eina.SOURCE_SYSTEM = 'SHIFT'
        )

        -- ✅ ADDED: Filter scope to BPUMN attribute only
        AND eine.BPUMN IS NOT NULL

),

CHECKS AS (
    SELECT
        SOURCE_SYSTEM,
        GMID,
        ATTRIBUTE,                         -- ✅ ADDED: Carry ATTRIBUTE through checks

        -- =====================================================================
        -- COMPLETENESS CHECK (Combined)
        -- All 4 required fields must be populated for the conversion to be valid
        -- Returns: 1 = Fail, 0 = Pass
        -- =====================================================================
        CASE
            WHEN NULLIF(TRIM(ORDER_PRICE_UNIT), '')   IS NULL THEN 1  -- Order Price Unit missing
            WHEN NULLIF(TRIM(PO_UNIT_OF_MEASURE), '') IS NULL THEN 1  -- PO UoM missing
            WHEN CONVERSION_NUMERATOR                 IS NULL THEN 1  -- Numerator (BPUMN) missing
            WHEN CONVERSION_DENOMINATOR               IS NULL THEN 1  -- Denominator missing
            ELSE 0
        END AS COMPLETENESS,

        -- =====================================================================
        -- ACCURACY CHECK (Combined)
        -- Validates the logical correctness of the conversion factor
        -- Returns: 1 = Fail, 0 = Pass
        -- =====================================================================
        CASE
            -- Check 1: When UoMs are the same, conversion must be 1:1
            WHEN TRIM(ORDER_PRICE_UNIT) = TRIM(PO_UNIT_OF_MEASURE)
                 AND (CONVERSION_NUMERATOR != 1 OR CONVERSION_DENOMINATOR != 1)
            THEN 1

            -- Check 2: When UoMs differ, conversion must NOT be 1:1 (real conversion needed)
            WHEN TRIM(ORDER_PRICE_UNIT) != TRIM(PO_UNIT_OF_MEASURE)
                 AND CONVERSION_NUMERATOR  = 1
                 AND CONVERSION_DENOMINATOR = 1
            THEN 1

            -- Check 3: Denominator cannot be zero (division by zero guard)
            WHEN CONVERSION_DENOMINATOR = 0
            THEN 1

            -- All accuracy checks passed
            ELSE 0
        END AS ACCURACY

    FROM BASE_DATA
)

-- =====================================================================
-- FINAL OUTPUT
-- =====================================================================
SELECT
    SOURCE_SYSTEM,
    GMID,
    ATTRIBUTE,                             -- ✅ ADDED: BPUMN attribute label in output
    COMPLETENESS,
    ACCURACY
FROM CHECKS
ORDER BY SOURCE_SYSTEM, GMID