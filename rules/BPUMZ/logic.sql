WITH BASE_DATA AS (

    SELECT
        -- System and Material identifiers
        eina.SOURCE_SYSTEM                AS SOURCE_SYSTEM,
        eina.MATNR                        AS GMID,
        eine.INFNR                        AS INFO_RECORD_NUMBER,

        -- Order Price Unit: UoM from supplier agreement / price list (EINE.BPRME)
        eine.BPRME                        AS ORDER_PRICE_UNIT,

        -- PO Unit of Measure: Sanofi's purchasing UoM from EINA (EINA.MEINS)
        eina.MEINS                        AS PO_UNIT_OF_MEASURE,

        -- Numerator (BPUMN): needed for cross-check in accuracy logic
        eine.BPUMN                        AS CONVERSION_NUMERATOR,

        -- Denominator (BPUMZ): the primary field being checked in this script
        eine.BPUMZ                        AS CONVERSION_DENOMINATOR,

        -- ✅ ADDED: Explicit ATTRIBUTE tag for BPUMZ traceability
        'BPUMZ'                           AS ATTRIBUTE               -- Attribute identifier

    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS eine

    INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS eina
        ON  eine.INFNR         = eina.INFNR
        AND eine.SOURCE_SYSTEM = eina.SOURCE_SYSTEM

    WHERE 1=1
        -- Exclude PIR general data records flagged for deletion
        AND (eina.LOEKZ IS NULL OR eina.LOEKZ = '')

        -- ✅ ADDED: Filter scope to BPUMZ attribute only
        AND eine.BPUMZ IS NOT NULL

        -- ✅ NEW: Filter to only ATHENA instances, P08, and SHIFT
        AND (
            eina.SOURCE_SYSTEM LIKE 'ATHENA%'  -- Any ATHENA instance (ATHENA, ATHENA_US, etc.)
            OR eina.SOURCE_SYSTEM = 'P08'
            OR eina.SOURCE_SYSTEM = 'SHIFT'
        )

),

CHECKS AS (

    SELECT
        SOURCE_SYSTEM,
        GMID,
        ATTRIBUTE,                         -- ✅ ADDED: Carry ATTRIBUTE through checks

        -- =====================================================================
        -- COMPLETENESS CHECK (Combined)
        -- BPUMZ is the primary field. ORDER_PRICE_UNIT and PO_UNIT_OF_MEASURE
        -- are supporting fields — without them, the denominator has no context.
        -- Returns: 1 = Fail, 0 = Pass
        -- =====================================================================
        CASE
            -- Sub-check 1: Denominator itself is missing
            WHEN CONVERSION_DENOMINATOR IS NULL
                THEN 1

            -- Sub-check 2: Order Price Unit is missing — cannot assess conversion
            --              without knowing the supplier's pricing UoM
            WHEN NULLIF(TRIM(ORDER_PRICE_UNIT), '') IS NULL
                THEN 1

            -- Sub-check 3: PO Unit of Measure is missing — cannot assess conversion
            --              without knowing Sanofi's purchasing UoM
            WHEN NULLIF(TRIM(PO_UNIT_OF_MEASURE), '') IS NULL
                THEN 1

            -- All completeness checks passed
            ELSE 0
        END AS COMPLETENESS,

        -- =====================================================================
        -- ACCURACY CHECK (Combined)
        -- Validates the logical correctness of BPUMZ specifically.
        -- Returns: 1 = Fail, 0 = Pass
        -- =====================================================================
        CASE
            -- Check 1: Zero denominator guard
            -- A denominator of zero is mathematically invalid —
            -- it would cause a division by zero in price calculation.
            WHEN CONVERSION_DENOMINATOR = 0
                THEN 1

            -- Check 2: Negative denominator guard
            -- A negative denominator is logically invalid for a
            -- unit conversion factor in a purchasing context.
            WHEN CONVERSION_DENOMINATOR < 0
                THEN 1

            -- Check 3: Same UoM must have denominator = 1
            -- If the supplier's pricing unit equals Sanofi's PO unit,
            -- no conversion is needed — denominator must be exactly 1.
            WHEN TRIM(ORDER_PRICE_UNIT) = TRIM(PO_UNIT_OF_MEASURE)
                 AND CONVERSION_DENOMINATOR != 1
                THEN 1

            -- Check 4: Different UoMs must have a real conversion ratio
            -- If UoMs differ, both numerator and denominator cannot both
            -- be 1 — a meaningful conversion ratio must be defined.
            WHEN TRIM(ORDER_PRICE_UNIT) != TRIM(PO_UNIT_OF_MEASURE)
                 AND CONVERSION_DENOMINATOR = 1
                 AND CONVERSION_NUMERATOR   = 1
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
    ATTRIBUTE,                             -- ✅ ADDED: BPUMZ attribute label in output
    COMPLETENESS,
    ACCURACY
FROM CHECKS
ORDER BY SOURCE_SYSTEM, GMID