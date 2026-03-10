WITH EINE_BASE AS (
    SELECT
        EINE.SOURCE_SYSTEM,
        EINE.INFNR,
        EINE.UNTTO,
        EINA.LOEKZ
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS EINE
    LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS EINA
        ON EINE.INFNR          = EINA.INFNR
        AND EINE.SOURCE_SYSTEM = EINA.SOURCE_SYSTEM
    WHERE EINA.LOEKZ IS NULL
      AND (EINE.SOURCE_SYSTEM LIKE 'ATHENA%'
         OR EINE.SOURCE_SYSTEM = 'P08'
         OR EINE.SOURCE_SYSTEM = 'SHIFT')
),

GMID_MAPPING AS (
    SELECT
        EINA.SOURCE_SYSTEM,
        EINA.INFNR,
        EINA.MATNR AS GMID
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS EINA
    WHERE EINA.LOEKZ IS NULL
      AND (EINA.SOURCE_SYSTEM LIKE 'ATHENA%'
         OR EINA.SOURCE_SYSTEM = 'P08'
         OR EINA.SOURCE_SYSTEM = 'SHIFT')
),

MATERIAL_MASTER AS (
    -- Retrieve the tolerance limit from the Material Master
    -- Adjust schema/table/column names to match your actual Material Master view
    SELECT
        SOURCE_SYSTEM,
        MATNR,
        UNETO AS MM_UNETO
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC
    WHERE (SOURCE_SYSTEM LIKE 'ATHENA%'
         OR SOURCE_SYSTEM = 'P08'
         OR SOURCE_SYSTEM = 'SHIFT')
),

CHECKS AS (
    SELECT
        EB.SOURCE_SYSTEM,
        GM.GMID,
        'UNTTO'                                                         AS ATTRIBUTE,

        -- --------------------------------------------------------
        -- COMPLETENESS CHECK
        -- KO = 1 if UNTTO is NULL or empty
        -- --------------------------------------------------------
        CASE
            WHEN EB.UNTTO IS NULL OR TRIM(CAST(EB.UNTTO AS VARCHAR)) = ''
            THEN 1
            ELSE 0
        END                                                             AS COMPLETENESS,

        -- --------------------------------------------------------
        -- ACCURACY CHECK
        -- KO = 1 if:
        --   (a) UNTTO is NOT between 5% and 10% (inclusive), OR
        --   (b) UNTTO in PIR does not match UNTTO in Material Master
        -- --------------------------------------------------------
        CASE
            WHEN EB.UNTTO IS NULL
                THEN 1  -- Cannot assess accuracy if value is missing
            WHEN EB.UNTTO < 5 OR EB.UNTTO > 10
                THEN 1  -- Outside the accepted percentage range [5%, 10%]
            WHEN MM.MM_UNETO IS NULL
                THEN 1  -- No corresponding Material Master record found
            WHEN EB.UNTTO <> MM.MM_UNETO
                THEN 1  -- PIR tolerance does not align with Material Master
            ELSE 0
        END                                                             AS ACCURACY

    FROM EINE_BASE          AS EB
    INNER JOIN GMID_MAPPING AS GM
        ON EB.INFNR          = GM.INFNR
        AND EB.SOURCE_SYSTEM = GM.SOURCE_SYSTEM
    LEFT JOIN MATERIAL_MASTER AS MM
        ON GM.GMID           = MM.MATNR
        AND EB.SOURCE_SYSTEM = MM.SOURCE_SYSTEM
)

-- ============================================================
-- FINAL OUTPUT
-- ============================================================
SELECT
    SOURCE_SYSTEM,
    GMID,
    ATTRIBUTE,
    COMPLETENESS,
    ACCURACY
FROM CHECKS
ORDER BY
    SOURCE_SYSTEM,
    GMID
