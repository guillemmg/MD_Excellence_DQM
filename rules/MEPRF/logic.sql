SELECT DISTINCT
    EINE.SOURCE_SYSTEM,
    EINA.MATNR AS GMID,
    'MEPRF' AS ATTRIBUTE,
    
    -- Completeness: 1 if NULL/empty, 0 if has value
    CASE
        WHEN EINE.MEPRF IS NULL OR TRIM(EINE.MEPRF) = '' THEN 1
        ELSE 0
    END AS COMPLETENESS,
    
    -- Accuracy: 1 if populated but invalid, 0 if valid or empty/null
    CASE
        WHEN EINE.MEPRF IS NULL
        OR TRIM(EINE.MEPRF) = ''                      THEN 1  -- KO: missing = inaccurate
        WHEN TRIM(EINE.MEPRF) NOT IN ('1', '2')       THEN 1  -- KO: invalid value
        ELSE                                               0  -- OK: valid value
    END AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS EINE
INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA AS EINA
    ON EINE.INFNR = EINA.INFNR
    AND EINE.SOURCE_SYSTEM = EINA.SOURCE_SYSTEM

WHERE EINA.LOEKZ IS NULL
    AND (EINE.SOURCE_SYSTEM LIKE 'ATHENA%'
         OR EINE.SOURCE_SYSTEM = 'P08'
         OR EINE.SOURCE_SYSTEM = 'SHIFT')

ORDER BY EINE.SOURCE_SYSTEM, EINA.MATNR
