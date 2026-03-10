SELECT DISTINCT
    e.SOURCE_SYSTEM,
    e.MATNR AS GMID,
    'LMEIN' AS ATTRIBUTE,

    /* ---------------- Completeness (OK=0, KO=1) ---------------- */

    CASE
        WHEN e.LMEIN IS NULL OR e.LMEIN = '' THEN 1       -- Missing value
        ELSE 0
    END AS COMPLETENESS,

    /* ----------------- Accuracy (OK=0, KO=1) ------------------- */

    CASE
        WHEN e.LMEIN IS NULL OR e.LMEIN = '' THEN 1       -- Missing invalidates accuracy
        WHEN m.MEINS IS NULL THEN 1                       -- Material master missing
        WHEN e.LMEIN <> m.MEINS THEN 1                    -- LMEIN must match MARA base unit
        WHEN (e.UMREZ IS NOT NULL AND e.UMREZ <= 0) THEN 1
        WHEN (e.UMREN IS NOT NULL AND e.UMREN <= 0) THEN 1
        ELSE 0
    END AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA e
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA m             
   ON e.MATNR = m.MATNR