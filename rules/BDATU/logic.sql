SELECT DISTINCT
    marc.SOURCE_SYSTEM,
    mara.MATNR                                          AS GMID,
    'BDATU'                                             AS ATTRIBUTE,
    CASE 
        WHEN eord.BDATU IS NULL THEN 1 
        ELSE 0 
    END                                                 AS COMPLETENESS,
    CASE 
        WHEN eord.BDATU IS NULL THEN 1              -- KO if NULL (incomplete = inaccurate)
        WHEN eord.BDATU <> '9999-12-31'
         AND eord.BDATU < CURRENT_DATE THEN 1       -- KO if not 31/12/9999 and expired
        ELSE 0 
    END                                                 AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA AS mara

INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC AS marc
    ON  mara.MATNR         = marc.MATNR
    AND mara.SOURCE_SYSTEM = marc.SOURCE_SYSTEM

LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EORD AS eord
    ON  marc.MATNR         = eord.MATNR
    AND marc.WERKS         = eord.WERKS
    AND marc.SOURCE_SYSTEM = eord.SOURCE_SYSTEM

WHERE
    -- ── MARA filters ──────────────────────────────────────────────
    mara.MSTAE NOT IN ('XX', 'WF')
    AND mara.ZMTAR IN ('PM', 'RM', 'AI')

    -- ── MARC filters ──────────────────────────────────────────────
    AND (marc.MMSTA NOT IN ('XX', 'WF', 'MC', 'NE', 'IN', 'XO') OR marc.MMSTA IS NULL)
    AND marc.LVORM IS NULL          -- not flagged for deletion
    AND marc.BESKZ = 'F'
    AND (marc.DISMM <> 'ND' OR marc.DISMM IS NULL)

    -- ── SOURCE SYSTEM filter ──────────────────────────────────────
    AND (
        marc.SOURCE_SYSTEM LIKE '%ATHENA%'
        OR marc.SOURCE_SYSTEM = 'P08'
        OR marc.SOURCE_SYSTEM = 'SHIFT'
    )