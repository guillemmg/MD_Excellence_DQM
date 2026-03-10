WITH crhd_base AS (
    /*
     * Extract work center master data from CRHD table
     * Filter for relevant work centers and their LVORM field
     */
    SELECT DISTINCT
        SOURCE_SYSTEM,
        OBJTY,                  -- Object Type
        OBJID,                  -- Object ID (Work Center)
        WERKS,                  -- Plant
        LVORM,                  -- Deletion Flag
        BEGDA,                  -- Valid From Date
        ENDDA                   -- Valid To Date
        
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_CRHD
    WHERE OBJTY = 'A'          -- Filter for Work Centers (Object Type A)
    AND UPPER(SOURCE_SYSTEM) LIKE 'ATHENA%'
   OR UPPER(SOURCE_SYSTEM) IN ('SHIFT', 'P08')
),

mara_link AS (
    /*
     * Get material master data to link MATNR (GMID) with work centers
     * WERKS is sourced from MARC (Plant Data for Material) and joined
     * to MARA via MARA.MATNR = MARC.MATNR to provide the plant context
     * for work center validation
     */
    SELECT DISTINCT
        mara.SOURCE_SYSTEM,
        mara.MATNR,             -- Material Number (GMID)
        marc.WERKS              -- Plant sourced from MARC
    FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA mara
    INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC marc
        ON mara.MATNR = marc.MATNR
    WHERE mara.MATNR IS NOT NULL
      AND marc.WERKS IS NOT NULL
      AND mara.LVORM IS NOT NULL
      AND UPPER(mara.SOURCE_SYSTEM) LIKE 'ATHENA%'
   OR UPPER(mara.SOURCE_SYSTEM) IN ('SHIFT', 'P08')
),

work_center_status AS (
    /*
     * Extract core work center data from CRHD
     * Focus on LVORM field presence and validity dates
     * Include deletion flag status based on LVORM IS NOT NULL condition
     */
    SELECT DISTINCT
        c.SOURCE_SYSTEM,
        m.MATNR,
        c.OBJID,
        c.LVORM,
        c.BEGDA,
        c.ENDDA,
        -- Flag if work center is expired (past valid-to date)
        CASE 
            WHEN c.ENDDA < CURRENT_DATE() THEN 1
            ELSE 0
        END AS is_expired,
        -- Deletion flag status: work center is flagged for deletion when LVORM is not null
        CASE 
            WHEN c.LVORM IS NOT NULL THEN 1
            ELSE 0
        END AS DELETION_FLAG
    FROM crhd_base c
    LEFT JOIN mara_link m
        ON c.SOURCE_SYSTEM = m.SOURCE_SYSTEM
        AND c.WERKS = m.WERKS
),

completeness_check AS (
    /*
     * COMPLETENESS: Check if LVORM field is populated
     * Verify that the LVORM field contains data (not null or empty)
     */
    SELECT DISTINCT
        SOURCE_SYSTEM,
        MATNR,
        CASE 
            WHEN LVORM IS NOT NULL AND TRIM(LVORM) != '' THEN 1
            ELSE 0
        END AS completeness_score
    FROM work_center_status
),

accuracy_check AS (
    /*
     * ACCURACY: Validate LVORM field exists and is properly populated
     * Check that when LVORM is present, it contains valid data using LVORM IS NOT NULL condition
     */
    SELECT DISTINCT
        SOURCE_SYSTEM,
        MATNR,
        CASE 
            -- LVORM field exists (deletion flag is set when LVORM IS NOT NULL)
            WHEN LVORM IS NOT NULL THEN 1
            -- LVORM field is missing (no deletion flag set)
            ELSE 0
        END AS accuracy_score
    FROM work_center_status
),

final_metrics AS (
    /*
     * Join completeness and accuracy scores per SOURCE_SYSTEM and MATNR
     * COMPLETENESS and ACCURACY are binary: 1 = OK, 0 = Not OK
     */
    SELECT DISTINCT
        c.SOURCE_SYSTEM,
        c.MATNR,
        c.completeness_score,
        a.accuracy_score
    FROM completeness_check c
    INNER JOIN accuracy_check a
        ON c.SOURCE_SYSTEM = a.SOURCE_SYSTEM
        AND COALESCE(c.MATNR, 'N/A') = COALESCE(a.MATNR, 'N/A')
    WHERE c.MATNR IS NOT NULL  -- Only include records with valid GMID
)

/*
 * Final output with standardized column names
 * Returns binary pass/fail indicators for LVORM attribute by SOURCE_SYSTEM and GMID
 * COMPLETENESS and ACCURACY are binary indicators: 1 = OK (pass), 0 = Not OK (fail)
 */
SELECT DISTINCT
    SOURCE_SYSTEM,
    MATNR AS GMID,
    'LVORM' AS ATTRIBUTE,
    CASE 
        WHEN completeness_score = 1 THEN 1
        ELSE 0
    END AS COMPLETENESS,
    CASE 
        WHEN accuracy_score = 1 THEN 1
        ELSE 0
    END AS ACCURACY
FROM final_metrics
ORDER BY SOURCE_SYSTEM, GMID