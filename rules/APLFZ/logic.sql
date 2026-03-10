WITH

-- ============================================================
-- CTE 1: base_data
-- Purpose: Consolidate all relevant fields from EINE, EINA,
--          and MARC into a single working dataset.
-- Filters:
--   - EINA.LOEKZ IS NULL → Only active (non-deleted) PIRs
--   - EINE.SOURCE_SYSTEM filter → Only ATHENA instances,
--     P08, and SHIFT source systems
-- Joins:
--   - EINE ↔ EINA on INFNR + SOURCE_SYSTEM → to retrieve MATNR
--   - base ↔ MARC on MATNR + SOURCE_SYSTEM → to retrieve PLIFZ
--     and BESKZ for material master alignment checks
-- ============================================================
base_data AS (

    SELECT DISTINCT
        EINE.SOURCE_SYSTEM,
        EINA.MATNR,                          -- Material Number (will be aliased as GMID in final output)
        EINE.INFNR,                          -- Purchasing Info Record Number
        EINE.APLFZ,                          -- Planned Delivery Time in PIR (field under review)
        MARC.PLIFZ,                          -- Planned Delivery Time in Material Master
        MARC.BESKZ                           -- Procurement Type (e.g., 'F' = External Procurement)

    FROM
        -- Main source table: Purchasing Info Record (PIR) conditions
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE  AS EINE

        -- Join EINA to retrieve MATNR linked to the PIR
        INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA  AS EINA
            ON  EINE.INFNR         = EINA.INFNR           -- Match on Info Record Number
            AND EINE.SOURCE_SYSTEM = EINA.SOURCE_SYSTEM   -- Match on Source System (SAP client)

        -- Join MARC to retrieve material master procurement data
        LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC  AS MARC
            ON  EINA.MATNR         = MARC.MATNR           -- Match on Material Number
            AND EINE.SOURCE_SYSTEM = MARC.SOURCE_SYSTEM   -- Match on Source System

    WHERE
        -- Objective 1 / Objective 4 prerequisite:
        -- Only process active PIR records (exclude logically deleted info records)
        EINA.LOEKZ IS NULL

        -- Source System filter:
        -- Only include ATHENA instances (any system starting with 'ATHENA'),
        -- P08, and SHIFT
        AND (
            EINE.SOURCE_SYSTEM LIKE 'ATHENA%'   -- Covers all ATHENA instances (e.g., ATHENA1, ATHENA_EU, etc.)
            OR EINE.SOURCE_SYSTEM = 'P08'        -- P08 exact match
            OR EINE.SOURCE_SYSTEM = 'SHIFT'      -- SHIFT exact match
        )

),

-- ============================================================
-- CTE 2: checks
-- Purpose: Apply Completeness and Accuracy business rules
--          to each record from base_data.
-- Convention:
--   1 = KO (check failed)
--   0 = OK (check passed)
-- ============================================================
checks AS (

    SELECT DISTINCT
        SOURCE_SYSTEM,
        MATNR,
        APLFZ,
        PLIFZ,
        BESKZ,

        -- ----------------------------------------------------------
        -- COMPLETENESS CHECK
        -- Objective 1: APLFZ is a mandatory field and must always
        --              be populated in the PIR.
        -- Objective 4: The Planned Delivery Time in the PIR
        --              (EINE.APLFZ) must be informed / not null.
        -- Rule: COMPLETENESS = 1 (KO) if APLFZ is NULL or 0
        --       COMPLETENESS = 0 (OK) if APLFZ is properly populated
        -- Note: APLFZ is a numeric field, so we only check for NULL
        --       and zero values (no empty string comparison needed)
        -- ----------------------------------------------------------
        CASE
            WHEN APLFZ IS NULL THEN 1   -- Obj. 1 & 4: Field is missing (NULL)
            WHEN APLFZ = 0     THEN 1   -- Obj. 1 & 4: Zero is not a valid delivery time
            ELSE 0                      -- Field is properly populated → OK
        END AS COMPLETENESS,

        -- ----------------------------------------------------------
        -- ACCURACY CHECK
        -- Objective 2: The planned delivery time must be negotiated
        --              and recorded in the supplier agreement
        --              → APLFZ must be > 0.
        -- Objective 3: The planned delivery time in the PIR must be
        --              aligned with the planned delivery time in the
        --              material master → EINE.APLFZ = MARC.PLIFZ.
        -- Objective 5: MARC.PLIFZ (Material Master) must equal
        --              EINE.APLFZ (PIR) for the fixed vendor.
        -- Objective 6: If the material is externally procured
        --              (MARC.BESKZ = 'F'), APLFZ must be >= 1.
        --              This rule applies only to external procurement.
        -- Rule: ACCURACY = 1 (KO) if any accuracy rule fails
        --       ACCURACY = 0 (OK) if all accuracy rules pass
        -- Note: All comparisons are numeric-to-numeric since APLFZ
        --       and PLIFZ are both numeric fields
        -- ----------------------------------------------------------
        CASE
            -- Obj. 2: Planned delivery time must be a positive value (> 0)
            WHEN APLFZ <= 0
                THEN 1

            -- Obj. 3 & 5: PIR delivery time must match material master delivery time
            -- Only evaluated when MARC.PLIFZ is available (LEFT JOIN may return NULL)
            WHEN PLIFZ IS NOT NULL
             AND APLFZ <> PLIFZ
                THEN 1

            -- Obj. 6: For externally procured materials (BESKZ = 'F'),
            -- the planned delivery time must be at least 1 day
            WHEN BESKZ = 'F'
             AND APLFZ < 1
                THEN 1

            -- All accuracy rules passed → OK
            ELSE 0
        END AS ACCURACY

    FROM base_data

)

-- ============================================================
-- FINAL SELECT
-- Purpose: Return the final output with all required columns.
-- Output columns:
--   SOURCE_SYSTEM : SAP source system identifier
--   GMID          : Material Number (MATNR from EINA)
--   ATTRIBUTE     : Fixed label identifying the checked field
--   COMPLETENESS  : 1 = KO (failed), 0 = OK (passed)
--   ACCURACY      : 1 = KO (failed), 0 = OK (passed)
-- ============================================================
SELECT DISTINCT
    SOURCE_SYSTEM,
    MATNR                AS GMID,          -- Material Number aliased as GMID
    'APLFZ'              AS ATTRIBUTE,     -- Identifies the field being checked
    COMPLETENESS,                          -- Completeness flag (0 = OK, 1 = KO)
    ACCURACY                               -- Accuracy flag    (0 = OK, 1 = KO)

FROM checks

ORDER BY
    SOURCE_SYSTEM,
    GMID