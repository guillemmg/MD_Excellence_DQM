WITH EINE_BASE AS (
    SELECT
        EINE.SOURCE_SYSTEM,
        EINE.INFNR,
        EINE.UEBTO
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS EINE
    -- Filter for specific source systems
    WHERE EINE.SOURCE_SYSTEM LIKE 'ATHENA%'
       OR EINE.SOURCE_SYSTEM = 'P08'
       OR EINE.SOURCE_SYSTEM = 'SHIFT'
),

EINA_GMID AS (
    SELECT
        EINA.SOURCE_SYSTEM,
        EINA.INFNR,
        EINA.MATNR AS GMID
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS EINA
    WHERE EINA.LOEKZ IS NULL  -- Only include non-deleted/active EINA records
      -- Filter for specific source systems
      AND (EINA.SOURCE_SYSTEM LIKE 'ATHENA%'
           OR EINA.SOURCE_SYSTEM = 'P08'
           OR EINA.SOURCE_SYSTEM = 'SHIFT')
),

JOINED AS (
    SELECT
        E.SOURCE_SYSTEM,
        G.GMID,
        'UEBTO'         AS ATTRIBUTE,
        E.UEBTO

    FROM EINE_BASE AS E
    LEFT JOIN EINA_GMID AS G
        ON  E.INFNR         = G.INFNR
        AND E.SOURCE_SYSTEM = G.SOURCE_SYSTEM
),

DQ_CHECKS AS (
    SELECT
        SOURCE_SYSTEM,
        GMID,
        ATTRIBUTE,
        UEBTO,

        -- COMPLETENESS: KO (1) if UEBTO is NULL or empty, OK (0) otherwise
        CASE
            WHEN UEBTO IS NULL OR TRIM(CAST(UEBTO AS VARCHAR)) = ''
            THEN 1
            ELSE 0
        END AS COMPLETENESS,

        -- ACCURACY: KO (1) if UEBTO is NOT between 5 and 10 (exclusive), OK (0) otherwise
        CASE
            WHEN UEBTO IS NULL
                 OR CAST(UEBTO AS FLOAT) < 5
                 OR CAST(UEBTO AS FLOAT) > 10
            THEN 1
            ELSE 0
        END AS ACCURACY

    FROM JOINED
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
FROM DQ_CHECKS
ORDER BY
    SOURCE_SYSTEM,
    GMID