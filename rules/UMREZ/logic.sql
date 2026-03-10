WITH EINA_BASE AS (
    -- ══════════════════════════════════════════════════════════════════════
    -- Step 1: Get PIR data with relevant fields
    -- ══════════════════════════════════════════════════════════════════════
    SELECT
        eina.SOURCE_SYSTEM,
        eina.MATNR,
        eina.INFNR,
        eina.LIFNR,
        eina.UMREZ,
        eina.UMREN,
        eina.LMEIN                                      AS ORDER_UNIT,
        mara.MEINS                                      AS BASE_UNIT
        
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS eina
    
    INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA AS mara
        ON  eina.MATNR         = mara.MATNR
        AND eina.SOURCE_SYSTEM = mara.SOURCE_SYSTEM
    
    WHERE
        -- ── SOURCE_SYSTEM scope filter ────────────────────────────────────
        (
            eina.SOURCE_SYSTEM LIKE '%ATHENA%'          -- Any ATHENA instance
            OR eina.SOURCE_SYSTEM = 'P08'               -- P08 instance
            OR eina.SOURCE_SYSTEM = 'SHIFT'             -- SHIFT instance
        )

        -- ── EINA filters ──────────────────────────────────────────────────
        AND eina.LOEKZ IS NULL                          -- Not flagged for deletion

        -- ── MARA filters (align with your existing scope) ─────────────────
        --AND mara.MSTAE NOT IN ('GM', 'IN', 'MC', 'QU', 'WF', 'XX','01', '04', '05', '07', '13', '17', 'AV')
        --AND mara.MTART NOT IN ('IDIN', 'IDAI','IDSF')
        AND mara.LVORM IS NULL
),

COMPLETENESS_CHECK AS (
    -- ══════════════════════════════════════════════════════════════════════
    -- Step 2: Evaluate Completeness
    -- KO (1) when conversion data is missing or incomplete
    -- ══════════════════════════════════════════════════════════════════════
    SELECT
        SOURCE_SYSTEM,
        MATNR,
        INFNR,
        LIFNR,
        UMREZ,
        UMREN,
        ORDER_UNIT,
        BASE_UNIT,
        
        CASE 
            -- Missing UMREZ when conversion is required (PUoM ≠ BUoM)
            WHEN ORDER_UNIT <> BASE_UNIT AND UMREZ IS NULL THEN 1
            
            -- Missing UMREN when conversion is required (PUoM ≠ BUoM)
            WHEN ORDER_UNIT <> BASE_UNIT AND UMREN IS NULL THEN 1
            
            -- Orphan: UMREZ exists but UMREN is missing
            WHEN UMREZ IS NOT NULL AND UMREN IS NULL THEN 1
            
            -- Orphan: UMREN exists but UMREZ is missing
            WHEN UMREN IS NOT NULL AND UMREZ IS NULL THEN 1
            
            -- Complete
            ELSE 0
        END AS COMPLETENESS
        
    FROM EINA_BASE
),

ACCURACY_CHECK AS (
    -- ══════════════════════════════════════════════════════════════════════
    -- Step 3: Evaluate Accuracy (linked to Completeness)
    -- KO (1) when data is incomplete OR values are invalid
    -- ══════════════════════════════════════════════════════════════════════
    SELECT
        SOURCE_SYSTEM,
        MATNR,
        INFNR,
        LIFNR,
        UMREZ,
        UMREN,
        ORDER_UNIT,
        BASE_UNIT,
        COMPLETENESS,
        
        CASE 
            -- If incomplete, automatically inaccurate
            WHEN COMPLETENESS = 1 THEN 1
            
            -- UMREZ must be positive
            WHEN UMREZ <= 0 THEN 1
            
            -- UMREN must be positive (avoid division by zero)
            WHEN UMREN <= 0 THEN 1
            
            -- Extreme conversion ratio (likely data entry error)
            WHEN UMREN <> 0 
                 AND ((UMREZ / UMREN) < 0.0001 OR (UMREZ / UMREN) > 10000) THEN 1
            
            -- Unnecessary conversion: PUoM = BUoM but ratio ≠ 1:1
            WHEN ORDER_UNIT = BASE_UNIT 
                 AND (UMREZ <> 1 OR UMREN <> 1) THEN 1
            
            -- Accurate
            ELSE 0
        END AS ACCURACY
        
    FROM COMPLETENESS_CHECK
)

-- ══════════════════════════════════════════════════════════════════════════
-- Final Output: Aggregated at SOURCE_SYSTEM + GMID level
-- ══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT
    SOURCE_SYSTEM,
    MATNR                                               AS GMID,
    'UMREZ'                                             AS ATTRIBUTE,
    
    -- Completeness: KO if ANY PIR for this GMID has completeness issue
    MAX(COMPLETENESS)                                   AS COMPLETENESS,
    
    -- Accuracy: KO if ANY PIR for this GMID has accuracy issue
    MAX(ACCURACY)                                       AS ACCURACY

FROM ACCURACY_CHECK

GROUP BY
    SOURCE_SYSTEM,
    MATNR

ORDER BY
    SOURCE_SYSTEM,
    GMID